import { createElement } from "lwc";
import StewardStatements from "c/stewardStatements";
import getMyAccount from "@salesforce/apex/PortalAccountController.getMyAccount";

jest.mock(
  "@salesforce/apex/PortalAccountController.getMyAccount",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

function statement(id, number) {
  return {
    statementId: id,
    statementNumber: number,
    statementDate: "2026-09-01",
    dueDate: "2026-09-15",
    amountDue: 120,
    amountPaid: 0,
    creditsApplied: 0,
    balance: 120,
    status: "Open",
    payments: []
  };
}

async function render() {
  const element = createElement("c-steward-statements", {
    is: StewardStatements
  });
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

describe("c-steward-statements", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows one card per statement, in the order the server sent them", async () => {
    getMyAccount.mockResolvedValue({
      outcome: "COMPLETED",
      statements: [
        statement("a01000000000002AAA", "BS-000102"),
        statement("a01000000000001AAA", "BS-000101")
      ]
    });
    const element = await render();
    const cards = element.shadowRoot.querySelectorAll(
      "c-steward-statement-card"
    );
    expect(cards).toHaveLength(2);
    expect(cards[0].statement.statementNumber).toBe("BS-000102");
    expect(cards[0].linkToDetail).toBe(true);
    await expect(element).toBeAccessible();
  });

  it("says when there are no statements", async () => {
    getMyAccount.mockResolvedValue({ outcome: "COMPLETED", statements: [] });
    const element = await render();
    expect(element.shadowRoot.textContent).toContain(
      "You don't have any statements yet."
    );
  });

  it("tells someone without a household that the portal is for customers", async () => {
    getMyAccount.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "INVALID_REQUEST"
    });
    const element = await render();
    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("for Lumenfield customers");
  });
});
