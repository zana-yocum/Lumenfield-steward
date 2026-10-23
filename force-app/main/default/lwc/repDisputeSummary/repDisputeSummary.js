import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import disputeSummary from "@salesforce/apex/RepAssistantController.disputeSummary";
import { LABELS, viewOf, viewOfError } from "c/repAssistantShared";

/**
 * ST-09, S-21. The Dispute Summary button on a billing dispute in the Collections Console.
 * Writes the summary as soon as the case is known, and again on request. The server decides what
 * the specialist may see and refuses anything that isn't a billing dispute; this only shows the
 * result.
 */
export default class RepDisputeSummary extends LightningElement {
  labels = LABELS;
  loading = false;
  text;
  message;
  detail;
  caseId;

  /** The case on the page, set by the quick action. */
  @api
  get recordId() {
    return this.caseId;
  }
  set recordId(value) {
    const first = !this.caseId && value;
    this.caseId = value;
    if (first) {
      this.write();
    }
  }

  async write() {
    this.show({});
    this.loading = true;
    try {
      this.show(viewOf(await disputeSummary({ caseId: this.caseId })));
    } catch (error) {
      this.show(viewOfError(error));
    } finally {
      this.loading = false;
    }
  }

  show(view) {
    this.text = view.text;
    this.message = view.message;
    this.detail = view.detail;
  }

  close() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
