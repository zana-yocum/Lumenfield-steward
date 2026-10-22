import { createElement } from "lwc";
import PortalDisputeForm from "c/portalDisputeForm";
import getDisputeForm from "@salesforce/apex/PortalDisputesController.getDisputeForm";
import openDispute from "@salesforce/apex/PortalDisputesController.openDispute";

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

const OPEN_STATEMENT = "a01000000000002AAA";
const PAYMENT_NOT_POSTED = "Payment Not Posted";
const PROOF = { item: "Payment confirmation", required: true };
const BANK = { item: "Bank record", required: false };

const FORM = {
  outcome: "COMPLETED",
  reasons: [
    {
      value: PAYMENT_NOT_POSTED,
      label: PAYMENT_NOT_POSTED,
      evidence: [PROOF, BANK]
    },
    {
      value: "Promised Credit Not Applied",
      label: "Promised Credit Not Applied",
      evidence: [{ item: "Signed agreement or addendum", required: true }]
    }
  ],
  statements: [
    {
      statementId: OPEN_STATEMENT,
      statementNumber: "BS-000102",
      statementDate: "2026-10-01",
      amountDue: 120
    },
    {
      statementId: "a01000000000001AAA",
      statementNumber: "BS-000101",
      statementDate: "2026-09-01",
      amountDue: 120,
      disputeCaseId: "500000000000001AAA",
      disputeCaseNumber: "00001001"
    }
  ]
};

async function render() {
  const element = createElement("c-portal-dispute-form", {
    is: PortalDisputeForm
  });
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
}

function choose(element, field, value) {
  element.shadowRoot
    .querySelector(`[data-field="${field}"]`)
    .dispatchEvent(new CustomEvent("change", { detail: { value } }));
}

async function submit(element) {
  [...element.shadowRoot.querySelectorAll("lightning-button")]
    .find((button) => button.label === "Open the dispute")
    .click();
  await flushPromises();
  await flushPromises();
}

describe("c-portal-dispute-form", () => {
  beforeEach(() => {
    getDisputeForm.mockResolvedValue(FORM);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("offers only statements without an open dispute, and links the disputed ones", async () => {
    const element = await render();
    const radio = element.shadowRoot.querySelector('[data-field="statement"]');
    expect(radio.options).toEqual([
      {
        label: "Statement BS-000102, Oct 1, 2026, $120.00",
        value: OPEN_STATEMENT
      }
    ]);
    const disputed = element.shadowRoot.querySelector("ul.bullets li");
    expect(disputed.textContent).toContain("Statement BS-000101");
    expect(disputed.querySelector("a").textContent).toBe("dispute 00001001");
    await expect(element).toBeAccessible();
  });

  it("shows what to send as soon as a reason is chosen", async () => {
    const element = await render();
    choose(element, "reason", PAYMENT_NOT_POSTED);
    await flushPromises();
    const items = [
      ...element.shadowRoot.querySelectorAll(".field ul.bullets li")
    ].map((li) => li.textContent);
    expect(items).toEqual([
      "Payment confirmation (required)",
      "Bank record (optional)"
    ]);
  });

  it("doesn't send anything until a statement and a reason are chosen", async () => {
    const element = await render();
    await submit(element);
    expect(openDispute).not.toHaveBeenCalled();
  });

  it("opens the dispute, lists what to send, and tells the page", async () => {
    openDispute.mockResolvedValue({
      outcome: "COMPLETED",
      caseId: "500000000000002AAA",
      caseNumber: "00001002",
      evidence: [PROOF, BANK]
    });
    const element = await render();
    const opened = jest.fn();
    element.addEventListener("disputeopened", opened);
    choose(element, "statement", OPEN_STATEMENT);
    choose(element, "reason", PAYMENT_NOT_POSTED);
    element.shadowRoot
      .querySelector("lightning-textarea")
      .dispatchEvent(
        new CustomEvent("change", { detail: { value: "Paid on the 3rd." } })
      );
    await submit(element);
    expect(openDispute).toHaveBeenCalledWith({
      statementId: OPEN_STATEMENT,
      reason: PAYMENT_NOT_POSTED,
      description: "Paid on the 3rd."
    });
    const heading = element.shadowRoot.querySelector("h3");
    expect(heading.textContent.trim()).toBe("Dispute 00001002 is open");
    expect(element.shadowRoot.activeElement).toBe(heading);
    expect(element.shadowRoot.textContent).toContain(
      "Payment confirmation (required)"
    );
    expect(element.shadowRoot.querySelector(".next a").textContent).toBe(
      "Go to dispute 00001002"
    );
    expect(opened).toHaveBeenCalledTimes(1);
    await expect(element).toBeAccessible();
  });

  it("points to the open dispute instead of making a second one", async () => {
    openDispute.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "EXISTING_DISPUTE",
      caseId: "500000000000001AAA",
      caseNumber: "00001001"
    });
    const element = await render();
    choose(element, "statement", OPEN_STATEMENT);
    choose(element, "reason", PAYMENT_NOT_POSTED);
    await submit(element);
    expect(element.shadowRoot.querySelector("h3").textContent.trim()).toBe(
      "This statement already has an open dispute"
    );
    expect(element.shadowRoot.textContent).toContain(
      "Dispute 00001001 is already open for it."
    );
  });

  it("gives a reference and never the error when the dispute couldn't be saved (NFR-07)", async () => {
    openDispute.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "ACCESS_DENIED",
      reference: "AAL-000021"
    });
    const element = await render();
    choose(element, "statement", OPEN_STATEMENT);
    choose(element, "reason", PAYMENT_NOT_POSTED);
    await submit(element);
    const text = element.shadowRoot.textContent;
    expect(text).toContain("quote reference AAL-000021");
    expect(text).not.toContain("ACCESS_DENIED");
  });

  it("explains a statement the server didn't find", async () => {
    openDispute.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    choose(element, "statement", OPEN_STATEMENT);
    choose(element, "reason", PAYMENT_NOT_POSTED);
    await submit(element);
    expect(element.shadowRoot.textContent).toContain(
      "We couldn't find that statement on your account."
    );
  });

  it("starts again after a result", async () => {
    openDispute.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    choose(element, "statement", OPEN_STATEMENT);
    choose(element, "reason", PAYMENT_NOT_POSTED);
    await submit(element);
    [...element.shadowRoot.querySelectorAll("lightning-button")]
      .find((button) => button.label === "Open another dispute")
      .click();
    await flushPromises();
    await flushPromises();
    expect(getDisputeForm).toHaveBeenCalledTimes(2);
    expect(
      element.shadowRoot.querySelector('[data-field="statement"]').value
    ).toBeNull();
  });
});
