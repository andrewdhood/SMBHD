/**
 * TestDataFactory
 *
 * Utility class for creating test data across all Mission Command test classes.
 * Centralizes test data creation for consistency and maintainability.
 *
 * Usage:
 *   List<Superhero__c> heroes = TestDataFactory.createHeroes(5);
 *   Mission__c mission = TestDataFactory.createMission('Test Mission', 'Hard', 'In-Progress');
 *
 * @author andrewhood
 * @date 2026-01-19
 */
@IsTest
public class TestDataFactory {

    // ─────────────────────────────────────────────────────────────────────────
    // SUPERHERO CREATION
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates a batch of available superheroes with rotating powers.
     * @param count Number of heroes to create
     * @return Inserted list of Superhero__c records
     */
    public static List<Superhero__c> createHeroes(Integer count) {
        List<String> powers = new List<String>{'Strength', 'Flight', 'Magic', 'Tech'};
        List<Superhero__c> heroes = new List<Superhero__c>();

        for (Integer i = 0; i < count; i++) {
            heroes.add(new Superhero__c(
                    Name = 'Test Hero ' + i,
                    Alias__c = 'Alias ' + i,
                    Power__c = powers[Math.mod(i, 4)],  // Rotates through powers
                    Home_City__c = 'Test City',
                    Status__c = 'Available'
            ));
        }

        insert heroes;
        return heroes;
    }

    /**
     * Creates a single superhero with specified attributes.
     * @param name Hero name
     * @param power Power type (Strength, Flight, Magic, Tech)
     * @param status Status (Available, On Mission, Injured)
     * @return Inserted Superhero__c record
     */
    public static Superhero__c createHero(String name, String power, String status) {
        Superhero__c hero = new Superhero__c(
                Name = name,
                Alias__c = name + ' Alias',
                Power__c = power,
                Home_City__c = 'Test City',
                Status__c = status
        );
        insert hero;
        return hero;
    }

    /**
     * Creates a hero with profile image URL.
     * @param name Hero name
     * @param power Power type
     * @param imageUrl Profile image URL
     * @return Inserted Superhero__c record
     */
    public static Superhero__c createHeroWithImage(String name, String power, String imageUrl) {
        Superhero__c hero = new Superhero__c(
                Name = name,
                Alias__c = name + ' Alias',
                Power__c = power,
                Home_City__c = 'Test City',
                Status__c = 'Available',
                Profile_Image_URL__c = imageUrl
        );
        insert hero;
        return hero;
    }

    /**
     * Creates an injured hero (useful for validation tests).
     * @param name Hero name
     * @return Inserted injured Superhero__c record
     */
    public static Superhero__c createInjuredHero(String name) {
        Superhero__c hero = new Superhero__c(
                Name = name,
                Alias__c = name + ' Alias',
                Power__c = 'Strength',
                Home_City__c = 'Test City',
                Status__c = 'Injured'
        );
        insert hero;
        return hero;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MISSION CREATION
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates a mission with specified attributes.
     * @param name Mission name
     * @param difficulty Difficulty level
     * @param status Mission status (Planned, In-Progress, Complete, Cancelled)
     * @return Inserted Mission__c record
     */
    public static Mission__c createMission(String name, String difficulty, String status) {
        Mission__c mission = new Mission__c(
                Name = name,
                Difficulty__c = difficulty,
                Status__c = status
        );
        insert mission;
        return mission;
    }

    /**
     * Creates a simple "In-Progress" mission.
     * @param name Mission name
     * @return Inserted Mission__c record
     */
    public static Mission__c createActiveMission(String name) {
        return createMission(name, 'Medium', 'In-Progress');
    }

    /**
     * Creates multiple missions.
     * @param count Number of missions to create
     * @return List of inserted Mission__c records
     */
    public static List<Mission__c> createMissions(Integer count) {
        List<Mission__c> missions = new List<Mission__c>();
        List<String> difficulties = new List<String>{'Easy', 'Medium', 'Hard'};

        for (Integer i = 0; i < count; i++) {
            missions.add(new Mission__c(
                    Name = 'Test Mission ' + i,
                    Difficulty__c = difficulties[Math.mod(i, 3)],
                    Status__c = 'Planned'
            ));
        }

        insert missions;
        return missions;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MISSION ASSIGNMENT CREATION
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates a mission assignment (deploys a hero to a mission).
     * @param heroId Superhero record Id
     * @param missionId Mission record Id
     * @return Inserted Mission_Assignment__c record
     */
    public static Mission_Assignment__c createAssignment(Id heroId, Id missionId) {
        Mission_Assignment__c assignment = new Mission_Assignment__c(
                Superhero__c = heroId,
                Mission__c = missionId
        );
        insert assignment;
        return assignment;
    }

    /**
     * Deploys multiple heroes to a single mission.
     * @param heroes List of heroes to deploy
     * @param missionId Target mission Id
     * @return List of inserted Mission_Assignment__c records
     */
    public static List<Mission_Assignment__c> deployHeroesToMission(List<Superhero__c> heroes, Id missionId) {
        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Superhero__c h : heroes) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = h.Id,
                    Mission__c = missionId
            ));
        }
        insert assignments;
        return assignments;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // COMPOSITE DATA CREATION
    // Convenience methods for common test scenarios.
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Creates a complete test scenario: heroes + mission + assignments.
     * Useful for quickly setting up a "mission at capacity" scenario.
     * @return Map with keys: 'heroes' (List<Superhero__c>), 'mission' (Mission__c), 'assignments' (List<Mission_Assignment__c>)
     */
    public static Map<String, Object> createFullMissionScenario() {
        // Create 4 heroes (one extra for "over capacity" tests)
        List<Superhero__c> heroes = createHeroes(4);

        // Create a mission
        Mission__c mission = createActiveMission('Full Mission Test');

        // Deploy 3 heroes (at capacity)
        List<Mission_Assignment__c> assignments = new List<Mission_Assignment__c>();
        for (Integer i = 0; i < 3; i++) {
            assignments.add(new Mission_Assignment__c(
                    Superhero__c = heroes[i].Id,
                    Mission__c = mission.Id
            ));
        }
        insert assignments;

        Map<String, Object> result = new Map<String, Object>();
        result.put('heroes', heroes);
        result.put('mission', mission);
        result.put('assignments', assignments);
        return result;
    }

    /**
     * Creates heroes with specific powers for filter testing.
     * @return Map of power type to list of heroes
     */
    public static Map<String, List<Superhero__c>> createHeroesByPower() {
        Map<String, List<Superhero__c>> heroesByPower = new Map<String, List<Superhero__c>>();

        List<Superhero__c> allHeroes = new List<Superhero__c>();

        // 2 of each power type
        for (String power : new List<String>{'Strength', 'Flight', 'Magic', 'Tech'}) {
            List<Superhero__c> powerHeroes = new List<Superhero__c>();
            for (Integer i = 1; i <= 2; i++) {
                Superhero__c h = new Superhero__c(
                        Name = power + ' Hero ' + i,
                        Alias__c = power + ' Alias ' + i,
                        Power__c = power,
                        Status__c = 'Available'
                );
                allHeroes.add(h);
                powerHeroes.add(h);
            }
            heroesByPower.put(power, powerHeroes);
        }

        insert allHeroes;
        return heroesByPower;
    }
}