/**
 * MissionAssignmentServiceTest
 *
 * Tests the core business logic in MissionAssignmentService.
 * Covers validation rules, bulk operations, and hero status management.
 *
 * @author andrewhood
 * @date 2026-01-19
 */
@IsTest
private class MissionAssignmentServiceTest {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA SETUP
    // We create a reusable pool of heroes and missions for all test methods.
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        // Create a diverse roster of superheroes (one of each power type)
        List<Superhero__c> heroes = new List<Superhero__c>{
                new Superhero__c(
                        Name = 'Iron Guardian',
                        Alias__c = 'The Metal Man',
                        Power__c = 'Tech',
                        Home_City__c = 'Chicago',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Mystic Maven',
                        Alias__c = 'Keeper of Secrets',
                        Power__c = 'Magic',
                        Home_City__c = 'New Orleans',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Sky Sentinel',
                        Alias__c = 'The Flyer',
                        Power__c = 'Flight',
                        Home_City__c = 'Denver',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Titan',
                        Alias__c = 'The Strong One',
                        Power__c = 'Strength',
                        Home_City__c = 'Austin',
                        Status__c = 'Available'
                ),
                // This hero starts injured - useful for injury validation tests
                new Superhero__c(
                        Name = 'Wounded Warrior',
                        Alias__c = 'The Brave',
                        Power__c = 'Strength',
                        Home_City__c = 'Boston',
                        Status__c = 'Injured'
                )
        };
        insert heroes;

        // Create a couple of missions with different statuses
        List<Mission__c> missions = new List<Mission__c>{
                new Mission__c(
                        Name = 'Operation Firewall',
                        Difficulty__c = 'Hard',
                        Status__c = 'In-Progress'
                ),
                new Mission__c(
                        Name = 'Operation Cleanup',
                        Difficulty__c = 'Easy',
                        Status__c = 'Planned'
                )
        };
        insert missions;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER METHODS
    // Fetch test data by name for cleaner test methods.
    // ─────────────────────────────────────────────────────────────────────────

    static Superhero__c getHeroByName(String heroName) {
        return [SELECT Id, Name, Status__c, Is_Injured__c FROM Superhero__c WHERE Name = :heroName LIMIT 1];
    }

    static Mission__c getMissionByName(String missionName) {
        return [SELECT Id, Name, Status__c FROM Mission__c WHERE Name = :missionName LIMIT 1];
    }

    static List<Superhero__c> getAvailableHeroes() {
        return [SELECT Id, Name, Status__c FROM Superhero__c WHERE Status__c = 'Available'];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q1: HAPPY PATH - Single hero deployment
    // Verify that a single hero can be successfully assigned to a mission.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testSingleHeroDeployment_Success() {
        // Arrange: grab one hero and one mission
        Superhero__c hero = getHeroByName('Iron Guardian');
        Mission__c mission = getMissionByName('Operation Firewall');

        // Act: deploy the hero
        Test.startTest();
        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );
        insert assignment;
        Test.stopTest();

        // Assert: assignment created and hero status updated
        List<Mission_Assignment__c> assignments = [
                SELECT Id, Superhero__c, Mission__c
                FROM Mission_Assignment__c
                WHERE Mission__c = :mission.Id
        ];
        System.assertEquals(1, assignments.size(), 'One assignment should exist');

        // Hero should now be "On Mission" (handled by after insert trigger)
        Superhero__c updatedHero = getHeroByName('Iron Guardian');
        System.assertEquals('On Mission', updatedHero.Status__c, 'Hero status should be On Mission');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q2: CAPACITY LIMIT - Max 3 heroes per mission
    // The trigger should block the 4th deployment with a user-friendly error.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testMaxThreeHeroesPerMission_BlocksFourth() {
        // Arrange: we need 4 available heroes
        // Create a 5th hero since one is injured in setup
        Superhero__c extraHero = new Superhero__c(
                Name = 'Reserve Ranger',
                Alias__c = 'The Backup',
                Power__c = 'Tech',
                Status__c = 'Available'
        );
        insert extraHero;

        Mission__c mission = getMissionByName('Operation Firewall');
        List<Superhero__c> availableHeroes = [
                SELECT Id FROM Superhero__c WHERE Status__c = 'Available' LIMIT 4
        ];

        // Sanity check - we should have at least 4 available heroes
        System.assert(availableHeroes.size() >= 4, 'Need at least 4 available heroes for this test');

        // Act: deploy first 3 heroes (should succeed)
        Test.startTest();
        List<Mission_Assignment__c> firstThree = new List<Mission_Assignment__c>();
        for (Integer i = 0; i < 3; i++) {
            firstThree.add(new Mission_Assignment__c(
                    Superhero__c = availableHeroes[i].Id,
                    Mission__c = mission.Id
            ));
        }
        insert firstThree;

        // Now try to deploy the 4th hero (should fail)
        Mission_Assignment__c fourthAssignment = new Mission_Assignment__c(
                Superhero__c = availableHeroes[3].Id,
                Mission__c = mission.Id
        );

        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert fourthAssignment;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getDmlMessage(0);
        }
        Test.stopTest();

        // Assert: 4th deployment should be blocked
        System.assert(exceptionThrown, 'DmlException should be thrown for 4th hero');
        System.assert(
                errorMessage.containsIgnoreCase('capacity') || errorMessage.containsIgnoreCase('Maximum'),
                'Error message should mention capacity limit. Actual: ' + errorMessage
        );

        // Verify only 3 assignments exist
        Integer assignmentCount = [SELECT COUNT() FROM Mission_Assignment__c WHERE Mission__c = :mission.Id];
        System.assertEquals(3, assignmentCount, 'Only 3 assignments should exist');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q3: INJURY VALIDATION - Cannot deploy injured heroes
    // The system should prevent deployment of heroes with Status = 'Injured'.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testInjuredHeroDeployment_Blocked() {
        // Arrange: get the injured hero from setup
        Superhero__c injuredHero = getHeroByName('Wounded Warrior');
        Mission__c mission = getMissionByName('Operation Firewall');

        // Act: attempt to deploy injured hero
        Test.startTest();
        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = injuredHero.Id,
                Mission__c = mission.Id
        );

        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert assignment;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getDmlMessage(0);
        }
        Test.stopTest();

        // Assert: deployment should be blocked with medical alert
        System.assert(exceptionThrown, 'DmlException should be thrown for injured hero');
        System.assert(
                errorMessage.containsIgnoreCase('injured') || errorMessage.containsIgnoreCase('Medical'),
                'Error message should mention injury. Actual: ' + errorMessage
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q4: CONFLICT VALIDATION - Cannot deploy hero already on another mission
    // Heroes can only be on one active mission at a time.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testHeroAlreadyOnMission_Blocked() {
        // Arrange: deploy a hero to the first mission
        Superhero__c hero = getHeroByName('Iron Guardian');
        Mission__c mission1 = getMissionByName('Operation Firewall');
        Mission__c mission2 = getMissionByName('Operation Cleanup');

        Mission_Assignment__c firstAssignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission1.Id
        );
        insert firstAssignment;

        // Act: try to deploy same hero to a second mission
        Test.startTest();
        Mission_Assignment__c secondAssignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission2.Id
        );

        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            insert secondAssignment;
        } catch (DmlException e) {
            exceptionThrown = true;
            errorMessage = e.getDmlMessage(0);
        }
        Test.stopTest();

        // Assert: second deployment should be blocked
        System.assert(exceptionThrown, 'DmlException should be thrown for hero already on mission');
        System.assert(
                errorMessage.containsIgnoreCase('Conflict') || errorMessage.containsIgnoreCase('already'),
                'Error message should mention conflict. Actual: ' + errorMessage
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q5: BULK INSERT - Multiple assignments in single transaction
    // Validates bulkification of the trigger logic.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBulkAssignmentInsert_Success() {
        // Arrange: get 3 different heroes and 1 mission
        Mission__c mission = getMissionByName('Operation Firewall');
        List<Superhero__c> heroes = [
                SELECT Id FROM Superhero__c WHERE Status__c = 'Available' LIMIT 3
        ];

        // Act: insert all 3 assignments in a single DML
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

        // Assert: all 3 assignments should exist
        Integer assignmentCount = [SELECT COUNT() FROM Mission_Assignment__c WHERE Mission__c = :mission.Id];
        System.assertEquals(3, assignmentCount, 'All 3 bulk assignments should be created');

        // All heroes should be "On Mission"
        Integer onMissionCount = [SELECT COUNT() FROM Superhero__c WHERE Id IN :heroes AND Status__c = 'On Mission'];
        System.assertEquals(3, onMissionCount, 'All 3 heroes should be On Mission');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q6: HERO STATUS UPDATE - updateHeroStatuses method
    // Direct test of the service method that flips hero statuses.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testUpdateHeroStatuses_ToOnMission() {
        // Arrange: get some available heroes
        List<Superhero__c> heroes = [SELECT Id FROM Superhero__c WHERE Status__c = 'Available' LIMIT 2];
        Set<Id> heroIds = new Set<Id>();
        for (Superhero__c h : heroes) {
            heroIds.add(h.Id);
        }

        // Act: call the service directly
        Test.startTest();
        MissionAssignmentService.updateHeroStatuses(heroIds, 'On Mission');
        Test.stopTest();

        // Assert: heroes should now be On Mission
        List<Superhero__c> updatedHeroes = [SELECT Status__c FROM Superhero__c WHERE Id IN :heroIds];
        for (Superhero__c h : updatedHeroes) {
            System.assertEquals('On Mission', h.Status__c, 'Hero should be On Mission');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q7: RECALL FUNCTIONALITY - Deleting assignment restores availability
    // When a Mission_Assignment__c is deleted, hero should return to Available.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testRecallHero_StatusReturnsToAvailable() {
        // Arrange: deploy a hero first
        Superhero__c hero = getHeroByName('Iron Guardian');
        Mission__c mission = getMissionByName('Operation Firewall');

        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );
        insert assignment;

        // Verify hero is now On Mission
        hero = getHeroByName('Iron Guardian');
        System.assertEquals('On Mission', hero.Status__c, 'Hero should be On Mission after deployment');

        // Act: delete the assignment (recall)
        Test.startTest();
        delete assignment;
        Test.stopTest();

        // Assert: hero should be back to Available
        Superhero__c recalledHero = getHeroByName('Iron Guardian');
        System.assertEquals('Available', recalledHero.Status__c, 'Hero should be Available after recall');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q8: EMPTY SET HANDLING - updateHeroStatuses with empty set
    // Edge case: service should handle empty input gracefully.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testUpdateHeroStatuses_EmptySet() {
        // Act: call with empty set (should not throw)
        Test.startTest();
        MissionAssignmentService.updateHeroStatuses(new Set<Id>(), 'Available');
        Test.stopTest();

        // Assert: no exception thrown, test passes
        System.assert(true, 'Empty set should be handled gracefully');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q9: BULK CAPACITY VALIDATION - 4 heroes in single bulk insert
    // When inserting 4 at once, only 3 should succeed (or all fail, depending
    // on implementation). This tests the local counter increment logic.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBulkInsertExceedsCapacity_PartialFailure() {
        // Arrange: need 4 available heroes
        Superhero__c extraHero = new Superhero__c(
                Name = 'Fourth Hero',
                Alias__c = 'Number Four',
                Power__c = 'Magic',
                Status__c = 'Available'
        );
        insert extraHero;

        Mission__c mission = getMissionByName('Operation Firewall');
        List<Superhero__c> heroes = [
                SELECT Id FROM Superhero__c WHERE Status__c = 'Available' LIMIT 4
        ];

        // Act: try to insert 4 assignments at once
        Test.startTest();
        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Superhero__c h : heroes) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = h.Id,
                    Mission__c = mission.Id
            ));
        }

        Boolean exceptionThrown = false;
        try {
            insert assignments;
        } catch (DmlException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert: should fail because 4th hero exceeds capacity
        // Note: The exact behavior depends on implementation -
        // the service increments locally, so the 4th should fail
        System.assert(exceptionThrown, 'Bulk insert of 4 should fail when capacity is 3');
    }
}