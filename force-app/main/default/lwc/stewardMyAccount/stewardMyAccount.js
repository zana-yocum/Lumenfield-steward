import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";
import {
  CONNECTION_PROBLEM,
  PAGES,
  formatDate,
  formatMoney,
  namedPage,
  problemMessage
} from "c/stewardPortal";

/**
 * ST-01. The portal's My Account page: what the household owes, what's past due, the oldest
 * unpaid statement, the next payment due, and any payment arrangement. Every figure is Accord's,
 * read back by AccountSnapshotService for the logged-in household; nothing is calculated here.
 */
export default class StewardMyAccount extends NavigationMixin(
  LightningElement
) {
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
      this.problem = problemMessage(
        result,
        "We couldn't find an account for your login."
      );
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
      { label: "Current balance", value: formatMoney(a.currentBalance) },
      { label: "Past due", value: formatMoney(a.pastDueBalance) },
      {
        label: "Oldest unpaid statement",
        value: a.oldestPastDueDate ? formatDate(a.oldestPastDueDate) : "None"
      },
      {
        label: "Next payment due",
        value: a.nextDueDate
          ? `${formatMoney(a.nextDueAmount)} on ${formatDate(a.nextDueDate)}`
          : "Nothing due"
      }
    ];
  }

  get promise() {
    const p = this.account?.openPromise;
    return p
      ? {
          text: `You've arranged to pay ${formatMoney(p.amount)} by ${formatDate(p.promiseDate)}.`,
          status: p.status
        }
      : null;
  }

  handleStatements(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.statements));
  }
}
