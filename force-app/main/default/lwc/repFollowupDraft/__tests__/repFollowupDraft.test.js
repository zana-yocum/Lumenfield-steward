import { createElement } from "lwc";
import RepFollowupDraft from "c/repFollowupDraft";
import followupDraft from "@salesforce/apex/RepAssistantController.followupDraft";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";

const mockNavigate = jest.fn();

jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](pageReference) {
        mockNavigate(pageReference);
      }
    };
  NavigationMixin.Navigate = Navigate;
  return { NavigationMixin };
});

jest.mock(
  "@salesforce/apex/RepAssistantController.followupDraft",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const ACCOUNT_ID = "001000000000001AAA";
const EMAIL = {
  outcome: "COMPLETED",
  toAddress: "sandra.barnett@example.com",
  subject: "Your payment arrangement",
  htmlBody: "<p>Hi Sandra,</p><p>Thanks for talking with us today.</p>"
};

async function render(closed = jest.fn()) {
  const element = createElement("c-rep-followup-draft", {
    is: RepFollowupDraft
  });
  element.addEventListener("close", closed);
  element.recordId = ACCOUNT_ID;
  document.body.appendChild(element);
  await flushPromises();
  await flushPromises();
  return element;
}

function generatedText(element) {
  return element.shadowRoot.querySelector("c-rep-generated-text");
}

describe("c-rep-followup-draft", () => {
  beforeEach(() => {
    encodeDefaultFieldValues.mockImplementation((values) =>
      JSON.stringify(values)
    );
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("opens the draft in the email composer, addressed, and closes", async () => {
    followupDraft.mockResolvedValue(EMAIL);
    const closed = jest.fn();
    await render(closed);
    expect(followupDraft).toHaveBeenCalledWith({ accountId: ACCOUNT_ID });
    expect(mockNavigate).toHaveBeenCalledTimes(1);
    const pageReference = mockNavigate.mock.calls[0][0];
    expect(pageReference.type).toBe("standard__quickAction");
    expect(pageReference.attributes.apiName).toBe("Global.SendEmail");
    expect(pageReference.state.recordId).toBe(ACCOUNT_ID);
    expect(JSON.parse(pageReference.state.defaultFieldValues)).toEqual({
      Subject: EMAIL.subject,
      HtmlBody: EMAIL.htmlBody,
      RelatedToId: ACCOUNT_ID,
      ToAddress: EMAIL.toAddress
    });
    expect(closed).toHaveBeenCalledTimes(1);
  });

  it("leaves the To line for the rep when there's no address", async () => {
    followupDraft.mockResolvedValue({ ...EMAIL, toAddress: null });
    await render();
    const values = JSON.parse(
      mockNavigate.mock.calls[0][0].state.defaultFieldValues
    );
    expect(values.ToAddress).toBeUndefined();
  });

  it("asks the rep to log today's contact attempt first", async () => {
    followupDraft.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NO_ATTEMPT_TODAY"
    });
    const closed = jest.fn();
    const element = await render(closed);
    expect(generatedText(element).message).toBe(
      "Log today's contact attempt first, so the draft reflects what happened on the call."
    );
    expect(mockNavigate).not.toHaveBeenCalled();
    expect(closed).not.toHaveBeenCalled();
    expect(
      element.shadowRoot.querySelector("lightning-quick-action-panel").header
    ).toBe("Follow-up Draft");
    await expect(element).toBeAccessible();
  });

  it("reports a failure without opening the composer", async () => {
    followupDraft.mockRejectedValue({
      body: { message: "Insufficient access" }
    });
    const element = await render();
    expect(generatedText(element).message).toBe(
      "The assistant couldn't write this just now. Try again in a minute."
    );
    expect(generatedText(element).detail).toBe("Insufficient access");
    expect(mockNavigate).not.toHaveBeenCalled();
  });

  it("closes on Close", async () => {
    followupDraft.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const closed = jest.fn();
    const element = await render(closed);
    element.shadowRoot.querySelector("lightning-button.close").click();
    expect(closed).toHaveBeenCalledTimes(1);
  });
});
