import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getStatement from "@salesforce/apex/PortalAccountController.getStatement";
import {
  CONNECTION_PROBLEM,
  LABELS,
  OUTCOME,
  PAGES,
  format,
  namedPage,
  problemMessage,
  recordIdFrom
} from "c/portalShared";

const NOT_YOURS = LABELS.statementNotYours;

/** Stripe sends the customer back with these in the address (PaymentCheckoutService). */
const SESSION_PARAM = "c__session_id";
const PAYMENT_PARAM = "c__payment";
const CANCELLED = "cancelled";

/**
 * ST-01, ST-05, ST-12. A statement's own page. The ID comes from the address (?recordId=…), so
 * the server looks for it only among the logged-in household's statements: another household's ID
 * gets the same answer as one that doesn't exist, and nothing about it reaches the browser. Below
 * the statement, Pay online (portalPayment), which also reads what Stripe put in the address on
 * the way back.
 */
export default class PortalStatementDetail extends NavigationMixin(
  LightningElement
) {
  labels = LABELS;
  loading = true;
  statementId;
  statement;
  problem;
  statementsUrl;
  hasPage = false;
  /** The checkout session Stripe sent the customer back from, if any. */
  paymentSession;
  /** True when the customer came back from Stripe without paying. */
  paymentCancelled = false;

  @wire(CurrentPageReference)
  setCurrentPage(pageRef) {
    const statementId = recordIdFrom(pageRef);
    if (!pageRef || (this.hasPage && statementId === this.statementId)) {
      return;
    }
    this.hasPage = true;
    this.statementId = statementId;
    this.paymentSession = pageRef.state?.[SESSION_PARAM];
    this.paymentCancelled = pageRef.state?.[PAYMENT_PARAM] === CANCELLED;
    this.load();
  }

  connectedCallback() {
    this[NavigationMixin.GenerateUrl](namedPage(PAGES.statements)).then(
      (url) => {
        this.statementsUrl = url;
      }
    );
  }

  async load() {
    const requested = this.statementId;
    this.loading = true;
    this.statement = null;
    this.problem = null;
    if (!requested) {
      this.problem = NOT_YOURS;
      this.loading = false;
      return;
    }
    try {
      const result = await getStatement({ statementId: requested });
      if (requested !== this.statementId) {
        return;
      }
      this.problem = problemMessage(result, NOT_YOURS);
      this.statement = this.problem ? null : result.statement;
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      if (requested === this.statementId) {
        this.loading = false;
      }
    }
  }

  /**
   * Reads the statement again without clearing the page, after a payment, so it shows the new
   * balance and payment.
   */
  async handleRefresh() {
    const requested = this.statementId;
    try {
      const result = await getStatement({ statementId: requested });
      if (
        requested === this.statementId &&
        result?.outcome === OUTCOME.completed
      ) {
        this.statement = result.statement;
      }
    } catch {
      // The statement on screen stays; the customer can reload the page.
    }
  }

  get title() {
    return this.statement
      ? format(LABELS.statementNumbered, this.statement.statementNumber)
      : LABELS.statement;
  }

  handleBack(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.statements));
  }
}
