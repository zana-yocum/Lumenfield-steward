import { createElement } from "lwc";
import PortalCommitments from "c/portalCommitments";
import getMyCommitments from "@salesforce/apex/PortalCommitmentsController.getMyCommitments";

jest.mock(
  "@salesforce/apex/PortalCommitmentsController.getMyCommitments",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

async function render() {
  const element = createElement("c-portal-commitments", {
    is: PortalCommitments
  });
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

describe("c-portal-commitments", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("shows each commitment's type, value, months, status and terms as recorded", async () => {
    getMyCommitments.mockResolvedValue({
      outcome: "COMPLETED",
      commitments: [
        {
          commitmentType: "Payment Coverage",
          value: 342.62,
          monthsCovered: 2,
          terms:
            "Rep agreed Lumenfield would cover the first 2 monthly payments.",
          status: "Recorded"
        },
        {
          commitmentType: "Promotional Credit",
          value: 150,
          monthsCovered: null,
          terms: "Rep promised a $150 promotional credit.",
          status: "Applied"
        }
      ]
    });
    const element = await render();
    const cards = element.shadowRoot.querySelectorAll("article");
    expect(cards).toHaveLength(2);
    expect(cards[0].querySelector("h2").textContent).toBe("Payment Coverage");
    expect(cards[0].textContent).toContain("Value$342.62");
    expect(cards[0].textContent).toContain("Months covered2");
    expect(cards[0].textContent).toContain("StatusRecorded");
    expect(cards[0].textContent).toContain(
      "As recorded at signing:“Rep agreed Lumenfield would cover the first 2 monthly payments.”"
    );
    expect(cards[1].textContent).toContain("Months coveredNot applicable");
    await expect(element).toBeAccessible();
  });

  it("says nothing was recorded and links to opening a dispute (ST-02)", async () => {
    getMyCommitments.mockResolvedValue({
      outcome: "COMPLETED",
      commitments: []
    });
    const element = await render();
    expect(element.shadowRoot.textContent).toContain(
      "No special terms were recorded when you signed."
    );
    const link = element.shadowRoot.querySelector("a");
    expect(link.textContent).toBe("Open a dispute");
    expect(link.getAttribute("href")).toBe("https://www.example.com");
    await expect(element).toBeAccessible();
  });

  it("shows only a reference when the server failed (NFR-07)", async () => {
    getMyCommitments.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "UNEXPECTED_ERROR",
      reference: "AAL-000011"
    });
    const element = await render();
    expect(
      element.shadowRoot.querySelector('[role="alert"]').textContent
    ).toContain("AAL-000011");
    expect(element.shadowRoot.querySelector("article")).toBeNull();
  });
});
