import { LightningElement, api } from "lwc";
import { LABELS } from "c/repAssistantShared";

/**
 * ST-08, ST-09, S-21. Shows what the rep assistant wrote: a spinner while it writes, then the
 * text with a reminder to check it against the record, or why there's nothing. The text is
 * rendered as text, never as HTML, so nothing a customer typed can turn into a link or markup in
 * the console.
 */
export default class RepGeneratedText extends LightningElement {
  labels = LABELS;

  /** True while the assistant is writing. */
  @api loading = false;
  /** What the assistant wrote. */
  @api text;
  /** Why there's no text, in the assistant's words. */
  @api message;
  /** The server's own message, for an internal user. */
  @api detail;
}
