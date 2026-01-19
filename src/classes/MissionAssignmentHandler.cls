/**
 * Created by andrewhood on 1/19/26.
 */

/**
 * Created by andrewhood on 1/19/26.
 */
public with sharing class MissionAssignmentHandler {

    /**
     * Orchestrates validation logic before records are saved.
     */
    public static void handleBeforeInsert(List<Mission_Assignment__c> newAssignments) {
        // We call the service layer to perform the actual business logic
        MissionAssignmentService.validateAssignments(newAssignments);
    }

    /**
     * Orchestrates status updates after a successful assignment.
     */
    public static void handleAfterInsert(List<Mission_Assignment__c> newAssignments) {
        Set<Id> heroIds = new Set<Id>();
        for (Mission_Assignment__c ma : newAssignments) {
            if (ma.Superhero__c != null) {
                heroIds.add(ma.Superhero__c);
            }
        }
        // Use the service to flip heroes to 'On Mission'
        MissionAssignmentService.updateHeroStatuses(heroIds, 'On Mission');
    }

    /**
     * Orchestrates status updates after an assignment is removed (Recall).
     */
    public static void handleAfterDelete(List<Mission_Assignment__c> oldAssignments) {
        Set<Id> heroIds = new Set<Id>();
        for (Mission_Assignment__c ma : oldAssignments) {
            if (ma.Superhero__c != null) {
                heroIds.add(ma.Superhero__c);
            }
        }
        // Use the service to flip heroes back to 'Available'
        MissionAssignmentService.updateHeroStatuses(heroIds, 'Available');
    }
}