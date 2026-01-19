/**
 * Created by andrewhood on 1/19/26.
 */

public with sharing class MissionAssignmentService {

    /**
     * Centralizes all validation rules:
     * 1. Max 3 Heroes per Mission.
     * 2. No Heroes currently on other missions.
     * 3. No Injured Heroes.
     */
    public static void validateAssignments(List<Mission_Assignment__c> newAssignments) {
        Set<Id> heroIds = new Set<Id>();
        Set<Id> missionIds = new Set<Id>();

        // 1. Collect IDs for bulk querying
        for (Mission_Assignment__c ma : newAssignments) {
            heroIds.add(ma.Superhero__c);
            if (ma.Mission__c != null) {
                missionIds.add(ma.Mission__c);
            }
        }

        // 2. Query current mission capacities
        Map<Id, Integer> currentCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
                SELECT Mission__c, COUNT(Id) total
                FROM Mission_Assignment__c
                WHERE Mission__c IN :missionIds
                GROUP BY Mission__c
        ]) {
            currentCounts.put((Id)ar.get('Mission__c'), (Integer)ar.get('total'));
        }

        // 3. Query Hero details (Status and Injury)
        Map<Id, Superhero__c> heroesMap = new Map<Id, Superhero__c>(
                [SELECT Id, Status__c, Is_Injured__c FROM Superhero__c WHERE Id IN :heroIds]
        );

        // 4. Run Validation Loop
        for (Mission_Assignment__c ma : newAssignments) {
            Superhero__c hero = heroesMap.get(ma.Superhero__c);

            // A. Check Max 3 Capacity
            Integer currentCount = currentCounts.containsKey(ma.Mission__c) ? currentCounts.get(ma.Mission__c) : 0;

            if (currentCount >= 3) {
                ma.addError('Mission capacity reached. Maximum 3 heroes allowed.');
            } else {
                // CRITICAL FIX: Increment the count locally!
                // This ensures if you upload 5 records at once, the loop knows
                // when it hits the limit for the 4th and 5th record.
                currentCounts.put(ma.Mission__c, currentCount + 1);
            }

            // B. Check Double Booking
            // We check if the status is 'On Mission'.
            // Note: This assumes the hero isn't assigned to THIS mission already, which the UI prevents.
            if (hero != null && hero.Status__c == 'On Mission') {
                ma.addError('This hero is already deployed on another mission.');
            }

            // C. Check Injury
            if (hero != null && hero.Is_Injured__c) {
                ma.addError('Injured heroes cannot be deployed until they have recovered.');
            }
        }
    }

    /**
     * Updates the Status__c field on Superhero records.
     * Used by After Insert (On Mission) and After Delete (Available).
     */
    public static void updateHeroStatuses(Set<Id> heroIds, String newStatus) {
        if (heroIds.isEmpty()) return;

        List<Superhero__c> heroesToUpdate = new List<Superhero__c>();
        for (Id hId : heroIds) {
            heroesToUpdate.add(new Superhero__c(Id = hId, Status__c = newStatus));
        }

        // Use a try-catch block to gracefully handle any potential locking errors
        try {
            update heroesToUpdate;
        } catch (DmlException e) {
            System.debug('Error syncing hero status: ' + e.getMessage());
            // In a real prod environment, you might log this to an Error_Log__c object
        }
    }
}