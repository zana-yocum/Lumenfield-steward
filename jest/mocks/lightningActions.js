// sfdx-lwc-jest has no stub for lightning/actions. In the org, CloseActionScreenEvent closes the
// quick action's panel; here it's an ordinary "close" event a test can listen for.
export class CloseActionScreenEvent extends CustomEvent {
  constructor() {
    super("close");
  }
}
