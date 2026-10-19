import { createElement } from "lwc";
import PortalHeader from "c/portalHeader";
import { CurrentPageReference } from "lightning/navigation";

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

function render() {
  const element = createElement("c-portal-header", {
    is: PortalHeader
  });
  document.body.appendChild(element);
  return element;
}

function currentLinks(element) {
  return [...element.shadowRoot.querySelectorAll('a[aria-current="page"]')].map(
    (link) => link.textContent
  );
}

describe("c-portal-header", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("links to every page and to Log out, inside a labelled nav", async () => {
    const element = render();
    await flushPromises();
    const nav = element.shadowRoot.querySelector("nav");
    expect(nav.getAttribute("aria-label")).toBe("Customer portal");
    const labels = [...nav.querySelectorAll("a")].map((a) => a.textContent);
    expect(labels).toEqual([
      "My account",
      "Statements",
      "What we promised you",
      "Disputes",
      "Log out"
    ]);
    const logOut = [...nav.querySelectorAll("a")].pop();
    expect(logOut.getAttribute("href")).toBe("/portal/secur/logout.jsp");
    await expect(element).toBeAccessible();
  });

  it("marks the current page for screen readers", async () => {
    const element = render();
    CurrentPageReference.emit({
      type: "comm__namedPage",
      attributes: { name: "What_We_Promised__c" }
    });
    await flushPromises();
    expect(currentLinks(element)).toEqual(["What we promised you"]);
  });

  it("counts a dispute's own page as being in Disputes", async () => {
    const element = render();
    CurrentPageReference.emit({
      type: "comm__namedPage",
      attributes: { name: "Dispute__c" },
      state: { recordId: "500000000000001AAA" }
    });
    await flushPromises();
    expect(currentLinks(element)).toEqual(["Disputes"]);
  });
});
