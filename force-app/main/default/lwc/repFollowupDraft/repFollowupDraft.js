import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { CloseActionScreenEvent } from "lightning/actions";
import followupDraft from "@salesforce/apex/RepAssistantController.followupDraft";
import { LABELS, OUTCOME, viewOf, viewOfError } from "c/repAssistantShared";

/**
 * ST-10, S-21. The Follow-up Draft button on a household. Asks the server for a draft of today's
 * follow-up and opens it in the standard email composer, addressed and signed, for the rep to
 * edit and send. Nothing is sent from here. Without a contact attempt logged today, the rep is
 * asked to log one first.
 */
export default class RepFollowupDraft extends NavigationMixin(
  LightningElement
) {
  labels = LABELS;
  loading = false;
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
      this.draft();
    }
  }

  async draft() {
    this.loading = true;
    try {
      const email = await followupDraft({ accountId: this.householdId });
      if (email?.outcome === OUTCOME.completed) {
        this.openComposer(email);
        this.close();
        return;
      }
      this.show(viewOf(email));
    } catch (error) {
      this.show(viewOfError(error));
    } finally {
      this.loading = false;
    }
  }

  openComposer(email) {
    const values = {
      Subject: email.subject,
      HtmlBody: email.htmlBody,
      RelatedToId: this.householdId
    };
    if (email.toAddress) {
      values.ToAddress = email.toAddress;
    }
    this[NavigationMixin.Navigate]({
      type: "standard__quickAction",
      attributes: { apiName: "Global.SendEmail" },
      state: {
        recordId: this.householdId,
        defaultFieldValues: encodeDefaultFieldValues(values)
      }
    });
  }

  show(view) {
    this.message = view.message;
    this.detail = view.detail;
  }

  close() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
