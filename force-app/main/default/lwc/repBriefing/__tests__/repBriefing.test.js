import { createElement } from "lwc";
import RepBriefing from "c/repBriefing";
import briefing from "@salesforce/apex/RepAssistantController.briefing";

jest.mock(
  "@salesforce/apex/RepAssistantController.briefing",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const ACCOUNT_ID = "001000000000001AAA";

async function render(recordId = ACCOUNT_ID) {
  const element = createElement("c-rep-briefing", { is: RepBriefing });
  element.recordId = recordId;
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
}

function generatedText(element) {
  return element.shadowRoot.querySelector("c-rep-generated-text");
}

describe("c-rep-briefing", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("writes the briefing for the household on the page", async () => {
    briefing.mockResolvedValue({
      outcome: "COMPLETED",
      text: "Balance\n$190.00"
    });
    const element = await render();
    expect(briefing).toHaveBeenCalledTimes(1);
    expect(briefing).toHaveBeenCalledWith({ accountId: ACCOUNT_ID });
    const panel = element.shadowRoot.querySelector(
      "lightning-quick-action-panel"
    );
    expect(panel.header).toBe("Briefing");
    expect(generatedText(element).text).toBe("Balance\n$190.00");
    expect(generatedText(element).loading).toBe(false);
    expect(generatedText(element).message).toBeUndefined();
    await expect(element).toBeAccessible();
  });

  it("says why there's no briefing for a household the rep can't see", async () => {
    briefing.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render();
    expect(generatedText(element).message).toBe(
      "This record isn't available to you."
    );
    expect(generatedText(element).text).toBeUndefined();
  });

  it("reports a failed generation with its detail", async () => {
    briefing.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "GENERATION_FAILED",
      detail: "Einstein is unavailable."
    });
    const element = await render();
    expect(generatedText(element).message).toBe(
      "The assistant couldn't write this just now. Try again in a minute."
    );
    expect(generatedText(element).detail).toBe("Einstein is unavailable.");
  });

  it("reports a server error the same way", async () => {
    briefing.mockRejectedValue({ body: { message: "Insufficient access" } });
    const element = await render();
    expect(generatedText(element).message).toBe(
      "The assistant couldn't write this just now. Try again in a minute."
    );
    expect(generatedText(element).detail).toBe("Insufficient access");
  });

  it("writes again on request and closes on Close", async () => {
    briefing
      .mockResolvedValueOnce({ outcome: "COMPLETED", text: "First" })
      .mockResolvedValueOnce({ outcome: "COMPLETED", text: "Second" });
    const element = await render();
    element.shadowRoot.querySelector("lightning-button.write-again").click();
    await flushPromises();
    await flushPromises();
    expect(briefing).toHaveBeenCalledTimes(2);
    expect(generatedText(element).text).toBe("Second");

    const closed = jest.fn();
    element.addEventListener("close", closed);
    element.shadowRoot.querySelector("lightning-button.close").click();
    expect(closed).toHaveBeenCalledTimes(1);
  });

  it("waits for the household before asking", async () => {
    const element = createElement("c-rep-briefing", { is: RepBriefing });
    document.body.appendChild(element);
    await flushPromises();
    expect(briefing).not.toHaveBeenCalled();
  });
});
