import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { PAGES, formatDate, formatMoney, recordPage } from "c/portalShared";

/**
 * ST-01. One statement as the customer sees it: its dates and amounts, its status, the payments
 * made against it (date and amount only), and a link to its dispute when one is open. Used on the
 * Statements page, where its number links to the statement's own page, and on that page itself.
 */
export default class PortalStatementCard extends NavigationMixin(
  LightningElement
) {
  /** The statement, as AccountSnapshotService returns it. */
  @api statement;
  /** On the Statements page: the number links to the statement's own page. */
  @api linkToDetail = false;
  /** On the statement's own page, whose heading already names it. */
  @api hideTitle = false;

  detailUrl;
  disputeUrl;

  connectedCallback() {
    if (this.linkToDetail) {
      this[NavigationMixin.GenerateUrl](this.statementPage).then((url) => {
        this.detailUrl = url;
      });
    }
    if (this.hasDispute) {
      this[NavigationMixin.GenerateUrl](this.disputePage).then((url) => {
        this.disputeUrl = url;
      });
    }
  }

  get statementPage() {
    return recordPage(this.statement.statementId, PAGES.statement);
  }

  get disputePage() {
    return recordPage(this.statement.disputeCaseId, PAGES.dispute);
  }

  get title() {
    return `Statement ${this.statement.statementNumber}`;
  }

  get hasDispute() {
    return Boolean(this.statement?.disputeCaseId);
  }

  get details() {
    const s = this.statement;
    return [
      { label: "Statement date", value: formatDate(s.statementDate) },
      { label: "Due date", value: formatDate(s.dueDate) },
      { label: "Amount due", value: formatMoney(s.amountDue) },
      { label: "Paid", value: formatMoney(s.amountPaid) },
      { label: "Credits applied", value: formatMoney(s.creditsApplied) },
      { label: "Balance", value: formatMoney(s.balance) }
    ];
  }

  get payments() {
    return (this.statement?.payments ?? []).map((payment) => ({
      key: payment.paymentId,
      text: `${formatDate(payment.paymentDate)}: ${formatMoney(payment.amount)}`
    }));
  }

  get hasPayments() {
    return this.payments.length > 0;
  }

  handleOpenStatement(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](this.statementPage);
  }

  handleOpenDispute(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](this.disputePage);
  }
}
