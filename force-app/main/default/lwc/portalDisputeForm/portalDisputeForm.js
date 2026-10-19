import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getDisputeForm from "@salesforce/apex/PortalDisputesController.getDisputeForm";
import openDispute from "@salesforce/apex/PortalDisputesController.openDispute";
import {
  CONNECTION_PROBLEM,
  PAGES,
  OUTCOME,
  REASON,
  formatDate,
  formatMoney,
  problemMessage,
  recordPage
} from "c/portalShared";

const DECLINED = {
  [REASON.notFound]: "We couldn't find that statement on your account.",
  [REASON.statementRequired]: "Choose the statement the dispute is about.",
  [REASON.invalidReason]: "Choose one of the reasons in the list."
};

/**
 * ST-06, ST-12, NFR-07. Opens a dispute from the portal. The customer picks one of their own
 * statements and one of Accord's eight reasons, and sees the evidence that reason calls for before
 * they send it. The server re-checks that the statement is the household's, and Accord's flows,
 * SLA and assignment rule take it from there. A statement already in dispute isn't offered:
 * it's listed with a link to its open dispute instead. Fires disputeopened when a dispute opens.
 */
export default class PortalDisputeForm extends NavigationMixin(
  LightningElement
) {
  loading = true;
  problem;
  reasons = [];
  statements = [];
  statementId;
  reason;
  description = "";
  submitting = false;
  result;
  focusResult = false;

  connectedCallback() {
    this.load();
  }

  renderedCallback() {
    if (this.focusResult) {
      this.focusResult = false;
      this.refs.resultHeading?.focus();
    }
  }

  async load() {
    try {
      const form = await getDisputeForm();
      this.problem = problemMessage(
        form,
        "We couldn't find an account for your login."
      );
      if (!this.problem) {
        this.reasons = form.reasons ?? [];
        this.statements = (form.statements ?? []).map((statement) => ({
          ...statement,
          label: `Statement ${statement.statementNumber}, ${formatDate(statement.statementDate)}, ${formatMoney(statement.amountDue)}`
        }));
        this.linkDisputedStatements();
      }
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      this.loading = false;
    }
  }

  linkDisputedStatements() {
    this.statements
      .filter((statement) => statement.disputeCaseId)
      .forEach((statement) => {
        this[NavigationMixin.GenerateUrl](
          recordPage(statement.disputeCaseId, PAGES.dispute)
        ).then((url) => {
          this.statements = this.statements.map((s) =>
            s.statementId === statement.statementId
              ? { ...s, disputeUrl: url }
              : s
          );
        });
      });
  }

  get statementOptions() {
    return this.statements
      .filter((statement) => !statement.disputeCaseId)
      .map((statement) => ({
        label: statement.label,
        value: statement.statementId
      }));
  }

  get disputedStatements() {
    return this.statements.filter((statement) => statement.disputeCaseId);
  }

  get hasOpenChoices() {
    return this.statementOptions.length > 0;
  }

  get hasDisputedStatements() {
    return this.disputedStatements.length > 0;
  }

  get reasonOptions() {
    return this.reasons.map((r) => ({ label: r.label, value: r.value }));
  }

  get evidence() {
    const chosen = this.reasons.find((r) => r.value === this.reason);
    return chosen ? this.toEvidence(chosen.evidence) : null;
  }

  toEvidence(items) {
    return (items ?? []).map((item, index) => ({
      key: `evidence-${index}`,
      text: `${item.item} (${item.required ? "required" : "optional"})`
    }));
  }

  handleStatement(event) {
    this.statementId = event.detail.value;
  }

  handleReason(event) {
    this.reason = event.detail.value;
  }

  handleDescription(event) {
    this.description = event.detail.value;
  }

  async handleSubmit() {
    const missing = [
      ["statement", this.statementId],
      ["reason", this.reason]
    ]
      .filter(([, value]) => !value)
      .map(([name]) => this.template.querySelector(`[data-field="${name}"]`));
    if (missing.length > 0) {
      missing.forEach((field) => field.reportValidity());
      missing[0].focus();
      return;
    }
    this.submitting = true;
    try {
      const result = await openDispute({
        statementId: this.statementId,
        reason: this.reason,
        description: this.description
      });
      this.showResult(result);
    } catch {
      this.result = {
        heading: "We couldn't open the dispute",
        text: CONNECTION_PROBLEM
      };
    } finally {
      this.submitting = false;
      this.focusResult = true;
    }
  }

  showResult(result) {
    if (result.outcome === OUTCOME.completed) {
      this.result = {
        heading: `Dispute ${result.caseNumber} is open`,
        text: "A dispute specialist will review it. Send the items below from the dispute's page.",
        evidence: this.toEvidence(result.evidence),
        caseId: result.caseId,
        caseNumber: result.caseNumber
      };
      this.linkResultCase();
      this.dispatchEvent(new CustomEvent("disputeopened"));
    } else if (result.reasonCode === REASON.existingDispute) {
      this.result = {
        heading: "This statement already has an open dispute",
        text: `Dispute ${result.caseNumber} is already open for it.`,
        caseId: result.caseId,
        caseNumber: result.caseNumber
      };
      this.linkResultCase();
    } else if (
      result.outcome === OUTCOME.declined &&
      DECLINED[result.reasonCode]
    ) {
      this.result = {
        heading: "We couldn't open the dispute",
        text: DECLINED[result.reasonCode]
      };
    } else {
      this.result = {
        heading: "We couldn't open the dispute",
        text: problemMessage(result, DECLINED[REASON.notFound])
      };
    }
  }

  linkResultCase() {
    const caseId = this.result.caseId;
    this[NavigationMixin.GenerateUrl](recordPage(caseId, PAGES.dispute)).then(
      (url) => {
        if (this.result?.caseId === caseId) {
          this.result = { ...this.result, caseUrl: url };
        }
      }
    );
  }

  handleOpenCase(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](
      recordPage(event.currentTarget.dataset.id, PAGES.dispute)
    );
  }

  handleStartAgain() {
    this.result = null;
    this.statementId = null;
    this.reason = null;
    this.description = "";
    this.loading = true;
    this.load();
  }
}
