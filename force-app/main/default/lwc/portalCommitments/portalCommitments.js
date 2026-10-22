import { LightningElement } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyCommitments from "@salesforce/apex/PortalCommitmentsController.getMyCommitments";
import {
  CONNECTION_PROBLEM,
  LABELS,
  PAGES,
  formatMoney,
  namedPage,
  problemMessage
} from "c/portalShared";

/**
 * ST-02, S-08. The portal's What We Promised You page: each special term recorded on the
 * household's agreement at signing, with its type, value, months covered, status and terms. The
 * terms are shown exactly as recorded. Nothing about the deal behind them, the sales rep or who
 * recorded them reaches the page, because the read service never returns it. When nothing was
 * recorded, the page says so and points to opening a dispute.
 */
export default class PortalCommitments extends NavigationMixin(
  LightningElement
) {
  labels = LABELS;
  loading = true;
  commitments = [];
  problem;
  disputesUrl;

  connectedCallback() {
    this[NavigationMixin.GenerateUrl](namedPage(PAGES.disputes)).then((url) => {
      this.disputesUrl = url;
    });
    this.load();
  }

  async load() {
    try {
      const result = await getMyCommitments();
      this.problem = problemMessage(result, LABELS.noAccount);
      this.commitments = this.problem
        ? []
        : (result.commitments ?? []).map((commitment, index) => ({
            key: `commitment-${index}`,
            type: commitment.commitmentType,
            terms: commitment.terms,
            details: [
              { label: LABELS.value, value: formatMoney(commitment.value) },
              {
                label: LABELS.monthsCovered,
                value: commitment.monthsCovered ?? LABELS.notApplicable
              },
              { label: LABELS.status, value: commitment.status }
            ]
          }));
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      this.loading = false;
    }
  }

  get hasCommitments() {
    return this.commitments.length > 0;
  }

  handleDisputes(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.disputes));
  }
}
