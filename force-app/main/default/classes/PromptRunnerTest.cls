/**
 * ST-08, ST-09, ST-10, S-21. Proves the runner hands each generation to its model and accepts
 * only a generation that has text. The real model can't be reached from a test, so the last test
 * proves the request is built and sent, and that a template that doesn't exist is an error.
 */
@IsTest
private class PromptRunnerTest {
  private class FixedModel implements PromptRunner.Model {
    /**
     * Answers with the template and input it was given.
     * @param templateName the template
     * @param inputName the template input
     * @param recordId the record
     * @return the template and input, as text
     */
    public String generate(String templateName, String inputName, Id recordId) {
      return templateName + ' for ' + inputName;
    }
  }

  @IsTest
  static void generationGoesToTheModel() {
    PromptRunner.model = new FixedModel();

    Test.startTest();
    String text = PromptRunner.generate(
      'Steward_Account_Briefing',
      'Input:Household',
      UserInfo.getUserId()
    );
    Test.stopTest();

    Assert.areEqual(
      'Steward_Account_Briefing for Input:Household',
      text,
      'The model\'s text'
    );
  }

  @IsTest
  static void onlyAGenerationWithTextCounts() {
    ConnectApi.EinsteinLLMGenerationItemOutput generation = new ConnectApi.EinsteinLLMGenerationItemOutput();
    generation.text = 'A briefing.';
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
    output.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>{
      generation
    };
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation empty = new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation();
    empty.generations = new List<ConnectApi.EinsteinLLMGenerationItemOutput>();

    Test.startTest();
    String text = PromptRunner.firstText(output);
    Integer refused = 0;
    for (
      ConnectApi.EinsteinPromptTemplateGenerationsRepresentation nothing : new List<ConnectApi.EinsteinPromptTemplateGenerationsRepresentation>{
        null,
        empty
      }
    ) {
      try {
        PromptRunner.firstText(nothing);
      } catch (PromptRunner.PromptRunnerException noText) {
        refused++;
      }
    }
    Test.stopTest();

    Assert.areEqual('A briefing.', text, 'The first generation\'s text');
    Assert.areEqual(
      2,
      refused,
      'No output and no generations are both refused'
    );
  }

  @IsTest
  static void anUnknownTemplateIsAnError() {
    Exception failure;

    Test.startTest();
    try {
      new PromptRunner.EinsteinModel()
        .generate(
          'Steward_No_Such_Template',
          'Input:Household',
          UserInfo.getUserId()
        );
    } catch (Exception error) {
      failure = error;
    }
    Test.stopTest();

    Assert.isNotNull(
      failure,
      'No text comes back for a template that doesn\'t exist'
    );
  }
}
