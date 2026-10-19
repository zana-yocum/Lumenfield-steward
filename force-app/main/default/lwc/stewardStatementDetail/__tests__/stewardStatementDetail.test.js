import { createElement } from "lwc";
import StewardStatementDetail from "c/stewardStatementDetail";
import getStatement from "@salesforce/apex/PortalAccountController.getStatement";
import { CurrentPageReference } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/PortalAccountController.getStatement",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const RECORD_ID = "a01000000000001AAA";

function statementPage(recordId) {
  return {
    type: "comm__namedPage",
    attributes: { name: "Statement__c" },
    state: recordId ? { recordId } : {}
  };
}

async function render(recordId = RECORD_ID) {
  const element = createElement("c-steward-statement-detail", {
    is: StewardStatementDetail
  });
  document.body.appendChild(element);
  CurrentPageReference.emit(statementPage(recordId));
  await flushPromises();
  return element;
}

describe("c-steward-statement-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("asks the server for the statement in the address and shows it", async () => {
    getStatement.mockResolvedValue({
      outcome: "COMPLETED",
      statement: {
        statementId: RECORD_ID,
        statementNumber: "BS-000101",
        statementDate: "2026-09-01",
        dueDate: "2026-09-15",
        amountDue: 120,
        amountPaid: 0,
        creditsApplied: 0,
        balance: 120,
        status: "Open",
        payments: []
      }
    });
    const element = await render();
    expect(getStatement).toHaveBeenCalledWith({ statementId: RECORD_ID });
    expect(element.shadowRoot.querySelector("h1").textContent).toBe(
      "Statement BS-000101"
    );
    const card = element.shadowRoot.querySelector("c-steward-statement-card");
    expect(card.hideTitle).toBe(true);
    await expect(element).toBeAccessible();
  });

  it("shows the no-access message for another household's statement (ST-01, ST-12)", async () => {
    getStatement.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    expect(element.shadowRoot.querySelector("h1").textContent).toBe(
      "Statement"
    );
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "We can't show this statement. It isn't on your account, or it doesn't exist."
    );
    expect(
      element.shadowRoot.querySelector("c-steward-statement-card")
    ).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("shows the same message, without asking the server, when the address has no ID", async () => {
    const element = await render(null);
    expect(getStatement).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "We can't show this statement. It isn't on your account, or it doesn't exist."
    );
  });

  it("loads again when the address names another statement, and only then", async () => {
    getStatement.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    await render();
    CurrentPageReference.emit(statementPage(RECORD_ID));
    await flushPromises();
    expect(getStatement).toHaveBeenCalledTimes(1);
    CurrentPageReference.emit(statementPage("a01000000000002AAA"));
    await flushPromises();
    expect(getStatement).toHaveBeenCalledTimes(2);
    expect(getStatement).toHaveBeenLastCalledWith({
      statementId: "a01000000000002AAA"
    });
  });
});
