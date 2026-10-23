import { createElement } from "lwc";
import RepGeneratedText from "c/repGeneratedText";

function render(props) {
  const element = createElement("c-rep-generated-text", {
    is: RepGeneratedText
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  return element;
}

describe("c-rep-generated-text", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows a spinner while the assistant writes", async () => {
    const element = render({ loading: true });
    expect(
      element.shadowRoot.querySelector("lightning-spinner")
    ).not.toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "Writing from this record…"
    );
    expect(element.shadowRoot.querySelector(".generated")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("shows the text as written, with a reminder to check it", async () => {
    const element = render({ text: "Balance\nPast due $190.00" });
    const generated = element.shadowRoot.querySelector(".generated");
    expect(generated.textContent.trim()).toBe("Balance\nPast due $190.00");
    expect(generated.getAttribute("aria-label")).toBe(
      "What the assistant wrote"
    );
    expect(
      element.shadowRoot.querySelector(".disclaimer").textContent.trim()
    ).toBe(
      "Written by AI from this record's data. Check it against the record before you rely on it."
    );
    await expect(element).toBeAccessible();
  });

  it("never turns the text into markup", () => {
    const element = render({
      text: '<a href="https://example.com/pay">Pay here</a>'
    });
    const generated = element.shadowRoot.querySelector(".generated");
    expect(generated.querySelector("a")).toBeNull();
    expect(generated.textContent).toContain(
      '<a href="https://example.com/pay">'
    );
  });

  it("explains why there's nothing, with the detail for an internal user", async () => {
    const element = render({
      message:
        "The assistant couldn't write this just now. Try again in a minute.",
      detail: "Einstein is unavailable."
    });
    expect(element.shadowRoot.querySelector(".message").textContent).toBe(
      "The assistant couldn't write this just now. Try again in a minute."
    );
    expect(element.shadowRoot.querySelector(".detail").textContent.trim()).toBe(
      "Einstein is unavailable."
    );
    expect(element.shadowRoot.querySelector(".generated")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("leaves the detail out when there isn't one", () => {
    const element = render({ message: "This record isn't available to you." });
    expect(element.shadowRoot.querySelector(".detail")).toBeNull();
  });
});
