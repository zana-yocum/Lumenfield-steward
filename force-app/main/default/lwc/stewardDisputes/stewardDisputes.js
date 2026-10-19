import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyDisputes from "@salesforce/apex/PortalDisputesController.getMyDisputes";
import {
  CONNECTION_PROBLEM,
  PAGES,
  formatDate,
  problemMessage,
  recordPage
} from "c/stewardPortal";

/**
 * ST-06. The portal's Disputes page: the form that opens a dispute, and the household's disputes,
 * newest first, each linking to its own page. The list reloads when the form opens a new dispute.
 */
export default class StewardDisputes extends NavigationMixin(LightningElement) {
  loading = true;
  disputes = [];
  problem;

  connectedCallback() {
    this.load();
  }

  async load() {
    try {
      const result = await getMyDisputes();
      this.problem = problemMessage(
        result,
        "We couldn't find an account for your login."
      );
      this.disputes = this.problem ? [] : this.toRows(result.disputes ?? []);
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      this.loading = false;
    }
  }

  toRows(disputes) {
    const rows = disputes.map((dispute) => ({
      key: dispute.caseId,
      caseId: dispute.caseId,
      title: `Dispute ${dispute.caseNumber}`,
      url: undefined,
      details: [
        { label: "Status", value: dispute.status },
        { label: "Reason", value: dispute.reason },
        { label: "Statement", value: dispute.statementNumber },
        { label: "Opened", value: formatDate(dispute.openedDate) }
      ]
    }));
    rows.forEach((row) => {
      this[NavigationMixin.GenerateUrl](
        recordPage(row.caseId, PAGES.dispute)
      ).then((url) => {
        this.disputes = this.disputes.map((r) =>
          r.caseId === row.caseId ? { ...r, url } : r
        );
      });
    });
    return rows;
  }

  get hasDisputes() {
    return this.disputes.length > 0;
  }

  handleOpened() {
    this.load();
  }

  handleOpenDispute(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](
      recordPage(event.currentTarget.dataset.id, PAGES.dispute)
    );
  }
}
