import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import getStatement from "@salesforce/apex/PortalAccountController.getStatement";
import {
  CONNECTION_PROBLEM,
  PAGES,
  namedPage,
  problemMessage,
  recordIdFrom
} from "c/portalShared";

const NOT_YOURS =
  "We can't show this statement. It isn't on your account, or it doesn't exist.";

/**
 * ST-01, ST-12. A statement's own page. The ID comes from the address (?recordId=…), so the server
 * looks for it only among the logged-in household's statements: another household's ID gets the
 * same answer as one that doesn't exist, and nothing about it reaches the browser.
 */
export default class PortalStatementDetail extends NavigationMixin(
  LightningElement
) {
  loading = true;
  statementId;
  statement;
  problem;
  statementsUrl;
  hasPage = false;

  @wire(CurrentPageReference)
  setCurrentPage(pageRef) {
    const statementId = recordIdFrom(pageRef);
    if (!pageRef || (this.hasPage && statementId === this.statementId)) {
      return;
    }
    this.hasPage = true;
    this.statementId = statementId;
    this.load();
  }

  connectedCallback() {
    this[NavigationMixin.GenerateUrl](namedPage(PAGES.statements)).then(
      (url) => {
        this.statementsUrl = url;
      }
    );
  }

  async load() {
    const requested = this.statementId;
    this.loading = true;
    this.statement = null;
    this.problem = null;
    if (!requested) {
      this.problem = NOT_YOURS;
      this.loading = false;
      return;
    }
    try {
      const result = await getStatement({ statementId: requested });
      if (requested !== this.statementId) {
        return;
      }
      this.problem = problemMessage(result, NOT_YOURS);
      this.statement = this.problem ? null : result.statement;
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      if (requested === this.statementId) {
        this.loading = false;
      }
    }
  }

  get title() {
    return this.statement
      ? `Statement ${this.statement.statementNumber}`
      : "Statement";
  }

  handleBack(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(PAGES.statements));
  }
}
