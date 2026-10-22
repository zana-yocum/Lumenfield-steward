import { LABELS } from "./labels";

/**
 * ST-01, ST-02, ST-06, NFR-05, NFR-07. Shared by the portal's components: the pages they link to,
 * the outcome codes the server returns, the portal's text (custom labels, in LABELS), and the words
 * a customer sees when something isn't there or goes wrong. A customer never sees an error's
 * details, only a reference to quote.
 */

export { LABELS };

/**
 * Fills a label's placeholders: format("Dispute {0} is open", "00001002").
 * @param {string} label the label, with {0}, {1}… where values go
 * @param {...*} values the values, in placeholder order
 * @returns {string} the finished text
 */
export function format(label, ...values) {
  return (label ?? "").replace(/\{(\d+)\}/g, (placeholder, index) =>
    String(values[index] ?? "")
  );
}

/**
 * The portal's pages, by the API names of their routes. The last two show one record each: a
 * statement or a dispute, named by the ID in their address (S-17).
 */
export const PAGES = {
  account: "Home",
  statements: "Statements__c",
  promises: "What_We_Promised__c",
  disputes: "Disputes__c",
  statement: "Statement__c",
  dispute: "Dispute__c"
};

/**
 * A link to one of the portal's pages.
 * @param {string} name the page's API name, from PAGES
 * @returns {object} the page reference
 */
export function namedPage(name) {
  return { type: "comm__namedPage", attributes: { name } };
}

/** Logs the customer out of the portal, the way Experience Cloud sites do it. */
export const LOGOUT_PAGE = {
  type: "comm__loginPage",
  attributes: { actionName: "logout" }
};

/**
 * A link to a statement's or a dispute's own page, with the record's ID in the address
 * (?recordId=…). The page asks the server for that ID among the household's own records, so
 * changing it reaches nothing of another household's (ST-12).
 * @param {string} recordId the record
 * @param {string} name its page: PAGES.statement or PAGES.dispute
 * @returns {object} the page reference
 */
export function recordPage(recordId, name) {
  return { type: "comm__namedPage", attributes: { name }, state: { recordId } };
}

/**
 * The record ID in the current page's address, on a statement's or a dispute's own page.
 * @param {object} pageRef the current page reference
 * @returns {string|undefined} the ID, or nothing when the address has none
 */
export function recordIdFrom(pageRef) {
  return pageRef?.state?.recordId;
}

/** The outcome codes every Steward result carries (StewardOutcome in Apex). */
export const OUTCOME = {
  completed: "COMPLETED",
  declined: "DECLINED_POLICY",
  failed: "FAILED"
};

/** The reason codes the portal explains in its own words. */
export const REASON = {
  notFound: "NOT_FOUND",
  invalidRequest: "INVALID_REQUEST",
  existingDispute: "EXISTING_DISPUTE",
  statementRequired: "STATEMENT_REQUIRED",
  invalidReason: "INVALID_REASON",
  accessDenied: "ACCESS_DENIED"
};

/** Shown when the request never got an answer: the connection, not the server. */
export const CONNECTION_PROBLEM = LABELS.connectionProblem;

/**
 * What to tell the customer about a result that isn't a success.
 * @param {object} result the server's result
 * @param {string} notFound what "not found" means on this page
 * @returns {string|null} one or two sentences, or null when the result is a success
 */
export function problemMessage(result, notFound) {
  if (!result) {
    return LABELS.tryAgain;
  }
  if (result.outcome === OUTCOME.completed) {
    return null;
  }
  if (result.outcome === OUTCOME.failed) {
    return result.reference
      ? format(LABELS.failedWithReference, result.reference)
      : LABELS.failedNoReference;
  }
  if (result.reasonCode === REASON.invalidRequest) {
    return LABELS.notACustomer;
  }
  if (result.reasonCode === REASON.notFound) {
    return notFound || LABELS.tryAgain;
  }
  return LABELS.tryAgain;
}

const currency = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD"
});
const longDate = new Intl.DateTimeFormat("en-US", {
  dateStyle: "medium",
  timeZone: "UTC"
});

/**
 * An amount as the customer reads it, such as $1,234.50.
 * @param {number} amount the amount, or nothing
 * @returns {string} the formatted amount; $0.00 when there's none
 */
export function formatMoney(amount) {
  return currency.format(amount ?? 0);
}

/**
 * A date the server sent as YYYY-MM-DD, such as Oct 1, 2026. Read as UTC so it never shifts a day
 * in the customer's time zone.
 * @param {string} isoDate the date, or nothing
 * @returns {string} the formatted date; empty when there's none
 */
export function formatDate(isoDate) {
  return isoDate ? longDate.format(new Date(`${isoDate}T00:00:00Z`)) : "";
}
