import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getDispute from "@salesforce/apex/PortalDisputesController.getDispute";
import {
  CONNECTION_PROBLEM,
  LABELS,
  PAGES,
  format,
  formatDate,
  namedPage,
  problemMessage,
  recordIdFrom,
  recordPage
} from "c/portalShared";

const NOT_YOURS = LABELS.disputeNotYours;

/**
 * ST-06, ST-12. A dispute's own page: its status, reason, statement and opening date, the evidence
 * its reason calls for, required items first, and an upload area while it's open. Never the root
 * cause, internal notes or the sales team: the server doesn't send them. The ID comes from the
 * address (?recordId=…), so the server looks for it only among the household's own disputes.
 */
export default class PortalDisputeDetail extends NavigationMixin(
  LightningElement
) {
  labels = LABELS;
  loading = true;
  caseId;
  dispute;
  evidence = [];
  problem;
  uploadMessage = "";
  disputesUrl;
  statementUrl;
  hasPage = false;

  /** Documents and photos, the kinds of evidence Accord's checklist asks for. */
  acceptedFormats = [".pdf", ".png", ".jpg", ".jpeg", ".heic"];

  @wire(CurrentPageReference)
  setCurrentPage(pageRef) {
    const caseId = recordIdFrom(pageRef);
    if (!pageRef || (this.hasPage && caseId === this.caseId)) {
      return;
    }
    this.hasPage = true;
    this.caseId = caseId;
    this.load();
  }

  connectedCallback() {
    this[NavigationMixin.GenerateUrl](namedPage(PAGES.disputes)).then((url) => {
      this.disputesUrl = url;
    });
  }

  async load() {
    const requested = this.caseId;
    this.loading = true;
    this.dispute = null;
    this.evidence = [];
    this.problem = null;
    this.uploadMessage = "";
    if (!requested) {
      this.problem = NOT_YOURS;
      this.loading = false;
      return;
    }
    try {
      const result = await getDispute({ caseId: requested });
      if (requested !== this.caseId) {
        return;
      }
      this.problem = problemMessage(result, NOT_YOURS);
      if (!this.problem) {
        this.dispute = result.dispute;
        this.evidence = (result.evidence ?? []).map((item, index) => ({
          key: `evidence-${index}`,
          text: item.item,
          need: item.required ? LABELS.required : LABELS.optional
        }));
        this.linkStatement();
      }
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      if (requested === this.caseId) {
        this.loading = false;
      }
    }
  }

  linkStatement() {
    if (!this.dispute.statementId) {
      return;
    }
    this[NavigationMixin.GenerateUrl](this.statementPage).then((url) => {
      this.statementUrl = url;
    });
  }

  get statementPage() {
    return recordPage(this.dispute.statementId, PAGES.statement);
  }

  get title() {
    return this.dispute
      ? format(LABELS.disputeNumbered, this.dispute.caseNumber)
      : LABELS.dispute;
  }

  get details() {
    const d = this.dispute;
    return [
      { label: LABELS.status, value: d.status },
      { label: LABELS.reason, value: d.reason },
      { label: LABELS.opened, value: formatDate(d.openedDate) }
    ];
  }

  get isOpen() {
    return this.dispute && !this.dispute.isClosed;
  }

  handleUploadFinished(event) {
    const count = event.detail.files.length;
    this.uploadMessage =
      count === 1
        ? LABELS.uploadThanksOne
        : format(LABELS.uploadThanksMany, count);
  }

  handleStatement(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](this.statementPage);
  }

  handleBack(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.disputes));
  }
}
