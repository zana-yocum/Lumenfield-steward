# TestIds

**What it does:** Gives a test a well-formed ID that no record has, built from the object's key prefix: `TestIds.missing(Billing_Statement__c.SObjectType)`.

**Why it exists:** NFR-03. Some tests need a record that doesn't exist, such as a payment for a statement that was never there. Writing an ID into a test breaks between orgs, and Code Analyzer flags it.

**How it works:** The key prefix comes from a deferred describe, followed by twelve characters ending in 1.

**What can go wrong:** Nothing a test depends on. The ID belongs to no record anywhere.

**How it's tested:** By the tests that use it: `PaymentRecorderTest`, `CheckoutPaymentsTest` and `IntegrationLoggerTest`.
