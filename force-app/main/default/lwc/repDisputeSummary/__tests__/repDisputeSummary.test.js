import { createElement } from "lwc";
import RepDisputeSummary from "c/repDisputeSummary";
import disputeSummary from "@salesforce/apex/RepAssistantController.disputeSummary";

jest.mock(
  "@salesforce/apex/RepAssistantController.disputeSummary",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const CASE_ID = "500000000000001AAA";

async function render() {
  const element = createElement("c-rep-dispute-summary", {
    is: RepDisputeSummary
  });
  element.recordId = CASE_ID;
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
}

function generatedText(element) {
  return element.shadowRoot.querySelector("c-rep-generated-text");
}

describe("c-rep-dispute-summary", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("writes the summary for the dispute on the page", async () => {
    disputeSummary.mockResolvedValue({
      outcome: "COMPLETED",
      text: "The dispute\nCase 00001053"
    });
    const element = await render();
    expect(disputeSummary).toHaveBeenCalledWith({ caseId: CASE_ID });
    expect(
      element.shadowRoot.querySelector("lightning-quick-action-panel").header
    ).toBe("Dispute Summary");
    expect(generatedText(element).text).toBe("The dispute\nCase 00001053");
    await expect(element).toBeAccessible();
  });

  it("says why there's no summary for a case that isn't a billing dispute", async () => {
    disputeSummary.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    expect(generatedText(element).message).toBe(
      "This record isn't available to you."
    );
  });

  it("reports a server error with its detail", async () => {
    disputeSummary.mockRejectedValue({
      body: { message: "Script-thrown exception" }
    });
    const element = await render();
    expect(generatedText(element).detail).toBe("Script-thrown exception");
  });

  it("writes again on request and closes on Close", async () => {
    disputeSummary.mockResolvedValue({ outcome: "COMPLETED", text: "Summary" });
    const element = await render();
    element.shadowRoot.querySelector("lightning-button.write-again").click();
    await flushPromises();
    expect(disputeSummary).toHaveBeenCalledTimes(2);
    const closed = jest.fn();
    element.addEventListener("close", closed);
    element.shadowRoot.querySelector("lightning-button.close").click();
    expect(closed).toHaveBeenCalledTimes(1);
  });
});
