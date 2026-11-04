/**
 * ST-05, S-02, S-27. Records each Payment_Received__e as a Lease Payment, once. All the work is in
 * PaymentReceivedTriggerHandler.
 */
trigger PaymentReceivedTrigger on Payment_Received__e(after insert) {
  PaymentReceivedTriggerHandler.handle(Trigger.new);
}
