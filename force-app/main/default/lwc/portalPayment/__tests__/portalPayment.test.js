import { createElement } from "lwc";
import PortalPayment from "c/portalPayment";
import startPayment from "@salesforce/apex/PortalPaymentsController.startPayment";
import confirmPayment from "@salesforce/apex/PortalPaymentsController.confirmPayment";

jest.mock(
  "@salesforce/apex/PortalPaymentsController.startPayment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PortalPaymentsController.confirmPayment",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// Records where the component sends the customer.
const mockNavigate = jest.fn();
jest.mock("lightning/navigation", () => {
  const Navigate = Symbol("Navigate");
  const GenerateUrl = Symbol("GenerateUrl");
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](pageRef) {
        mockNavigate(pageRef);
      }
      [GenerateUrl]() {
        return Promise.resolve("https://www.example.com");
      }
    };
  NavigationMixin.Navigate = Navigate;
  NavigationMixin.GenerateUrl = GenerateUrl;
  return { NavigationMixin };
});

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));
const STATEMENT_ID = "a01000000000001AAA";
const CHECKOUT = "https://checkout.stripe.com/c/pay/cs_test_1";

// onRefresh listens from the start: a recorded payment asks for a refresh as soon as it's confirmed.
async function render(props = {}, onRefresh) {
  const element = createElement("c-portal-payment", { is: PortalPayment });
  Object.assign(element, { statementId: STATEMENT_ID, balance: 120 }, props);
  if (onRefresh) {
    element.addEventListener("refresh", onRefresh);
  }
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

function text(element) {
  return element.shadowRoot.textContent;
}

describe("c-portal-payment", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("offers to pay the balance on Stripe's secure page", async () => {
    const element = await render();

    const button = element.shadowRoot.querySelector(".pay-button");
    expect(button.textContent.trim()).toBe("Pay $120.00");
    expect(text(element)).toContain(
      "You'll pay on Stripe's secure page. Your card details never reach Lumenfield."
    );
    expect(element.shadowRoot.querySelector("h2").textContent).toBe(
      "Pay online"
    );
    await expect(element).toBeAccessible();
  });

  it("sends the customer to Stripe's page for this statement", async () => {
    startPayment.mockResolvedValue({
      outcome: "COMPLETED",
      checkoutUrl: CHECKOUT,
      amount: 120
    });
    const element = await render();

    element.shadowRoot.querySelector(".pay-button").click();
    await flushPromises();

    expect(startPayment).toHaveBeenCalledWith({ statementId: STATEMENT_ID });
    expect(mockNavigate).toHaveBeenCalledWith({
      type: "standard__webPage",
      attributes: { url: CHECKOUT }
    });
  });

  it("shows no Pay button when nothing is owed", async () => {
    const element = await render({ balance: 0 });

    expect(element.shadowRoot.querySelector(".pay-button")).toBeNull();
  });

  it("says when online payment isn't available, with a reference", async () => {
    startPayment.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "PROVIDER_UNAVAILABLE",
      reference: "AAL-000321"
    });
    const element = await render();

    element.shadowRoot.querySelector(".pay-button").click();
    await flushPromises();

    expect(mockNavigate).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "Online payment isn't available right now. Please try again later, and quote reference AAL-000321 if you contact us."
    );
    expect(element.shadowRoot.querySelector(".pay-button")).not.toBeNull();
    await expect(element).toBeAccessible();
  });

  it("says when the statement has nothing left to pay", async () => {
    startPayment.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOTHING_OWED"
    });
    const element = await render();

    element.shadowRoot.querySelector(".pay-button").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "There's nothing to pay on this statement."
    );
  });

  it("explains a lost connection without any error details", async () => {
    startPayment.mockRejectedValue(new Error("Network down"));
    const element = await render();

    element.shadowRoot.querySelector(".pay-button").click();
    await flushPromises();

    const alert = element.shadowRoot.querySelector("[role=alert]");
    expect(alert.textContent).toContain("Check your connection");
    expect(alert.textContent).not.toContain("Network down");
  });

  it("thanks the customer coming back from a paid checkout, and refreshes the statement", async () => {
    confirmPayment.mockResolvedValue({
      outcome: "COMPLETED",
      statementId: STATEMENT_ID,
      amount: 120,
      recorded: true
    });
    const refreshed = jest.fn();
    const element = await render({ sessionId: "cs_test_1" }, refreshed);

    expect(confirmPayment).toHaveBeenCalledWith({ sessionId: "cs_test_1" });
    expect(element.shadowRoot.querySelector("[role=status]").textContent).toBe(
      "Thank you. Your payment of $120.00 is received."
    );
    expect(refreshed).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.querySelector(".pay-button")).toBeNull();
    expect(text(element)).not.toContain("within the hour");
    await expect(element).toBeAccessible();
  });

  it("says when a payment received will show on the statement later", async () => {
    confirmPayment.mockResolvedValue({
      outcome: "COMPLETED",
      statementId: STATEMENT_ID,
      amount: 120,
      recorded: false
    });
    const refreshed = jest.fn();
    const element = await render({ sessionId: "cs_test_1" }, refreshed);

    expect(text(element)).toContain(
      "Thank you. Your payment of $120.00 is received."
    );
    expect(text(element)).toContain(
      "It will show on this statement within the hour."
    );
    expect(refreshed).not.toHaveBeenCalled();
    expect(element.shadowRoot.querySelector(".pay-button")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("says no payment was taken when the checkout wasn't paid", async () => {
    confirmPayment.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_PAID"
    });
    const element = await render({ sessionId: "cs_test_1" });

    expect(text(element)).toContain(
      "No payment was taken. You can try again whenever you're ready."
    );
    expect(element.shadowRoot.querySelector(".pay-button")).not.toBeNull();
  });

  it("says the same when the customer went back from Stripe", async () => {
    const element = await render({ cancelled: true });

    expect(confirmPayment).not.toHaveBeenCalled();
    expect(text(element)).toContain("No payment was taken.");
  });

  it("can't find a payment that isn't on this account", async () => {
    confirmPayment.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND"
    });
    const element = await render({ sessionId: "cs_test_9" });

    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "We couldn't find that payment on your account. If you were charged, contact us."
    );
  });

  it("gives a reference when the payment can't be checked", async () => {
    confirmPayment.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "PROVIDER_UNAVAILABLE",
      reference: "AAL-000322"
    });
    const element = await render({ sessionId: "cs_test_1" });

    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "Online payment isn't available right now. Please try again later, and quote reference AAL-000322 if you contact us."
    );
    await expect(element).toBeAccessible();
  });
});
