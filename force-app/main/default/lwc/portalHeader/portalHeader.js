import { LightningElement, wire } from "lwc";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
// The header is made only for the customer portal, where the site's base path builds the
// Log out link.
// eslint-disable-next-line @lwc/lwc-platform/no-community-import
import basePath from "@salesforce/community/basePath";
import { PAGES, namedPage } from "c/portalShared";

const LINKS = [
  { name: PAGES.account, label: "My account" },
  { name: PAGES.statements, label: "Statements", detail: PAGES.statement },
  { name: PAGES.promises, label: "What we promised you" },
  { name: PAGES.disputes, label: "Disputes", detail: PAGES.dispute }
];

/**
 * ST-01, ST-02, ST-06, NFR-05. The portal's header, on every page: the brand, a link to each page
 * with the current one marked for screen readers, and Log out. A statement's or a dispute's own
 * page counts as being in Statements or Disputes.
 */
export default class PortalHeader extends NavigationMixin(LightningElement) {
  urls = {};
  currentName;

  @wire(CurrentPageReference)
  setCurrentPage(pageRef) {
    const name = pageRef?.attributes?.name;
    const current = LINKS.find(
      (link) => link.name === name || (link.detail && link.detail === name)
    );
    this.currentName = current?.name;
  }

  connectedCallback() {
    LINKS.forEach((link) => {
      this[NavigationMixin.GenerateUrl](namedPage(link.name)).then((url) => {
        this.urls = { ...this.urls, [link.name]: url };
      });
    });
  }

  get links() {
    return LINKS.map((link) => ({
      ...link,
      url: this.urls[link.name],
      current: link.name === this.currentName ? "page" : null
    }));
  }

  get homeUrl() {
    return this.urls[PAGES.account];
  }

  get homePage() {
    return PAGES.account;
  }

  get logoutUrl() {
    return `${basePath}/secur/logout.jsp`;
  }

  handleNavigate(event) {
    event.preventDefault();
    this[NavigationMixin.Navigate](namedPage(event.currentTarget.dataset.page));
  }
}
