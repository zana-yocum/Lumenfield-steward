import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import briefing from "@salesforce/apex/RepAssistantController.briefing";
import { LABELS, viewOf, viewOfError } from "c/repAssistantShared";

/**
 * ST-08, S-21. The Briefing button on a household in the Collections Console. Writes the
 * briefing as soon as the household is known, and again on request. The server decides what the
 * rep may see; this only shows the result.
 */
export default class RepBriefing extends LightningElement {
  labels = LABELS;
  loading = false;
  text;
  message;
  detail;
  householdId;

  /** The household on the page, set by the quick action. */
  @api
  get recordId() {
    return this.householdId;
  }
  set recordId(value) {
    const first = !this.householdId && value;
    this.householdId = value;
    if (first) {
      this.write();
    }
  }

  async write() {
    this.show({});
    this.loading = true;
    try {
      this.show(viewOf(await briefing({ accountId: this.householdId })));
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
