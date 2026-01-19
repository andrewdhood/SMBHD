/**
 * MissionAssignmentTrigger
 * Strictly acts as a router. No business logic lives here.
 * This pattern ensures code is maintainable and testable.
 */
trigger MissionAssignmentTrigger on Mission_Assignment__c (
        before insert,
        after insert,
        after delete
) {
    // 1. Validation Logic (Check Max 3, Injuries, and Conflicts)
    if (Trigger.isBefore && Trigger.isInsert) {
        MissionAssignmentHandler.handleBeforeInsert(Trigger.new);
    }

    // 2. Deployment Logic (Set Hero Status to 'On Mission')
    if (Trigger.isAfter && Trigger.isInsert) {
        MissionAssignmentHandler.handleAfterInsert(Trigger.new);
    }

    // 3. Recall Logic (Set Hero Status back to 'Available')
    if (Trigger.isAfter && Trigger.isDelete) {
        MissionAssignmentHandler.handleAfterDelete(Trigger.old);
    }
}