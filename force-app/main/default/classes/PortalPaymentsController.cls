/**
 * ST-05, ST-12, NFR-07. The portal's Pay button and the page Stripe sends the customer back to.
 * Thin, like every portal controller: the household is always the logged-in customer's own
 * (PortalHousehold), never one the page names, and a statement or session from anywhere else is
 * NOT_FOUND.
 *
 * A failure gets a reference to quote, never the error. The action log holds what went wrong, with
 * the number of the Integration_Log__c record that has Stripe's own answer.
 */
public with sharing class PortalPaymentsController {
  private static final String START = 'PortalPaymentsController.startPayment';
  private static final String CONFIRM = 'PortalPaymentsController.confirmPayment';

  /**
   * Stripe's checkout page for one of the customer's statements, for its balance.
   * @param statementId the statement
   * @return the page to go to, or why not
   */
  @AuraEnabled
  public static PaymentCheckoutService.Checkout startPayment(Id statementId) {
    PaymentCheckoutService.Checkout result = new PaymentCheckoutService.Checkout();
    Id household;
    try {
      household = PortalHousehold.current();
      if (household == null) {
        result.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.INVALID_REQUEST
        );
      } else if (statementId == null) {
        result.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.NOT_FOUND
        );
      } else {
        result = PaymentCheckoutService.startCheckout(household, statementId);
      }
      String logged = saveCalls();
      if (result.outcome == StewardOutcome.FAILED) {
        new PortalFailure(household, START)
          .record(
            result,
            describe(result.reasonCode, result.failureDetail, logged)
          );
      }
    } catch (Exception error) {
      result = new PaymentCheckoutService.Checkout();
      saveCalls();
      new PortalFailure(household, START).recordException(result, error);
    }
    result.failureDetail = null;
    return result;
  }

  /**
   * Whether the checkout the customer came back from was paid. A paid one is recorded as a Lease
   * Payment at once, so the statement shows it when the page reads it again.
   * @param sessionId the session ID Stripe put in the return address
   * @return the confirmation, or why there isn't one
   */
  @AuraEnabled
  public static PaymentCheckoutService.Confirmation confirmPayment(
    String sessionId
  ) {
    PaymentCheckoutService.Confirmation result = new PaymentCheckoutService.Confirmation();
    Id household;
    try {
      household = PortalHousehold.current();
      if (household == null) {
        result.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.INVALID_REQUEST
        );
      } else {
        result = PaymentCheckoutService.confirm(household, sessionId);
      }
      String logged = saveCalls();
      if (result.outcome == StewardOutcome.FAILED) {
        new PortalFailure(household, CONFIRM)
          .record(
            result,
            describe(result.reasonCode, result.failureDetail, logged)
          );
      }
    } catch (Exception error) {
      result = new PaymentCheckoutService.Confirmation();
      saveCalls();
      new PortalFailure(household, CONFIRM).recordException(result, error);
    }
    result.failureDetail = null;
    return result;
  }

  /**
   * Saves the calls made to Stripe, after the last one.
   * @return the integration logs' numbers, such as INT-000012, or an empty string
   */
  private static String saveCalls() {
    return String.join(IntegrationLogger.save().values(), ', ');
  }

  private static String describe(
    String reasonCode,
    String detail,
    String logged
  ) {
    return reasonCode +
      ': ' +
      (detail == null ? '' : detail) +
      (String.isBlank(logged) ? '' : ' (' + logged + ')');
  }
}
