import { createElement } from "lwc";
import PortalDisputeDetail from "c/portalDisputeDetail";
import getDispute from "@salesforce/apex/PortalDisputesController.getDispute";
import { CurrentPageReference } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/PortalDisputesController.getDispute",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const CASE_ID = "500000000000001AAA";

const DETAIL = {
  outcome: "COMPLETED",
  dispute: {
    caseId: CASE_ID,
    caseNumber: "00001001",
    status: "New",
    isClosed: false,
    reason: "Payment Not Posted",
    statementId: "a01000000000001AAA",
    statementNumber: "BS-000101",
    openedDate: "2026-10-18"
  },
  evidence: [
    { item: "Payment confirmation", required: true },
    { item: "Bank record", required: false }
  ]
};

async function render(recordId = CASE_ID) {
  const element = createElement("c-portal-dispute-detail", {
    is: PortalDisputeDetail
  });
  document.body.appendChild(element);
  CurrentPageReference.emit({
    type: "comm__namedPage",
    attributes: { name: "Dispute__c" },
    state: recordId ? { recordId } : {}
  });
  await flushPromises();
  await flushPromises();
  return element;
}

describe("c-portal-dispute-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows the dispute, what to send, and an upload area on the dispute", async () => {
    getDispute.mockResolvedValue(DETAIL);
    const element = await render();
    expect(getDispute).toHaveBeenCalledWith({ caseId: CASE_ID });
    expect(element.shadowRoot.querySelector("h1").textContent).toBe(
      "Dispute 00001001"
    );
    const text = element.shadowRoot.textContent;
    expect(text).toContain("StatusNew");
    expect(text).toContain("ReasonPayment Not Posted");
    expect(text).toContain("OpenedOct 18, 2026");
    const items = [...element.shadowRoot.querySelectorAll("ul.bullets li")].map(
      (li) => li.textContent.replace(/\s+/g, " ").trim()
    );
    expect(items).toEqual([
      "Required: Payment confirmation",
      "Optional: Bank record"
    ]);
    const upload = element.shadowRoot.querySelector("lightning-file-upload");
    expect(upload.recordId).toBe(CASE_ID);
    expect(upload.multiple).toBe(true);
    await expect(element).toBeAccessible();
  });

  it("thanks the customer when files arrive", async () => {
    getDispute.mockResolvedValue(DETAIL);
    const element = await render();
    element.shadowRoot.querySelector("lightning-file-upload").dispatchEvent(
      new CustomEvent("uploadfinished", {
        detail: { files: [{ name: "a.pdf" }, { name: "b.png" }] }
      })
    );
    await flushPromises();
    expect(
      element.shadowRoot.querySelector(".upload-message").textContent
    ).toBe("Thank you. We've received your 2 files.");
  });

  it("takes no files once the dispute is closed", async () => {
    getDispute.mockResolvedValue({
      ...DETAIL,
      dispute: { ...DETAIL.dispute, status: "Closed", isClosed: true }
    });
    const element = await render();
    expect(
      element.shadowRoot.querySelector("lightning-file-upload")
    ).toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "This dispute is closed, so it can't take new files."
    );
  });

  it("shows the no-access message for another household's dispute (ST-12)", async () => {
    getDispute.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "We can't show this dispute. It isn't on your account, or it doesn't exist."
    );
    expect(
      element.shadowRoot.querySelector("lightning-file-upload")
    ).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("asks the server for nothing when the address has no ID", async () => {
    const element = await render(null);
    expect(getDispute).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe(
      "We can't show this dispute. It isn't on your account, or it doesn't exist."
    );
  });
});
