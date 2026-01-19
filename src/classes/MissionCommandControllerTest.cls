/**
 * MissionCommandControllerTest
 *
 * Tests the Apex controller that powers the Mission Command LWC.
 * Covers hero retrieval, filtering, deployment, and recall operations.
 *
 * @author andrewhood
 * @date 2026-01-19
 */
@IsTest
private class MissionCommandControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA SETUP
    // Creates a realistic dataset with heroes of various powers and statuses.
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        // A diverse roster: 2 Tech, 2 Magic, 1 Flight, 1 Strength, plus 1 Injured
        List<Superhero__c> heroes = new List<Superhero__c>{
                // Tech heroes
                new Superhero__c(
                        Name = 'Circuit Breaker',
                        Alias__c = 'The Hacker',
                        Power__c = 'Tech',
                        Home_City__c = 'San Francisco',
                        Status__c = 'Available',
                        Profile_Image_URL__c = 'https://example.com/circuit.png'
                ),
                new Superhero__c(
                        Name = 'Gadget Girl',
                        Alias__c = 'The Inventor',
                        Power__c = 'Tech',
                        Home_City__c = 'Seattle',
                        Status__c = 'Available'
                ),
                // Magic heroes
                new Superhero__c(
                        Name = 'Arcane Archer',
                        Alias__c = 'The Mystic',
                        Power__c = 'Magic',
                        Home_City__c = 'Salem',
                        Status__c = 'Available'
                ),
                new Superhero__c(
                        Name = 'Spell Slinger',
                        Alias__c = 'The Wizard',
                        Power__c = 'Magic',
                        Home_City__c = 'New Orleans',
                        Status__c = 'Available'
                ),
                // Flight hero
                new Superhero__c(
                        Name = 'Cloud Rider',
                        Alias__c = 'The Aviator',
                        Power__c = 'Flight',
                        Home_City__c = 'Denver',
                        Status__c = 'Available'
                ),
                // Strength hero
                new Superhero__c(
                        Name = 'Boulder',
                        Alias__c = 'The Mountain',
                        Power__c = 'Strength',
                        Home_City__c = 'Boulder',
                        Status__c = 'Available'
                ),
                // Injured hero (should be excluded from roster)
                new Superhero__c(
                        Name = 'Fallen Star',
                        Alias__c = 'The Recovering',
                        Power__c = 'Flight',
                        Home_City__c = 'Phoenix',
                        Status__c = 'Injured'
                )
        };
        insert heroes;

        // Create missions for testing context
        List<Mission__c> missions = new List<Mission__c>{
                new Mission__c(
                        Name = 'Operation Alpha',
                        Difficulty__c = 'Hard',
                        Status__c = 'In-Progress'
                ),
                new Mission__c(
                        Name = 'Operation Beta',
                        Difficulty__c = 'Medium',
                        Status__c = 'Planned'
                )
        };
        insert missions;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER METHODS
    // ─────────────────────────────────────────────────────────────────────────

    static Superhero__c getHeroByName(String heroName) {
        return [SELECT Id, Name, Status__c FROM Superhero__c WHERE Name = :heroName LIMIT 1];
    }

    static Mission__c getMissionByName(String missionName) {
        return [SELECT Id, Name, Status__c FROM Mission__c WHERE Name = :missionName LIMIT 1];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q1: getMissionDetails - Retrieve mission record
    // Verifies that the controller correctly fetches mission info by Id.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetMissionDetails_Success() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        Mission__c result = MissionCommandController.getMissionDetails(mission.Id);
        Test.stopTest();

        // Assert
        System.assertNotEquals(null, result, 'Mission should be returned');
        System.assertEquals('Operation Alpha', result.Name, 'Mission name should match');
        System.assertEquals('In-Progress', result.Status__c, 'Mission status should match');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q2: getPowerOptions - Retrieve picklist values
    // Verifies that power options include "All" plus each picklist value.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetPowerOptions_ReturnsAllValues() {
        // Act
        Test.startTest();
        List<Map<String, String>> options = MissionCommandController.getPowerOptions();
        Test.stopTest();

        // Assert: should have "All" plus the 4 power types
        System.assert(options.size() >= 5, 'Should have at least 5 options (All + 4 powers)');

        // First option should be "All Powers"
        System.assertEquals('All', options[0].get('value'), 'First option value should be All');
        System.assertEquals('All Powers', options[0].get('label'), 'First option label should be All Powers');

        // Verify power types exist
        Set<String> powerValues = new Set<String>();
        for (Map<String, String> opt : options) {
            powerValues.add(opt.get('value'));
        }
        System.assert(powerValues.contains('Tech'), 'Should contain Tech');
        System.assert(powerValues.contains('Magic'), 'Should contain Magic');
        System.assert(powerValues.contains('Flight'), 'Should contain Flight');
        System.assert(powerValues.contains('Strength'), 'Should contain Strength');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q3: getHeroesForMission - No filter (All powers)
    // Should return all non-injured heroes with correct wrapper data.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_AllPowers() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'All');
        Test.stopTest();

        // Assert: should return 6 heroes (7 total - 1 injured)
        System.assertEquals(6, heroes.size(), 'Should return 6 non-injured heroes');

        // Verify wrapper fields are populated
        MissionCommandController.HeroWrapper firstHero = heroes[0];
        System.assertNotEquals(null, firstHero.id, 'Hero Id should be populated');
        System.assertNotEquals(null, firstHero.name, 'Hero name should be populated');
        System.assertNotEquals(null, firstHero.power, 'Hero power should be populated');
        System.assertEquals('Available', firstHero.effectiveStatus, 'Heroes should be Available');
        System.assertEquals(true, firstHero.isAvailable, 'isAvailable should be true');
        System.assertEquals(false, firstHero.isDeployedHere, 'isDeployedHere should be false');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q4: getHeroesForMission - Filter by Tech
    // Should only return heroes with Power__c = 'Tech'.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_FilterByTech() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'Tech');
        Test.stopTest();

        // Assert: should return only the 2 Tech heroes
        System.assertEquals(2, heroes.size(), 'Should return 2 Tech heroes');
        for (MissionCommandController.HeroWrapper h : heroes) {
            System.assertEquals('Tech', h.power, 'All returned heroes should have Tech power');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q5: getHeroesForMission - Filter by Magic
    // Should only return heroes with Power__c = 'Magic'.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_FilterByMagic() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'Magic');
        Test.stopTest();

        // Assert: should return only the 2 Magic heroes
        System.assertEquals(2, heroes.size(), 'Should return 2 Magic heroes');
        for (MissionCommandController.HeroWrapper h : heroes) {
            System.assertEquals('Magic', h.power, 'All returned heroes should have Magic power');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q6: getHeroesForMission - Excludes injured heroes
    // Even though "Fallen Star" exists with Flight power, they're injured.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_ExcludesInjured() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> flightHeroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'Flight');
        Test.stopTest();

        // Assert: only 1 Flight hero (Cloud Rider), not 2 (Fallen Star is injured)
        System.assertEquals(1, flightHeroes.size(), 'Should return only 1 Flight hero (injured excluded)');
        System.assertEquals('Cloud Rider', flightHeroes[0].name, 'Should be Cloud Rider');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q7: getHeroesForMission - Shows deployed status correctly
    // After deploying a hero, they should show as "On Mission" with correct flags.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_ShowsDeployedStatus() {
        // Arrange: deploy a hero to the mission
        Mission__c mission = getMissionByName('Operation Alpha');
        Superhero__c hero = getHeroByName('Circuit Breaker');

        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );
        insert assignment;

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'All');
        Test.stopTest();

        // Assert: find Circuit Breaker and verify their status
        MissionCommandController.HeroWrapper deployedHero;
        for (MissionCommandController.HeroWrapper h : heroes) {
            if (h.name == 'Circuit Breaker') {
                deployedHero = h;
                break;
            }
        }

        System.assertNotEquals(null, deployedHero, 'Circuit Breaker should be in results');
        System.assertEquals(true, deployedHero.isDeployedHere, 'Should be marked as deployed here');
        System.assertEquals('On Mission', deployedHero.effectiveStatus, 'Effective status should be On Mission');
        System.assertEquals(false, deployedHero.isAvailable, 'Should not be available');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q8: getHeroesForMission - Shows conflict status
    // A hero deployed to Mission A should show as conflicted on Mission B.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_ShowsConflict() {
        // Arrange: deploy hero to Mission Alpha
        Mission__c missionAlpha = getMissionByName('Operation Alpha');
        Mission__c missionBeta = getMissionByName('Operation Beta');
        Superhero__c hero = getHeroByName('Arcane Archer');

        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = missionAlpha.Id
        );
        insert assignment;

        // Act: fetch heroes for Mission Beta
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(missionBeta.Id, 'All');
        Test.stopTest();

        // Assert: Arcane Archer should show as conflicted
        MissionCommandController.HeroWrapper conflictedHero;
        for (MissionCommandController.HeroWrapper h : heroes) {
            if (h.name == 'Arcane Archer') {
                conflictedHero = h;
                break;
            }
        }

        System.assertNotEquals(null, conflictedHero, 'Arcane Archer should be in results');
        System.assertEquals(true, conflictedHero.hasConflict, 'Should have conflict flag');
        System.assertEquals(false, conflictedHero.isDeployedHere, 'Should NOT be deployed here (different mission)');
        System.assertEquals('Operation Alpha', conflictedHero.conflictingMissionName, 'Should show conflicting mission name');
        System.assertEquals(false, conflictedHero.isAvailable, 'Should not be available');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q9: deployHeroToMission - Successful deployment
    // The controller method should create an assignment and trigger status update.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDeployHeroToMission_Success() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');
        Superhero__c hero = getHeroByName('Boulder');

        // Act
        Test.startTest();
        MissionCommandController.deployHeroToMission(hero.Id, mission.Id);
        Test.stopTest();

        // Assert: assignment should exist
        List<Mission_Assignment__c> assignments = [
                SELECT Id FROM Mission_Assignment__c
                WHERE Superhero__c = :hero.Id AND Mission__c = :mission.Id
        ];
        System.assertEquals(1, assignments.size(), 'Assignment should be created');

        // Hero should be On Mission
        Superhero__c updatedHero = getHeroByName('Boulder');
        System.assertEquals('On Mission', updatedHero.Status__c, 'Hero should be On Mission');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q10: deployHeroToMission - Fourth hero blocked
    // Should throw AuraHandledException with clean error message.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDeployHeroToMission_FourthHeroBlocked() {
        // Arrange: deploy 3 heroes first
        Mission__c mission = getMissionByName('Operation Alpha');
        List<Superhero__c> heroes = [
                SELECT Id FROM Superhero__c WHERE Status__c = 'Available' LIMIT 4
        ];

        for (Integer i = 0; i < 3; i++) {
            insert new Mission_Assignment__c(
                    Superhero__c = heroes[i].Id,
                    Mission__c = mission.Id
            );
        }

        // Act: try to deploy 4th hero via controller
        Test.startTest();
        Boolean exceptionThrown = false;
        String errorMessage = '';
        try {
            MissionCommandController.deployHeroToMission(heroes[3].Id, mission.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        // Assert: should throw user-friendly error
        System.assert(exceptionThrown, 'AuraHandledException should be thrown');
        System.assert(
                errorMessage.containsIgnoreCase('capacity') || errorMessage.containsIgnoreCase('Maximum'),
                'Error should mention capacity. Actual: ' + errorMessage
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q11: recallHeroFromMission - Successful recall
    // Should delete assignment and restore hero to Available.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testRecallHeroFromMission_Success() {
        // Arrange: deploy hero first
        Mission__c mission = getMissionByName('Operation Alpha');
        Superhero__c hero = getHeroByName('Spell Slinger');

        insert new Mission_Assignment__c(
                Superhero__c = hero.Id,
                Mission__c = mission.Id
        );

        // Verify deployment worked
        hero = getHeroByName('Spell Slinger');
        System.assertEquals('On Mission', hero.Status__c, 'Hero should be On Mission before recall');

        // Act
        Test.startTest();
        MissionCommandController.recallHeroFromMission(hero.Id, mission.Id);
        Test.stopTest();

        // Assert: assignment should be deleted
        List<Mission_Assignment__c> assignments = [
                SELECT Id FROM Mission_Assignment__c
                WHERE Superhero__c = :hero.Id AND Mission__c = :mission.Id
        ];
        System.assertEquals(0, assignments.size(), 'Assignment should be deleted');

        // Hero should be Available
        Superhero__c recalledHero = getHeroByName('Spell Slinger');
        System.assertEquals('Available', recalledHero.Status__c, 'Hero should be Available after recall');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q12: recallHeroFromMission - No assignment exists (edge case)
    // Should handle gracefully when there's nothing to recall.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testRecallHeroFromMission_NoAssignment() {
        // Arrange: hero not deployed to this mission
        Mission__c mission = getMissionByName('Operation Alpha');
        Superhero__c hero = getHeroByName('Gadget Girl');

        // Act: try to recall (should not throw)
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            MissionCommandController.recallHeroFromMission(hero.Id, mission.Id);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        // Assert: should handle gracefully (no assignment to delete = no-op)
        System.assertEquals(false, exceptionThrown, 'Should not throw when no assignment exists');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q13: Profile Image URL - Verify optional field is returned
    // The wrapper should include the profile image URL when present.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_IncludesProfileImageUrl() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, 'Tech');
        Test.stopTest();

        // Assert: Circuit Breaker has a profile image URL
        MissionCommandController.HeroWrapper circuitBreaker;
        for (MissionCommandController.HeroWrapper h : heroes) {
            if (h.name == 'Circuit Breaker') {
                circuitBreaker = h;
                break;
            }
        }

        System.assertNotEquals(null, circuitBreaker, 'Circuit Breaker should be found');
        System.assertEquals(
                'https://example.com/circuit.png',
                circuitBreaker.profileImageUrl,
                'Profile image URL should be populated'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Q14: Filter with null value - Treated as "All"
    // Passing null for powerFilter should return all heroes.
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testGetHeroesForMission_NullFilter() {
        // Arrange
        Mission__c mission = getMissionByName('Operation Alpha');

        // Act
        Test.startTest();
        List<MissionCommandController.HeroWrapper> heroes =
                MissionCommandController.getHeroesForMission(mission.Id, null);
        Test.stopTest();

        // Assert: should return all non-injured heroes (same as 'All')
        System.assertEquals(6, heroes.size(), 'Null filter should return all 6 non-injured heroes');
    }
}