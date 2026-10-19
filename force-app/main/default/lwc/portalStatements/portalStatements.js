import { LightningElement } from "lwc";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";
import { CONNECTION_PROBLEM, LABELS, problemMessage } from "c/portalShared";

/**
 * ST-01. The portal's Statements page: every statement the household has, newest first, each with
 * its amounts, status, payments and any open dispute. The statements come from the same read as
 * My Account, so the two pages always agree.
 */
export default class PortalStatements extends LightningElement {
  labels = LABELS;
  loading = true;
  statements = [];
  problem;

  connectedCallback() {
    this.load();
  }

  async load() {
    try {
      const result = await getMyAccount();
      this.problem = problemMessage(result, LABELS.noAccount);
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
