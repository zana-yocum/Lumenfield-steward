import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyDisputes from "@salesforce/apex/PortalDisputesController.getMyDisputes";
import {
  CONNECTION_PROBLEM,
  LABELS,
  PAGES,
  format,
  formatDate,
  problemMessage,
  recordPage
} from "c/portalShared";

/**
 * ST-06. The portal's Disputes page: the form that opens a dispute, and the household's disputes,
 * newest first, each linking to its own page. The list reloads when the form opens a new dispute.
 */
export default class PortalDisputes extends NavigationMixin(LightningElement) {
  labels = LABELS;
  loading = true;
  disputes = [];
  problem;

  connectedCallback() {
    this.load();
  }

  async load() {
    try {
      const result = await getMyDisputes();
      this.problem = problemMessage(result, LABELS.noAccount);
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
      title: format(LABELS.disputeNumbered, dispute.caseNumber),
      url: undefined,
      details: [
        { label: LABELS.status, value: dispute.status },
        { label: LABELS.reason, value: dispute.reason },
        { label: LABELS.statement, value: dispute.statementNumber },
        { label: LABELS.opened, value: formatDate(dispute.openedDate) }
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
