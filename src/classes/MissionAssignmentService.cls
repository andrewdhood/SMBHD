/**
 * Created by andrewhood on 1/19/26.
 */
public with sharing class MissionAssignmentService {

    /**
     * Core business logic for hero deployment.
     * Uses your 'Max_Team_Size' metadata record for dynamic limits.
     */
    public static void validateAssignments(List<Mission_Assignment__c> newAssignments) {

        // 1. CONFIG: Retrieve the specific record using getInstance()
        // This is a Best Practice: It's SOQL-less and extremely fast.
        Mission_Setting__mdt settings = Mission_Setting__mdt.getInstance('Max_Team_Size');

        // Fallback to 3 if the record 'Max_Team_Size' is missing from the org
        Integer maxLimit = (settings != null) ? settings.Max_Heroes__c.intValue() : 3;

        Set<Id> heroIds = new Set<Id>();
        Set<Id> missionIds = new Set<Id>();

        // 2. BULK PREP: Gather IDs for bulkified data fetching
        for (Mission_Assignment__c ma : newAssignments) {
            if (ma.Superhero__c != null) heroIds.add(ma.Superhero__c);
            if (ma.Mission__c != null) missionIds.add(ma.Mission__c);
        }

        // 3. CAPACITY CHECK: Aggregate current headcounts for the target missions
        Map<Id, Integer> currentCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
                SELECT Mission__c, COUNT(Id) total
                FROM Mission_Assignment__c
                WHERE Mission__c IN :missionIds
                GROUP BY Mission__c
        ]) {
            currentCounts.put((Id)ar.get('Mission__c'), (Integer)ar.get('total'));
        }

        // 4. HERO DATA: Fetch status and health for the proposed heroes
        Map<Id, Superhero__c> heroesMap = new Map<Id, Superhero__c>([
                SELECT Id, Status__c, Is_Injured__c
                FROM Superhero__c
                WHERE Id IN :heroIds
        ]);

        // 5. VALIDATION: Apply the "Justice Alliance" ruleset
        for (Mission_Assignment__c ma : newAssignments) {
            Superhero__c hero = heroesMap.get(ma.Superhero__c);

            // Capacity Rule (Now correctly using Max_Team_Size)
            Integer currentCount = currentCounts.containsKey(ma.Mission__c) ? currentCounts.get(ma.Mission__c) : 0;

            if (currentCount >= maxLimit) {
                ma.addError('Mission capacity reached. Maximum ' + maxLimit + ' heroes allowed.');
            } else {
                // Increment locally for bulk insert support
                currentCounts.put(ma.Mission__c, currentCount + 1);
            }

            // Conflict Rule
            if (hero != null && hero.Status__c == 'On Mission') {
                ma.addError('Deployment Conflict: This hero is already assigned to an active mission.');
            }

            // Health Rule
            if (hero != null && hero.Is_Injured__c) {
                ma.addError('Medical Alert: This hero is currently injured and cannot be deployed.');
            }
        }
    }

    /**
     * Updates Superhero status based on deployment or recall.
     */
    public static void updateHeroStatuses(Set<Id> heroIds, String newStatus) {
        if (heroIds.isEmpty()) return;

        List<Superhero__c> heroesToUpdate = new List<Superhero__c>();
        for (Id hId : heroIds) {
            heroesToUpdate.add(new Superhero__c(Id = hId, Status__c = newStatus));
        }

        try {
            update heroesToUpdate;
        } catch (DmlException e) {
            System.debug('Error syncing hero status: ' + e.getMessage());
        }
    }
}