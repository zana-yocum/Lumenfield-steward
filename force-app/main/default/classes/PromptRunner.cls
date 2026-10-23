/**
 * ST-08, ST-09, ST-10, S-21. Runs a Steward prompt template for one record and returns the
 * model's text. The only place Steward's Apex calls a model: the request goes through the Einstein
 * Trust Layer like any Prompt Builder generation, and the template's Apex grounding runs as the
 * same user. A test can't reach a model, so tests replace the model with a stand-in.
 */
public with sharing class PromptRunner {
  // The application name Salesforce documents for generations started from Apex.
  private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';

  // The model every generation goes to. Tests put a stand-in here.
  @TestVisible
  private static Model model = new EinsteinModel();

  /** Something that turns a template and a record into text. */
  public interface Model {
    /**
     * Generates text from a prompt template.
     * @param templateName the template's API name
     * @param inputName the template input the record fills, such as Input:Household
     * @param recordId the record
     * @return the model's text
     */
    String generate(String templateName, String inputName, Id recordId);
  }

  /** Raised when a generation comes back without text. */
  public class PromptRunnerException extends Exception {
  }

  /**
   * Generates text from a prompt template for one record.
   * @param templateName the template's API name
   * @param inputName the template input the record fills, such as Input:Household
   * @param recordId the record
   * @return the model's text
   */
  public static String generate(
    String templateName,
    String inputName,
    Id recordId
  ) {
    return model.generate(templateName, inputName, recordId);
  }

  /**
   * The first generation's text.
   * @param output what the Einstein LLM API returned
   * @return the text
   */
  @TestVisible
  private static String firstText(
    ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output
  ) {
    if (
      output == null ||
      output.generations == null ||
      output.generations.isEmpty() ||
      String.isBlank(output.generations[0].text)
    ) {
      throw new PromptRunnerException('The model returned no text.');
    }
    return output.generations[0].text;
  }

  /** The real model, through ConnectApi.EinsteinLLM. */
  @TestVisible
  private class EinsteinModel implements Model {
    /**
     * Generates text from a prompt template through the Einstein Trust Layer.
     * @param templateName the template's API name
     * @param inputName the template input the record fills
     * @param recordId the record
     * @return the model's text
     */
    public String generate(String templateName, String inputName, Id recordId) {
      ConnectApi.WrappedValue record = new ConnectApi.WrappedValue();
      record.value = new Map<String, String>{ 'id' => recordId };
      ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
      input.inputParams = new Map<String, ConnectApi.WrappedValue>{
        inputName => record
      };
      input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
      input.additionalConfig.applicationName = APPLICATION_NAME;
      input.isPreview = false;
      return firstText(
        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
          templateName,
          input
        )
      );
    }
  }
}
