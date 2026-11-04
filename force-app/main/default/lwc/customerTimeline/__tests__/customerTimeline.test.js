import { createElement } from "lwc";
import CustomerTimeline from "c/customerTimeline";
import getTimeline from "@salesforce/apex/CustomerTimelineController.getTimeline";

jest.mock(
  "@salesforce/apex/CustomerTimelineController.getTimeline",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const ACCOUNT_ID = "001000000000001AAA";
const ALL_KINDS = [
  "STATEMENT",
  "PAYMENT",
  "PROMISE",
  "DISPUTE",
  "CREDIT",
  "COMMITMENT"
];

const PROMISE = {
  kind: "PROMISE",
  recordId: "a03000000000001AAA",
  name: "PTP-00007",
  eventDate: "2026-11-11",
  amount: 80,
  status: "Active"
};
const DISPUTE = {
  kind: "DISPUTE",
  recordId: "500000000000001AAA",
  name: "00001049",
  eventDate: "2026-11-04",
  status: "New",
  detail: "Payment Not Posted"
};
const PAYMENT = {
  kind: "PAYMENT",
  recordId: "a02000000000001AAA",
  name: "PAY-00031",
  eventDate: "2026-09-30",
  amount: 40
};
const STATEMENT = {
  kind: "STATEMENT",
  recordId: "a01000000000001AAA",
  name: "STMT-00012",
  eventDate: "2026-09-11",
  amount: 120,
  balance: 55,
  dueDate: "2026-10-01",
  status: "Past Due"
};

function page(events, extra = {}) {
  return {
    outcome: "COMPLETED",
    availableKinds: ALL_KINDS,
    events,
    nextCursor: null,
    ...extra
  };
}

async function render(recordId = ACCOUNT_ID) {
  const element = createElement("c-customer-timeline", {
    is: CustomerTimeline
  });
  if (recordId) {
    element.recordId = recordId;
  }
  document.body.appendChild(element);
  await flushPromises();
  return element;
}

function headings(element) {
  return [...element.shadowRoot.querySelectorAll(".event-title")].map((h) =>
    h.textContent.trim()
  );
}

function checkbox(element, code) {
  return element.shadowRoot.querySelector(`input[value="${code}"]`);
}

async function untick(element, code) {
  const box = checkbox(element, code);
  box.checked = false;
  box.dispatchEvent(new CustomEvent("change"));
  await flushPromises();
}

describe("c-customer-timeline", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
    delete global.IntersectionObserver;
  });

  it("shows the account's history newest first, with a filter for every kind", async () => {
    getTimeline.mockResolvedValue(page([PROMISE, DISPUTE, PAYMENT, STATEMENT]));
    const element = await render();

    expect(getTimeline).toHaveBeenCalledWith({
      recordId: ACCOUNT_ID,
      kinds: null,
      cursor: null
    });
    expect(headings(element)).toEqual([
      "Promise to pay PTP-00007",
      "Dispute 00001049",
      "Payment PAY-00031",
      "Statement STMT-00012"
    ]);
    const statement = element.shadowRoot.querySelectorAll(".event")[3];
    expect(statement.querySelector("time").getAttribute("datetime")).toBe(
      "2026-09-11"
    );
    expect(statement.textContent).toContain("Sep 11, 2026");
    expect(statement.textContent).toContain("Amount due$120.00");
    expect(statement.textContent).toContain("Balance$55.00");
    expect(statement.textContent).toContain("DueOct 1, 2026");
    expect(statement.textContent).toContain("StatusPast Due");
    const boxes = element.shadowRoot.querySelectorAll("input[type=checkbox]");
    expect([...boxes].map((box) => box.value)).toEqual(ALL_KINDS);
    expect([...boxes].every((box) => box.checked)).toBe(true);
    expect(element.shadowRoot.querySelector("legend").textContent).toBe("Show");
    expect(element.shadowRoot.querySelector(".count").textContent).toBe(
      "Events shown: 4. That's all of them."
    );
    expect(element.shadowRoot.querySelector(".more")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("in the console, links every event to its record", async () => {
    getTimeline.mockResolvedValue(page([PAYMENT]));
    const element = await render();
    await flushPromises();

    const link = element.shadowRoot.querySelector(".event-title a");
    expect(link.textContent).toBe("Payment PAY-00031");
    expect(link.getAttribute("href")).toBe("https://www.example.com");
    expect(element.shadowRoot.querySelector("section").className).toContain(
      "card"
    );
  });

  it("on the portal, links only statements and disputes, which have pages there", async () => {
    getTimeline.mockResolvedValue(
      page([DISPUTE, PAYMENT, STATEMENT], {
        availableKinds: ["STATEMENT", "PAYMENT", "PROMISE", "DISPUTE"]
      })
    );
    const element = await render(null);
    await flushPromises();

    expect(getTimeline).toHaveBeenCalledWith({
      recordId: undefined,
      kinds: null,
      cursor: null
    });
    const titles = element.shadowRoot.querySelectorAll(".event-title");
    expect(titles[0].querySelector("a")).not.toBeNull();
    expect(titles[1].querySelector("a")).toBeNull();
    expect(titles[2].querySelector("a")).not.toBeNull();
    expect(
      element.shadowRoot.querySelectorAll("input[type=checkbox]")
    ).toHaveLength(4);
    await expect(element).toBeAccessible();
  });

  it("leaves out a fact the person can't read", async () => {
    getTimeline.mockResolvedValue(
      page([{ ...STATEMENT, amount: undefined, balance: undefined }])
    );
    const element = await render();

    const text = element.shadowRoot.querySelector(".event").textContent;
    expect(text).not.toContain("Amount due");
    expect(text).not.toContain("Balance");
    expect(text).toContain("StatusPast Due");
  });

  it("says when a record has no date", async () => {
    getTimeline.mockResolvedValue(
      page([{ ...STATEMENT, eventDate: undefined }])
    );
    const element = await render();

    const event = element.shadowRoot.querySelector(".event");
    expect(event.querySelector("time")).toBeNull();
    expect(event.textContent).toContain("No date recorded");
  });

  it("says when there's no history yet", async () => {
    getTimeline.mockResolvedValue(page([]));
    const element = await render();

    expect(element.shadowRoot.textContent).toContain(
      "There's no history on this account yet."
    );
    expect(element.shadowRoot.querySelector("ol")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("says when none of the history is shared with the person", async () => {
    getTimeline.mockResolvedValue(page([], { availableKinds: [] }));
    const element = await render();

    expect(element.shadowRoot.querySelector("fieldset")).toBeNull();
    expect(element.shadowRoot.textContent).toContain(
      "None of this account's history is shared with you."
    );
  });

  it("shows a reference to quote when the server fails, never the error", async () => {
    getTimeline.mockResolvedValue({
      outcome: "FAILED",
      reasonCode: "UNEXPECTED_ERROR",
      reference: "TL-4821",
      availableKinds: [],
      events: []
    });
    const element = await render();

    const alert = element.shadowRoot.querySelector("[role=alert]");
    expect(alert.textContent).toBe(
      "The history couldn't load. If it keeps happening, quote reference TL-4821."
    );
    expect(element.shadowRoot.querySelector("fieldset")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("says when the request never got an answer", async () => {
    getTimeline.mockRejectedValue(new Error("offline"));
    const element = await render();

    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "The history couldn't load. Check your connection, then try again."
    );
  });

  it("explains an account that isn't a household in the console, and a missing one on the portal", async () => {
    getTimeline.mockResolvedValue({
      outcome: "DECLINED_POLICY",
      reasonCode: "NOT_FOUND",
      availableKinds: [],
      events: []
    });
    const consoleView = await render();
    expect(
      consoleView.shadowRoot.querySelector("[role=alert]").textContent
    ).toBe("History is kept for household accounts.");

    const portalView = await render(null);
    expect(
      portalView.shadowRoot.querySelector("[role=alert]").textContent
    ).toBe("Your account history isn't available right now.");
  });

  it("filters by kind, from the first page", async () => {
    getTimeline.mockResolvedValueOnce(page([PROMISE, PAYMENT, STATEMENT]));
    const element = await render();
    getTimeline.mockResolvedValueOnce(page([PROMISE, STATEMENT]));

    await untick(element, "PAYMENT");

    expect(getTimeline).toHaveBeenLastCalledWith({
      recordId: ACCOUNT_ID,
      kinds: ["STATEMENT", "PROMISE", "DISPUTE", "CREDIT", "COMMITMENT"],
      cursor: null
    });
    expect(headings(element)).toEqual([
      "Promise to pay PTP-00007",
      "Statement STMT-00012"
    ]);
    expect(checkbox(element, "PAYMENT").checked).toBe(false);
    await expect(element).toBeAccessible();
  });

  it("says when nothing of the chosen kinds has happened", async () => {
    getTimeline.mockResolvedValueOnce(page([PAYMENT]));
    const element = await render();
    getTimeline.mockResolvedValueOnce(page([]));

    await untick(element, "PAYMENT");

    expect(element.shadowRoot.textContent).toContain(
      "Nothing of the kinds you chose yet."
    );
  });

  it("asks for a kind when every one is unticked, without asking the server", async () => {
    getTimeline.mockResolvedValueOnce(
      page([PAYMENT], { availableKinds: ["PAYMENT"] })
    );
    const element = await render();

    await untick(element, "PAYMENT");

    expect(getTimeline).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.textContent).toContain(
      "Choose at least one kind of event to show."
    );
    expect(element.shadowRoot.querySelector("ol")).toBeNull();
    await expect(element).toBeAccessible();
  });

  it("ignores an answer for a filter that has since changed", async () => {
    getTimeline.mockResolvedValueOnce(page([PROMISE, PAYMENT, STATEMENT]));
    const element = await render();
    let answerTheFirstChange;
    getTimeline.mockReturnValueOnce(
      new Promise((resolve) => {
        answerTheFirstChange = resolve;
      })
    );
    getTimeline.mockResolvedValueOnce(page([PROMISE]));

    await untick(element, "PAYMENT");
    await untick(element, "STATEMENT");
    answerTheFirstChange(page([PROMISE, STATEMENT]));
    await flushPromises();

    expect(headings(element)).toEqual(["Promise to pay PTP-00007"]);
  });

  it("loads the next page with Show more and moves focus to the first new event", async () => {
    getTimeline.mockResolvedValueOnce(
      page([PROMISE, DISPUTE], { nextCursor: '{"PROMISE":1,"DISPUTE":1}' })
    );
    const element = await render();
    const count = element.shadowRoot.querySelector(".count");
    expect(count.textContent).toBe(
      "Events shown: 2. More load as you scroll, or choose Show more."
    );
    await expect(element).toBeAccessible();
    getTimeline.mockResolvedValueOnce(page([PAYMENT, STATEMENT]));

    element.shadowRoot.querySelector(".more").click();
    await flushPromises();

    expect(getTimeline).toHaveBeenLastCalledWith({
      recordId: ACCOUNT_ID,
      kinds: ALL_KINDS,
      cursor: '{"PROMISE":1,"DISPUTE":1}'
    });
    expect(headings(element)).toHaveLength(4);
    expect(element.shadowRoot.activeElement.textContent.trim()).toBe(
      "Payment PAY-00031"
    );
    expect(element.shadowRoot.querySelector(".more")).toBeNull();
    expect(element.shadowRoot.querySelector(".count").textContent).toBe(
      "Events shown: 4. That's all of them."
    );
  });

  it("keeps the list when the next page fails, so it can be tried again", async () => {
    getTimeline.mockResolvedValueOnce(page([PROMISE], { nextCursor: "next" }));
    const element = await render();
    getTimeline.mockRejectedValueOnce(new Error("offline"));

    element.shadowRoot.querySelector(".more").click();
    await flushPromises();

    expect(headings(element)).toEqual(["Promise to pay PTP-00007"]);
    expect(element.shadowRoot.querySelector("[role=alert]").textContent).toBe(
      "The history couldn't load. Check your connection, then try again."
    );
    expect(element.shadowRoot.querySelector(".more")).not.toBeNull();
    await expect(element).toBeAccessible();
  });

  it("loads more as the end of the list scrolls into view", async () => {
    const watchers = [];
    global.IntersectionObserver = class {
      constructor(callback) {
        this.callback = callback;
        watchers.push(this);
      }
      observe(target) {
        this.target = target;
      }
      disconnect() {
        this.target = undefined;
      }
    };
    getTimeline.mockResolvedValueOnce(page([PROMISE], { nextCursor: "next" }));
    const element = await render();
    getTimeline.mockResolvedValueOnce(page([DISPUTE]));

    const watcher = watchers.find((w) => w.target);
    expect(watcher.target.className).toBe("end-of-list");
    watcher.callback([{ isIntersecting: true }]);
    await flushPromises();

    expect(getTimeline).toHaveBeenLastCalledWith({
      recordId: ACCOUNT_ID,
      kinds: ALL_KINDS,
      cursor: "next"
    });
    expect(headings(element)).toEqual([
      "Promise to pay PTP-00007",
      "Dispute 00001049"
    ]);
    expect(element.shadowRoot.activeElement).toBeNull();
  });
});
