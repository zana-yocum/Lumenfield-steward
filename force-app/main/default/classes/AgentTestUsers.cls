/**
 * S-01, ST-12, NFR-03. The service agent's user, for tests that run actions the way the agent will:
 * a user on the Einstein Agent User profile, with only PS_Steward_Agent and membership of the
 * Steward Agent group, and the group given by hand exactly what its two sharing rules give it.
 * A check-only deployment doesn't apply the sharing rules it brings, and tests make their own
 * records, so the rules themselves are checked in the org after each release.
 */
@IsTest
public class AgentTestUsers {
  public static final String AGENT_PROFILE = 'Einstein Agent User';
  public static final String AGENT_PERMISSION_SET = 'PS_Steward_Agent';
  public static final String AGENT_GROUP = 'Steward_Agent';

  /**
   * Inserts an agent user with only the agent's access, and shares the households with its group
   * the way the sharing rules do.
   * @param households the households the rules would share
   * @return the agent user
   */
  public static User createAgentUser(
    List<StewardTestData.Household> households
  ) {
    String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
    User agent = new User(
      Alias = 'stwagent',
      Email = 'steward.agent.' + unique + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Steward Agent',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = :AGENT_PROFILE LIMIT 1]
      .Id,
      TimeZoneSidKey = 'America/New_York',
      Username = 'steward.agent.' + unique + '@example.com'
    );
    Id agentGroup = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = :AGENT_GROUP AND Type = 'Regular'
      LIMIT 1
    ]
    .Id;
    shareLikeTheRules(households, agentGroup);
    // Users, permission set assignments and group members are setup records: their own context.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert agent;
      insert new PermissionSetAssignment(
        AssigneeId = agent.Id,
        PermissionSetId = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = :AGENT_PERMISSION_SET
          LIMIT 1
        ]
        .Id
      );
      insert new GroupMember(GroupId = agentGroup, UserOrGroupId = agent.Id);
    }
    return agent;
  }

  /**
   * The agent user a test's setup created.
   * @return the user
   */
  public static User existingAgentUser() {
    return [
      SELECT Id
      FROM User
      WHERE
        Profile.Name = :AGENT_PROFILE
        AND Alias = 'stwagent'
        AND IsActive = TRUE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
  }

  /**
   * What Households_to_Steward_Agent and Agreements_to_Steward_Agent give the group.
   * @param households the test's households
   * @param agentGroup the Steward Agent group
   */
  private static void shareLikeTheRules(
    List<StewardTestData.Household> households,
    Id agentGroup
  ) {
    List<SObject> shares = new List<SObject>();
    Set<Id> accountIds = new Set<Id>();
    for (StewardTestData.Household household : households) {
      accountIds.add(household.account.Id);
      shares.add(
        new AccountShare(
          AccountId = household.account.Id,
          UserOrGroupId = agentGroup,
          AccountAccessLevel = 'Edit',
          CaseAccessLevel = 'Read',
          OpportunityAccessLevel = 'None'
        )
      );
    }
    for (ServiceContract agreement : [
      SELECT Id
      FROM ServiceContract
      WHERE AccountId IN :accountIds
      WITH SYSTEM_MODE
    ]) {
      shares.add(
        new ServiceContractShare(
          ParentId = agreement.Id,
          UserOrGroupId = agentGroup,
          AccessLevel = 'Read'
        )
      );
    }
    insert shares;
  }
}
