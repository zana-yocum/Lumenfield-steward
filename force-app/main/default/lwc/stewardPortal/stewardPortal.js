/**
 * ST-01, ST-02, ST-06, NFR-05, NFR-07. Shared by the portal's components: the pages they link to,
 * the outcome codes the server returns, and the words a customer sees when something isn't there
 * or goes wrong. A customer never sees an error's details, only a reference to quote.
 */

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
export const CONNECTION_PROBLEM =
  "We couldn't reach our system just now. Check your connection and try again.";

const NOT_A_CUSTOMER =
  "This page is for Lumenfield customers. Log in with your customer account to see it.";
const TRY_AGAIN = "We couldn't show this just now. Please try again later.";

/**
 * What to tell the customer about a result that isn't a success.
 * @param {object} result the server's result
 * @param {string} notFound what "not found" means on this page
 * @returns {string|null} one or two sentences, or null when the result is a success
 */
export function problemMessage(result, notFound) {
  if (!result) {
    return TRY_AGAIN;
  }
  if (result.outcome === OUTCOME.completed) {
    return null;
  }
  if (result.outcome === OUTCOME.failed) {
    return result.reference
      ? `Something went wrong on our side. If you contact us, quote reference ${result.reference}.`
      : "Something went wrong on our side. Please try again later.";
  }
  if (result.reasonCode === REASON.invalidRequest) {
    return NOT_A_CUSTOMER;
  }
  if (result.reasonCode === REASON.notFound) {
    return notFound || TRY_AGAIN;
  }
  return TRY_AGAIN;
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
