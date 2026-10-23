import writing from "@salesforce/label/c.Steward_Rep_Writing";
import disclaimer from "@salesforce/label/c.Steward_Rep_Disclaimer";
import generatedRegion from "@salesforce/label/c.Steward_Rep_Generated_Region";
import close from "@salesforce/label/c.Steward_Rep_Close";
import writeAgain from "@salesforce/label/c.Steward_Rep_Write_Again";
import briefingTitle from "@salesforce/label/c.Steward_Rep_Briefing_Title";
import summaryTitle from "@salesforce/label/c.Steward_Rep_Summary_Title";
import followupTitle from "@salesforce/label/c.Steward_Rep_Followup_Title";
import notFound from "@salesforce/label/c.Steward_Rep_Not_Found";
import noAttemptToday from "@salesforce/label/c.Steward_Rep_No_Attempt_Today";
import failed from "@salesforce/label/c.Steward_Rep_Failed";

/**
 * ST-08, ST-09, ST-10, S-21. Shared by the rep assistant's buttons: their text (custom labels,
 * Steward_Rep_*), the outcome codes RepAssistantController returns, and the words for a result
 * that isn't text to show.
 */
export const LABELS = {
  writing,
  disclaimer,
  generatedRegion,
  close,
  writeAgain,
  briefingTitle,
  summaryTitle,
  followupTitle,
  notFound,
  noAttemptToday,
  failed
};

/** The outcome codes every Steward result carries (StewardOutcome in Apex). */
export const OUTCOME = {
  completed: "COMPLETED",
  declined: "DECLINED_POLICY",
  failed: "FAILED"
};

const REASON_MESSAGES = {
  NOT_FOUND: notFound,
  NO_ATTEMPT_TODAY: noAttemptToday
};

/**
 * What the rep reads instead of generated text: why there's nothing, in the assistant's words.
 * @param {object} result what RepAssistantController returned
 * @returns {string} the message; the general failure message for anything unexpected
 */
export function messageFor(result) {
  return (result && REASON_MESSAGES[result.reasonCode]) || failed;
}

/**
 * What a button shows for a result: the text when there is some, otherwise why there isn't.
 * @param {object} result what RepAssistantController returned
 * @returns {object} text, message and detail; only the ones that apply are set
 */
export function viewOf(result) {
  if (result?.outcome === OUTCOME.completed) {
    return { text: result.text };
  }
  return { message: messageFor(result), detail: result?.detail };
}

/**
 * What a button shows when the call to the server itself failed. An internal user sees the
 * server's message as the detail.
 * @param {object} error what the Apex call threw
 * @returns {object} the general failure message and the detail
 */
export function viewOfError(error) {
  return { message: messageFor(null), detail: error?.body?.message };
}
