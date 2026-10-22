import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";
import {
  CONNECTION_PROBLEM,
  LABELS,
  PAGES,
  format,
  formatDate,
  formatMoney,
  namedPage,
  problemMessage
} from "c/portalShared";

/**
 * ST-01. The portal's My Account page: what the household owes, what's past due, the oldest
 * unpaid statement, the next payment due, and any payment arrangement. Every figure is Accord's,
 * read back by AccountSnapshotService for the logged-in household; nothing is calculated here.
 */
export default class PortalMyAccount extends NavigationMixin(LightningElement) {
  labels = LABELS;
  loading = true;
  account;
  problem;
  statementsUrl;

  connectedCallback() {
    this[NavigationMixin.GenerateUrl](namedPage(PAGES.statements)).then(
      (url) => {
        this.statementsUrl = url;
      }
    );
    this.load();
  }

  async load() {
    try {
      const result = await getMyAccount();
      this.problem = problemMessage(result, LABELS.noAccount);
      this.account = this.problem ? null : result;
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      this.loading = false;
    }
  }

  get figures() {
    const a = this.account;
    return [
      { label: LABELS.currentBalance, value: formatMoney(a.currentBalance) },
      { label: LABELS.pastDue, value: formatMoney(a.pastDueBalance) },
      {
        label: LABELS.oldestUnpaid,
        value: a.oldestPastDueDate
          ? formatDate(a.oldestPastDueDate)
          : LABELS.none
      },
      {
        label: LABELS.nextPaymentDue,
        value: a.nextDueDate
          ? format(
              LABELS.amountOnDate,
              formatMoney(a.nextDueAmount),
              formatDate(a.nextDueDate)
            )
          : LABELS.nothingDue
      }
    ];
  }

  get promise() {
    const p = this.account?.openPromise;
    return p
      ? format(
          LABELS.arrangementText,
          formatMoney(p.amount),
          formatDate(p.promiseDate),
          p.status
        )
      : null;
  }

  handleStatements(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.statements));
  }
}
