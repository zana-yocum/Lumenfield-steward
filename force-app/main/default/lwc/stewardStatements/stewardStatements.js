import { LightningElement } from "lwc";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";
import { CONNECTION_PROBLEM, problemMessage } from "c/stewardPortal";

/**
 * ST-01. The portal's Statements page: every statement the household has, newest first, each with
 * its amounts, status, payments and any open dispute. The statements come from the same read as
 * My Account, so the two pages always agree.
 */
export default class StewardStatements extends LightningElement {
  loading = true;
  statements = [];
  problem;

  connectedCallback() {
    this.load();
  }

  async load() {
    try {
      const result = await getMyAccount();
      this.problem = problemMessage(
        result,
        "We couldn't find an account for your login."
      );
      this.statements = this.problem ? [] : (result.statements ?? []);
    } catch {
      this.problem = CONNECTION_PROBLEM;
    } finally {
      this.loading = false;
    }
  }

  get hasStatements() {
    return this.statements.length > 0;
  }
}
