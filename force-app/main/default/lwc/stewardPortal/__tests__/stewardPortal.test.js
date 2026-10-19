import {
  CONNECTION_PROBLEM,
  formatDate,
  formatMoney,
  namedPage,
  problemMessage,
  recordIdFrom,
  recordPage
} from "c/stewardPortal";

describe("c/stewardPortal", () => {
  describe("problemMessage", () => {
    it("says nothing about a success", () => {
      expect(problemMessage({ outcome: "COMPLETED" }, "Not here")).toBeNull();
    });

    it("gives a failure's reference and never its details (NFR-07)", () => {
      const message = problemMessage(
        {
          outcome: "FAILED",
          reasonCode: "UNEXPECTED_ERROR",
          reference: "AAL-000042"
        },
        "Not here"
      );
      expect(message).toContain("AAL-000042");
      expect(message).not.toContain("UNEXPECTED_ERROR");
    });

    it("asks the customer to try again when a failure has no reference", () => {
      expect(problemMessage({ outcome: "FAILED" }, "Not here")).toBe(
        "Something went wrong on our side. Please try again later."
      );
    });

    it("explains a missing record in the page's own words", () => {
      expect(
        problemMessage(
          { outcome: "DECLINED_POLICY", reasonCode: "NOT_FOUND" },
          "Not here"
        )
      ).toBe("Not here");
    });

    it("tells someone without a household that the page is for customers", () => {
      expect(
        problemMessage(
          { outcome: "DECLINED_POLICY", reasonCode: "INVALID_REQUEST" },
          "Not here"
        )
      ).toContain("for Lumenfield customers");
    });

    it("falls back to a plain message for anything else, or no answer at all", () => {
      const other = problemMessage(
        { outcome: "DECLINED_POLICY", reasonCode: "SOMETHING_NEW" },
        "Not here"
      );
      expect(other).toContain("try again later");
      expect(problemMessage(undefined, "Not here")).toBe(other);
      expect(CONNECTION_PROBLEM).toContain("connection");
    });
  });

  describe("formatting", () => {
    it("formats money to the cent, and nothing as $0.00", () => {
      expect(formatMoney(1234.5)).toBe("$1,234.50");
      expect(formatMoney(null)).toBe("$0.00");
    });

    it("formats a server date without shifting it a day", () => {
      expect(formatDate("2026-10-01")).toBe("Oct 1, 2026");
      expect(formatDate(null)).toBe("");
    });
  });

  describe("page references", () => {
    it("builds a named page, and a record's page with its ID in the address", () => {
      expect(namedPage("Disputes__c")).toEqual({
        type: "comm__namedPage",
        attributes: { name: "Disputes__c" }
      });
      expect(recordPage("500000000000001AAA", "Dispute__c")).toEqual({
        type: "comm__namedPage",
        attributes: { name: "Dispute__c" },
        state: { recordId: "500000000000001AAA" }
      });
    });

    it("reads the record ID back from the address", () => {
      const pageRef = recordPage("a01000000000001AAA", "Statement__c");
      expect(recordIdFrom(pageRef)).toBe("a01000000000001AAA");
      expect(recordIdFrom(namedPage("Statement__c"))).toBeUndefined();
      expect(recordIdFrom(undefined)).toBeUndefined();
    });
  });
});
