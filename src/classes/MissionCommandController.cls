public with sharing class MissionCommandController {

    // Wrapper to hold the data exactly how the LWC expects it
    public class HeroWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String alias;
        @AuraEnabled public String power;
        @AuraEnabled public String profileImageUrl;
        @AuraEnabled public String status;          
        @AuraEnabled public String effectiveStatus; // Computed status for UI
        @AuraEnabled public Boolean isDeployedHere;
        @AuraEnabled public Boolean isAvailable;
        @AuraEnabled public Boolean hasConflict;
        @AuraEnabled public String conflictingMissionName;
    }

    @AuraEnabled(cacheable=true)
    public static Mission__c getMissionDetails(Id missionId) {
        return [SELECT Id, Name, Status__c FROM Mission__c WHERE Id = :missionId];
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPowerOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        options.add(new Map<String, String>{'label' => 'All Powers', 'value' => 'All'});
        for (Schema.PicklistEntry ple : Superhero__c.Power__c.getDescribe().getPicklistValues()) {
            options.add(new Map<String, String>{'label' => ple.getLabel(), 'value' => ple.getValue()});
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<HeroWrapper> getHeroesForMission(Id missionId, String powerFilter) {
        // 1. Fetch Candidates (Exclude Injured)
        String query = 'SELECT Id, Name, Alias__c, Power__c, Status__c, Profile_Image_URL__c, Is_Injured__c FROM Superhero__c WHERE Is_Injured__c = false';
        if (powerFilter != null && powerFilter != 'All') {
            query += ' AND Power__c = :powerFilter';
        }
        List<Superhero__c> heroes = Database.query(query);

        // 2. Fetch Active Assignments for Context
        Map<Id, Mission_Assignment__c> activeMap = new Map<Id, Mission_Assignment__c>();
        for (Mission_Assignment__c ma : [SELECT Superhero__c, Mission__c, Mission__r.Name FROM Mission_Assignment__c WHERE Is_Active__c = TRUE]) {
            activeMap.put(ma.Superhero__c, ma);
        }

        // 3. Build Wrappers
        List<HeroWrapper> results = new List<HeroWrapper>();
        for (Superhero__c h : heroes) {
            HeroWrapper w = new HeroWrapper();
            w.id = h.Id; 
            w.name = h.Name; 
            w.alias = h.Alias__c; 
            w.power = h.Power__c; 
            w.profileImageUrl = h.Profile_Image_URL__c;
            
            Mission_Assignment__c assignment = activeMap.get(h.Id);
            w.isDeployedHere = (assignment != null && assignment.Mission__c == missionId);
            w.hasConflict = (assignment != null && assignment.Mission__c != missionId);

            if (w.isDeployedHere) {
                w.effectiveStatus = 'On Mission';
                w.isAvailable = false;
            } else if (w.hasConflict) {
                w.effectiveStatus = 'On Mission'; 
                w.conflictingMissionName = assignment.Mission__r.Name;
                w.isAvailable = false;
            } else {
                w.effectiveStatus = 'Available';
                w.isAvailable = true;
            }
            results.add(w);
        }
        return results;
    }

    @AuraEnabled
    public static void deployHeroToMission(Id heroId, Id missionId) {
        // Atomic Transaction: Create Assignment + Update Hero Status
        try {
            insert new Mission_Assignment__c(Superhero__c = heroId, Mission__c = missionId, Is_Active__c = true);
            update new Superhero__c(Id = heroId, Status__c = 'On Mission');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void recallHeroFromMission(Id heroId, Id missionId) {
        try {
            // Find the specific assignment record for this hero and mission
            List<Mission_Assignment__c> assignments = [
                    SELECT Id
                    FROM Mission_Assignment__c
                    WHERE Superhero__c = :heroId
                    AND Mission__c = :missionId
                    LIMIT 1
            ];

            if (!assignments.isEmpty()) {
                // This delete triggers the 'after delete' logic in the handler
                delete assignments;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Recall failed: ' + e.getMessage());
        }
    }
}