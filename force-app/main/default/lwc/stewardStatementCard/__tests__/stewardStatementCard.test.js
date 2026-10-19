import { createElement } from "lwc";
import StewardStatementCard from "c/stewardStatementCard";

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const STATEMENT = {
  statementId: "a01000000000001AAA",
  statementNumber: "BS-000101",
  statementDate: "2026-09-01",
  dueDate: "2026-09-15",
  amountDue: 120,
  amountPaid: 50,
  creditsApplied: 0,
  balance: 70,
  status: "Past Due",
  payments: [
    { paymentId: "a02000000000001AAA", paymentDate: "2026-09-10", amount: 50 }
  ]
};

async function render(props) {
  const element = createElement("c-steward-statement-card", {
    is: StewardStatementCard
  });
  Object.assign(element, props);
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

describe("c-steward-statement-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows the amounts, the status and each payment's date and amount only", async () => {
    const element = await render({ statement: STATEMENT, linkToDetail: true });
    const text = element.shadowRoot.textContent;
    expect(element.shadowRoot.querySelector("h2 a").textContent).toBe(
      "Statement BS-000101"
    );
    expect(text).toContain("Past Due");
    expect(text).toContain("Amount due$120.00");
    expect(text).toContain("Paid$50.00");
    expect(text).toContain("Balance$70.00");
    const payments = [...element.shadowRoot.querySelectorAll("li")].map(
      (li) => li.textContent
    );
    expect(payments).toEqual(["Sep 10, 2026: $50.00"]);
    await expect(element).toBeAccessible();
  });

  it("links to an open dispute", async () => {
    const element = await render({
      statement: {
        ...STATEMENT,
        status: "In Dispute",
        disputeCaseId: "500000000000001AAA",
        disputeCaseNumber: "00001001"
      }
    });
    const dispute = element.shadowRoot.querySelector(".dispute a");
    expect(dispute.textContent).toBe("case 00001001");
    expect(dispute.getAttribute("href")).toBe("https://www.example.com");
  });

  it("leaves the title to the page, and keeps the headings in order, on the statement's own page", async () => {
    const element = await render({
      statement: { ...STATEMENT, payments: [] },
      hideTitle: true
    });
    expect(element.shadowRoot.querySelector("h3")).toBeNull();
    expect(element.shadowRoot.querySelector("h2").textContent).toBe("Payments");
    expect(element.shadowRoot.textContent).toContain(
      "No payments on this statement yet."
    );
  });
});
