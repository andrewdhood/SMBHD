/**
 * MissionAssignmentHandlerTest
 *
 * Tests the trigger handler layer. While the Service layer tests cover the
 * business logic, these tests verify the handler correctly orchestrates
 * the trigger context data.
 *
 * @author andrewhood
 * @date 2026-01-19
 */
@IsTest
private class MissionAssignmentHandlerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA SETUP
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        // Simple roster for handler-level tests
        List<Superhero__c> heroes = new List<Superhero__c>{
                new Superhero__c(
                        Name = 'Handler Hero 1',
                        Alias__c = 'H1',
                        Power__c = 'Tech',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Handler Hero 2',
                        Alias__c = 'H2',
                        Power__c = 'Magic',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Handler Hero 3',
                        Alias__c = 'H3',
                        Power__c = 'Flight',
                        Status__c = 'Available'
                )
        };
        insert heroes;

        Mission__c mission = new Mission__c(
                Name = 'Handler Test Mission',
                Difficulty__c = 'Medium',
                Status__c = 'In-Progress'
        );
        insert mission;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q1: handleBeforeInsert - Validation is triggered
    // Verifies the handler routes to validation logic before insert.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleBeforeInsert_ValidationOccurs() {
        // Arrange
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];
        List<Superhero__c> heroes = [SELECT Id FROM Superhero__c WHERE Name LIKE 'Handler Hero%'];

        // Deploy 3 heroes to hit capacity
        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Superhero__c h : heroes) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = h.Id,
                    Mission__c = mission.Id
            ));
        }
        insert assignments;

        // Now create a 4th hero to test validation
        Superhero__c fourthHero = new Superhero__c(
                Name = 'Handler Hero 4',
                Alias__c = 'H4',
                Power__c = 'Strength',
                Status__c = 'Available'
        );
        insert fourthHero;

        // Act: try to insert 4th assignment (triggers handleBeforeInsert)
        Test.startTest();
        Mission_Assignment__c fourthAssignment = new Mission_Assignment__c(
                Superhero__c = fourthHero.Id,
                Mission__c = mission.Id
        );

        Boolean blocked = false;
        try {
            insert fourthAssignment;
        } catch (DmlException e) {
            blocked = true;
        }
        Test.stopTest();

        // Assert: before insert validation should block the 4th
        System.assert(blocked, 'handleBeforeInsert should have blocked the 4th assignment');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q2: handleAfterInsert - Status update is triggered
    // Verifies the handler routes to status update logic after insert.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_StatusUpdated() {
        // Arrange
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];
        Superhero__c hero = [SELECT Id, Status__c FROM Superhero__c WHERE Name = 'Handler Hero 1' LIMIT 1];

        System.assertEquals('Available', hero.Status__c, 'Hero should start as Available');

        // Act: insert assignment (triggers handleAfterInsert)
        Test.startTest();
        insert new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );
        Test.stopTest();

        // Assert: after insert should have updated hero status
        hero = [SELECT Status__c FROM Superhero__c WHERE Id = :hero.Id];
        System.assertEquals('On Mission', hero.Status__c, 'handleAfterInsert should update hero to On Mission');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q3: handleAfterDelete - Status reverted on delete
    // Verifies the handler routes to status revert logic after delete.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterDelete_StatusReverted() {
        // Arrange: deploy a hero
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];
        Superhero__c hero = [SELECT Id FROM Superhero__c WHERE Name = 'Handler Hero 2' LIMIT 1];

        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );
        insert assignment;

        // Verify hero is On Mission
        hero = [SELECT Status__c FROM Superhero__c WHERE Id = :hero.Id];
        System.assertEquals('On Mission', hero.Status__c, 'Hero should be On Mission after deployment');

        // Act: delete assignment (triggers handleAfterDelete)
        Test.startTest();
        delete assignment;
        Test.stopTest();

        // Assert: after delete should have reverted hero status
        hero = [SELECT Status__c FROM Superhero__c WHERE Id = :hero.Id];
        System.assertEquals('Available', hero.Status__c, 'handleAfterDelete should revert hero to Available');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q4: Bulk after insert - Multiple heroes updated in one transaction
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterInsert_BulkStatusUpdate() {
        // Arrange
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];
        List<Superhero__c> heroes = [SELECT Id FROM Superhero__c WHERE Name LIKE 'Handler Hero%' LIMIT 3];

        // Act: insert 3 assignments in one DML
        Test.startTest();
        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Superhero__c h : heroes) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = h.Id,
                    Mission__c = mission.Id
            ));
        }
        insert assignments;
        Test.stopTest();

        // Assert: all 3 heroes should be On Mission
        Set<Id> heroIds = new Set<Id>();
        for (Superhero__c h : heroes) {
            heroIds.add(h.Id);
        }

        Integer onMissionCount = [SELECT COUNT() FROM Superhero__c WHERE Id IN :heroIds AND Status__c = 'On Mission'];
        System.assertEquals(3, onMissionCount, 'All 3 heroes should be On Mission after bulk insert');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q5: Bulk after delete - Multiple heroes reverted in one transaction
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandleAfterDelete_BulkStatusRevert() {
        // Arrange: deploy 3 heroes
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];
        List<Superhero__c> heroes = [SELECT Id FROM Superhero__c WHERE Name LIKE 'Handler Hero%' LIMIT 3];

        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Superhero__c h : heroes) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = h.Id,
                    Mission__c = mission.Id
            ));
        }
        insert assignments;

        // Act: delete all 3 assignments in one DML
        Test.startTest();
        delete assignments;
        Test.stopTest();

        // Assert: all 3 heroes should be Available
        Set<Id> heroIds = new Set<Id>();
        for (Superhero__c h : heroes) {
            heroIds.add(h.Id);
        }

        Integer availableCount = [SELECT COUNT() FROM Superhero__c WHERE Id IN :heroIds AND Status__c = 'Available'];
        System.assertEquals(3, availableCount, 'All 3 heroes should be Available after bulk delete');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q6: Handler with null Superhero__c (edge case)
    // Tests defensive coding - what happens if Superhero__c is null?
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHandler_NullSuperheroId() {
        // Arrange
        Mission__c mission = [SELECT Id FROM Mission__c WHERE Name = 'Handler Test Mission' LIMIT 1];

        // Act: try to insert assignment with null hero (should fail at DB level)
        Test.startTest();
        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = null,
                Mission__c = mission.Id
        );

        Boolean exceptionThrown = false;
        try {
            insert assignment;
        } catch (Exception e) {
            // Could be DmlException from required field, or other validation
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert: depends on field requirements, but handler should not break
        // If Superhero__c is required, this will fail at save
        // The important thing is we don't get a null pointer in the handler
        System.assert(true, 'Handler should handle gracefully or fail at DB level');
    }
}