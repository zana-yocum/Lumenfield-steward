import { createElement } from "lwc";
import StewardDisputes from "c/stewardDisputes";
import getMyDisputes from "@salesforce/apex/PortalDisputesController.getMyDisputes";
import getDisputeForm from "@salesforce/apex/PortalDisputesController.getDisputeForm";

jest.mock(
  "@salesforce/apex/PortalDisputesController.getMyDisputes",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PortalDisputesController.getDisputeForm",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PortalDisputesController.openDispute",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const DISPUTE = {
  caseId: "500000000000001AAA",
  caseNumber: "00001001",
  status: "New",
  isClosed: false,
  reason: "Payment Not Posted",
  statementId: "a01000000000001AAA",
  statementNumber: "BS-000101",
  openedDate: "2026-10-18"
};

async function render() {
  const element = createElement("c-steward-disputes", { is: StewardDisputes });
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
}

describe("c-steward-disputes", () => {
  beforeEach(() => {
    getDisputeForm.mockResolvedValue({
      outcome: "COMPLETED",
      reasons: [],
      statements: []
    });
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("lists the household's disputes, each linking to its own page", async () => {
    getMyDisputes.mockResolvedValue({
      outcome: "COMPLETED",
      disputes: [DISPUTE]
    });
    const element = await render();
    const link = element.shadowRoot.querySelector("h3 a");
    expect(link.textContent).toBe("Dispute 00001001");
    expect(link.getAttribute("href")).toBe("https://www.example.com");
    const text = element.shadowRoot.querySelector("article").textContent;
    expect(text).toContain("StatusNew");
    expect(text).toContain("ReasonPayment Not Posted");
    expect(text).toContain("StatementBS-000101");
    expect(text).toContain("OpenedOct 18, 2026");
    expect(
      element.shadowRoot.querySelector("c-steward-dispute-form")
    ).not.toBeNull();
    await expect(element).toBeAccessible();
  });

  it("says when there are no disputes yet", async () => {
    getMyDisputes.mockResolvedValue({ outcome: "COMPLETED", disputes: [] });
    const element = await render();
    expect(element.shadowRoot.textContent).toContain(
      "You haven't opened any disputes."
    );
  });

  it("reloads the list when the form opens a dispute", async () => {
    getMyDisputes.mockResolvedValue({ outcome: "COMPLETED", disputes: [] });
    const element = await render();
    getMyDisputes.mockResolvedValue({
      outcome: "COMPLETED",
      disputes: [DISPUTE]
    });
    element.shadowRoot
      .querySelector("c-steward-dispute-form")
      .dispatchEvent(new CustomEvent("disputeopened"));
    await flushPromises();
    await flushPromises();
    expect(getMyDisputes).toHaveBeenCalledTimes(2);
    expect(element.shadowRoot.querySelector("h3 a").textContent).toBe(
      "Dispute 00001001"
    );
  });
});
