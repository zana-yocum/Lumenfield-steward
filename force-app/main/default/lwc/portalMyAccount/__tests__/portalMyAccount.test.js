import { createElement } from "lwc";
import PortalMyAccount from "c/portalMyAccount";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";

jest.mock(
  "@salesforce/apex/PortalAccountController.getMyAccount",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const ACCOUNT = {
  outcome: "COMPLETED",
  currentBalance: 310,
  pastDueBalance: 190,
  oldestPastDueDate: "2026-08-01",
  nextDueDate: "2026-11-01",
  nextDueAmount: 120,
  statements: [],
  openPromise: {
    amount: 190,
    promiseDate: "2026-10-25",
    status: "Active"
  }
};

async function render() {
  const element = createElement("c-portal-my-account", {
    is: PortalMyAccount
  });
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

describe("c-portal-my-account", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows Accord's figures for the household, to the cent", async () => {
    getMyAccount.mockResolvedValue(ACCOUNT);
    const element = await render();
    const text = element.shadowRoot.textContent;
    expect(text).toContain("Current balance$310.00");
    expect(text).toContain("Past due$190.00");
    expect(text).toContain("Oldest unpaid statementAug 1, 2026");
    expect(text).toContain("Next payment due$120.00 on Nov 1, 2026");
    expect(text).toContain(
      "You've arranged to pay $190.00 by Oct 25, 2026. Status: Active."
    );
    await expect(element).toBeAccessible();
  });

  it("says when nothing is owed", async () => {
    getMyAccount.mockResolvedValue({
      ...ACCOUNT,
      currentBalance: 0,
      pastDueBalance: 0,
      oldestPastDueDate: null,
      nextDueDate: null,
      openPromise: null
    });
    const element = await render();
    const text = element.shadowRoot.textContent;
    expect(text).toContain("Oldest unpaid statementNone");
    expect(text).toContain("Next payment dueNothing due");
    expect(text).not.toContain("payment arrangement");
  });

  it("shows only a reference when the server failed (NFR-07)", async () => {
    getMyAccount.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "UNEXPECTED_ERROR",
      reference: "AAL-000007"
    });
    const element = await render();
    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("AAL-000007");
    expect(element.shadowRoot.textContent).not.toContain("Current balance");
    await expect(element).toBeAccessible();
  });

  it("explains a lost connection without any error details", async () => {
    getMyAccount.mockRejectedValue(new Error("Network down"));
    const element = await render();
    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert.textContent).toContain("Check your connection");
    expect(alert.textContent).not.toContain("Network down");
  });
});
