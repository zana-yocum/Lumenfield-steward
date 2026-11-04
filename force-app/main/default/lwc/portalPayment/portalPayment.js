import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import startPayment from "@salesforce/apex/PortalPaymentsController.startPayment";
import confirmPayment from "@salesforce/apex/PortalPaymentsController.confirmPayment";
import {
  CONNECTION_PROBLEM,
  LABELS,
  OUTCOME,
  format,
  formatMoney
} from "c/portalShared";

const NOTHING_OWED = "NOTHING_OWED";
const NOT_PAID = "NOT_PAID";
const NOT_FOUND = "NOT_FOUND";

/**
 * ST-05, ST-12, NFR-07. Paying a statement online, on its own page. Pay sends the customer to
 * Stripe's secure checkout page for the statement's balance; card details are typed there and
 * never reach Lumenfield. When Stripe sends the customer back, the page says whether the payment
 * went through. A payment recorded at once fires refresh, so the statement shows it in place; one
 * the platform refused for now says it will show within the hour, when reconciliation records it.
 */
export default class PortalPayment extends NavigationMixin(LightningElement) {
  /** The statement on this page. */
  @api statementId;
  /** Its balance; the Pay button shows only when there's one to pay. */
  @api balance;
  /** Set when Stripe sends the customer back after paying: the session to check. */
  @api sessionId;
  /** Set when the customer came back from Stripe without paying. */
  @api cancelled = false;

  labels = LABELS;
  opening = false;
  checking = false;
  /** What happened on the way back, or why Pay didn't open the page. */
  notice;
  /** Whether the notice is a problem, read out at once. */
  noticeIsProblem = false;
  paid = false;
  /** True when Stripe has the payment but the statement won't show it until reconciliation. */
  recordedLater = false;
  checkedSession;

  connectedCallback() {
    if (this.sessionId) {
      this.confirm();
    } else if (this.cancelled) {
      this.notice = LABELS.payNotTaken;
    }
  }

  get canPay() {
    return !this.paid && !this.checking && Number(this.balance) > 0;
  }

  get payLabel() {
    return this.opening
      ? LABELS.payOpening
      : format(LABELS.payButton, formatMoney(this.balance));
  }

  get busy() {
    return this.opening ? "true" : undefined;
  }

  get noticeRole() {
    return this.noticeIsProblem ? "alert" : "status";
  }

  get noticeClass() {
    return this.noticeIsProblem ? "notice" : "lead";
  }

  async handlePay() {
    if (this.opening) {
      return;
    }
    this.opening = true;
    this.notice = undefined;
    try {
      const result = await startPayment({ statementId: this.statementId });
      if (result?.outcome === OUTCOME.completed && result.checkoutUrl) {
        this[NavigationMixin.Navigate]({
          type: "standard__webPage",
          attributes: { url: result.checkoutUrl }
        });
        return;
      }
      this.showProblem(this.startProblem(result));
    } catch {
      this.showProblem(CONNECTION_PROBLEM);
    }
    this.opening = false;
  }

  async confirm() {
    if (this.checkedSession === this.sessionId) {
      return;
    }
    this.checkedSession = this.sessionId;
    this.checking = true;
    try {
      const result = await confirmPayment({ sessionId: this.sessionId });
      if (result?.outcome === OUTCOME.completed) {
        this.paid = true;
        this.noticeIsProblem = false;
        this.notice = format(LABELS.payReceived, formatMoney(result.amount));
        if (result.recorded) {
          this.dispatchEvent(new CustomEvent("refresh"));
        } else {
          this.recordedLater = true;
        }
      } else if (result?.reasonCode === NOT_PAID) {
        this.noticeIsProblem = false;
        this.notice = LABELS.payNotTaken;
      } else if (result?.reasonCode === NOT_FOUND) {
        this.showProblem(LABELS.payNotFound);
      } else {
        this.showProblem(this.failure(result));
      }
    } catch {
      this.showProblem(CONNECTION_PROBLEM);
    } finally {
      this.checking = false;
    }
  }

  startProblem(result) {
    if (result?.reasonCode === NOTHING_OWED) {
      return LABELS.payNothingOwed;
    }
    if (result?.reasonCode === NOT_FOUND) {
      return LABELS.statementNotYours;
    }
    return this.failure(result);
  }

  failure(result) {
    return result?.reference
      ? format(LABELS.payUnavailable, result.reference)
      : LABELS.tryAgain;
  }

  showProblem(message) {
    this.noticeIsProblem = true;
    this.notice = message;
  }
}
