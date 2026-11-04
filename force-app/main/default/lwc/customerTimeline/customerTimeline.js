import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getTimeline from "@salesforce/apex/CustomerTimelineController.getTimeline";
import {
  OUTCOME,
  PAGES,
  format,
  formatDate,
  formatMoney,
  recordPage
} from "c/portalShared";
import { LABELS } from "./labels";

/**
 * How each kind of event reads: its filter's label, its heading (with the record's number), its
 * page on the portal if it has one, and the facts it shows, as [property, label, formatter].
 * A fact the server left out, because the person can't read that field, isn't shown at all.
 */
const KINDS = {
  STATEMENT: {
    filter: LABELS.kindStatement,
    heading: LABELS.eventStatement,
    portalPage: PAGES.statement,
    facts: [
      ["amount", LABELS.amountDue, formatMoney],
      ["balance", LABELS.balance, formatMoney],
      ["dueDate", LABELS.due, formatDate],
      ["status", LABELS.status]
    ]
  },
  PAYMENT: {
    filter: LABELS.kindPayment,
    heading: LABELS.eventPayment,
    facts: [["amount", LABELS.amountPaid, formatMoney]]
  },
  PROMISE: {
    filter: LABELS.kindPromise,
    heading: LABELS.eventPromise,
    facts: [
      ["amount", LABELS.amountPromised, formatMoney],
      ["status", LABELS.status]
    ]
  },
  DISPUTE: {
    filter: LABELS.kindDispute,
    heading: LABELS.eventDispute,
    portalPage: PAGES.dispute,
    facts: [
      ["detail", LABELS.reason],
      ["status", LABELS.status]
    ]
  },
  CREDIT: {
    filter: LABELS.kindCredit,
    heading: LABELS.eventCredit,
    facts: [
      ["amount", LABELS.amount, formatMoney],
      ["detail", LABELS.type],
      ["status", LABELS.status]
    ]
  },
  COMMITMENT: {
    filter: LABELS.kindCommitment,
    heading: LABELS.eventCommitment,
    facts: [
      ["amount", LABELS.value, formatMoney],
      ["detail", LABELS.type],
      ["status", LABELS.status]
    ]
  }
};

const NOT_FOUND = "NOT_FOUND";
/** Starts the next page this far before the end of the list comes into view. */
const SCROLL_MARGIN = "200px";

function isPresent(value) {
  return value !== undefined && value !== null && value !== "";
}

/**
 * ST-15, ST-12, NFR-05, NFR-07. One household's history on one timeline: statements, payments,
 * promises to pay, billing disputes, credits and commitments, newest first. The filter offers only
 * the kinds the person can read, and an event shows only the fields they can read: the server
 * (CustomerTimelineController) leaves the rest out.
 *
 * On an account's record page in the console it shows that account, and every event links to its
 * record. On the portal it shows the customer's own household whatever the page passes, and
 * statements and disputes link to their portal pages. More loads as the end of the list scrolls
 * into view, or with Show more, which then moves focus to the first new event.
 */
export default class CustomerTimeline extends NavigationMixin(
  LightningElement
) {
  /** The record page's account. Empty on the portal, where the server uses the customer's own. */
  @api recordId;

  labels = LABELS;
  /** The first page, before the kinds are known. */
  loading = true;
  /** A new filter's first page. */
  refreshing = false;
  loadingMore = false;
  /** Why there's no list: shown in its place. */
  problem;
  /** Why the next page didn't load: shown under the list, which stays. */
  moreProblem;
  /** The kinds this person can read, in display order. */
  kinds = [];
  /** The kinds ticked in the filter. */
  selected = [];
  events = [];
  nextCursor;
  /** Record ID → link, filled in as the links are generated. */
  links = {};

  /** Counts requests, so an answer to a filter that's since changed is ignored. */
  request = 0;
  /** After Show more: the position of the first new event, to move focus to. */
  focusIndex;
  observer;
  observed;

  connectedCallback() {
    this.loadFirstPage(null);
  }

  renderedCallback() {
    this.watchTheEnd();
    this.moveFocus();
  }

  disconnectedCallback() {
    this.observer?.disconnect();
    this.observer = undefined;
    this.observed = undefined;
  }

  get sectionClass() {
    return this.recordId ? "timeline card" : "timeline";
  }

  get hasKinds() {
    return this.kinds.length > 0;
  }

  get noneSelected() {
    return this.hasKinds && this.selected.length === 0;
  }

  get hasEvents() {
    return this.events.length > 0;
  }

  get hasMore() {
    return Boolean(this.nextCursor);
  }

  get filters() {
    return this.kinds.map((code) => ({
      code,
      label: KINDS[code]?.filter ?? code,
      checked: this.selected.includes(code)
    }));
  }

  get items() {
    return this.events.map((event, index) => this.itemFor(event, index));
  }

  get emptyMessage() {
    if (!this.hasKinds) {
      return LABELS.noAccess;
    }
    return this.selected.length < this.kinds.length
      ? LABELS.emptyFiltered
      : LABELS.empty;
  }

  get countMessage() {
    return format(
      this.hasMore ? LABELS.showing : LABELS.showingAll,
      this.events.length
    );
  }

  get moreLabel() {
    return this.loadingMore ? LABELS.loadingMore : LABELS.showMore;
  }

  get busy() {
    return this.loadingMore ? "true" : undefined;
  }

  handleFilterChange(event) {
    const { value, checked } = event.target;
    this.selected = this.kinds.filter((code) =>
      code === value ? checked : this.selected.includes(code)
    );
    this.events = [];
    this.nextCursor = undefined;
    this.problem = undefined;
    this.moreProblem = undefined;
    this.loadingMore = false;
    if (this.selected.length === 0) {
      this.request++;
      this.refreshing = false;
      return;
    }
    this.refreshing = true;
    this.loadFirstPage([...this.selected]);
  }

  handleShowMore() {
    this.loadMore(true);
  }

  handleOpen(event) {
    const id = event.currentTarget.dataset.id;
    const timelineEvent = this.events.find((e) => e.recordId === id);
    const page = timelineEvent ? this.pageFor(timelineEvent) : null;
    if (page) {
      event.preventDefault();
      this[NavigationMixin.Navigate](page);
    }
  }

  /**
   * Loads the first page. The very first one also says which kinds this person can read.
   * @param {string[]|null} kinds the kinds to show; null for every kind
   */
  async loadFirstPage(kinds) {
    const request = ++this.request;
    try {
      const page = await getTimeline({
        recordId: this.recordId,
        kinds,
        cursor: null
      });
      if (request !== this.request) {
        return;
      }
      this.problem = this.problemFor(page);
      if (this.problem) {
        return;
      }
      if (this.loading) {
        this.kinds = page.availableKinds ?? [];
        this.selected = [...this.kinds];
      }
      this.events = page.events ?? [];
      this.nextCursor = page.nextCursor;
      this.linkEvents(this.events);
    } catch {
      if (request === this.request) {
        this.problem = LABELS.connectionProblem;
      }
    } finally {
      if (request === this.request) {
        this.loading = false;
        this.refreshing = false;
      }
    }
  }

  /**
   * Loads the next page and adds it to the list. Nothing happens while another page loads.
   * @param {boolean} byButton true for Show more, which moves focus to the first new event
   */
  async loadMore(byButton) {
    if (
      !this.nextCursor ||
      this.loading ||
      this.refreshing ||
      this.loadingMore
    ) {
      return;
    }
    const request = this.request;
    this.loadingMore = true;
    this.moreProblem = undefined;
    try {
      const page = await getTimeline({
        recordId: this.recordId,
        kinds: [...this.selected],
        cursor: this.nextCursor
      });
      if (request !== this.request) {
        return;
      }
      this.moreProblem = this.problemFor(page);
      if (this.moreProblem) {
        return;
      }
      const added = page.events ?? [];
      if (byButton && added.length > 0) {
        this.focusIndex = this.events.length;
      }
      this.events = [...this.events, ...added];
      this.nextCursor = page.nextCursor;
      // Watch the end of the list afresh: if it's still in view, the next page loads too.
      this.observed = undefined;
      this.linkEvents(added);
    } catch {
      if (request === this.request) {
        this.moreProblem = LABELS.connectionProblem;
      }
    } finally {
      if (request === this.request) {
        this.loadingMore = false;
      }
    }
  }

  /**
   * What to say about a page that isn't a success.
   * @param {object} page the server's answer
   * @returns {string|null} the message, or null for a success
   */
  problemFor(page) {
    if (page?.outcome === OUTCOME.completed) {
      return null;
    }
    if (page?.outcome === OUTCOME.failed && page.reference) {
      return format(LABELS.failedWithReference, page.reference);
    }
    if (page?.reasonCode === NOT_FOUND) {
      return this.recordId ? LABELS.notAHousehold : LABELS.notAvailable;
    }
    return LABELS.failed;
  }

  /**
   * One event as the list shows it.
   * @param {object} event the event, as the server sent it
   * @param {number} index its position in the list
   * @returns {object} what the template needs
   */
  itemFor(event, index) {
    const kind = KINDS[event.kind] ?? { heading: "{0}", facts: [] };
    const facts = kind.facts
      .filter(([property]) => isPresent(event[property]))
      .map(([property, label, show]) => ({
        key: property,
        label,
        value: show ? show(event[property]) : event[property]
      }));
    return {
      key: `${event.kind}-${event.recordId}`,
      index,
      recordId: event.recordId,
      heading: format(kind.heading, event.name),
      isoDate: event.eventDate,
      date: formatDate(event.eventDate),
      undated: !event.eventDate,
      link: this.links[event.recordId],
      facts,
      hasFacts: facts.length > 0
    };
  }

  /**
   * Where an event's link goes: its record in the console; on the portal, a statement's or a
   * dispute's own page. Other events on the portal have no page of their own.
   * @param {object} event the event
   * @returns {object|null} the page reference, or null for no link
   */
  pageFor(event) {
    if (this.recordId) {
      return {
        type: "standard__recordPage",
        attributes: { recordId: event.recordId, actionName: "view" }
      };
    }
    const name = KINDS[event.kind]?.portalPage;
    return name ? recordPage(event.recordId, name) : null;
  }

  async linkEvents(events) {
    const links = await Promise.all(
      events.map(async (event) => {
        const page = this.pageFor(event);
        if (!page) {
          return null;
        }
        try {
          return [
            event.recordId,
            await this[NavigationMixin.GenerateUrl](page)
          ];
        } catch {
          return null;
        }
      })
    );
    this.links = {
      ...this.links,
      ...Object.fromEntries(links.filter(Boolean))
    };
  }

  /**
   * Watches the end of the list, so the next page loads as it scrolls into view. Show more does
   * the same for keyboard users, and wherever the browser can't watch.
   */
  watchTheEnd() {
    const end = this.template.querySelector(".end-of-list");
    if (end === this.observed) {
      return;
    }
    this.observer?.disconnect();
    this.observer = undefined;
    this.observed = end;
    if (!end || typeof IntersectionObserver === "undefined") {
      return;
    }
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          this.loadMore(false);
        }
      },
      { rootMargin: SCROLL_MARGIN }
    );
    this.observer.observe(end);
  }

  moveFocus() {
    if (this.focusIndex === undefined) {
      return;
    }
    const target = this.template.querySelector(
      `[data-index="${this.focusIndex}"]`
    );
    this.focusIndex = undefined;
    target?.focus();
  }
}
