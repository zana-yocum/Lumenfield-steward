# TimelineKind

**What it does:** Describes the six kinds of event on the customer timeline, in the order the timeline shows them on the same date. For each one it records the object, the field that ties it to the household, the date that places it, the record's number, any condition, and the facts it shows. It also builds the kind's query and turns a record into an event.

| Kind | Object | Tied to the household by | Placed by | Facts |
|---|---|---|---|---|
| STATEMENT | `Billing_Statement__c` | `Account__c` | `Statement_Date__c` | Amount due, balance, due date, status |
| PAYMENT | `Payment__c` | `Billing_Statement__r.Account__c` | `Payment_Date__c` | Amount paid |
| PROMISE | `Promise_to_Pay__c` | `Account__c` | `Promise_Date__c` | Amount promised, status |
| DISPUTE | `Case`, Billing Dispute record type only | `AccountId` | `CreatedDate`, as the person's own date | Reason, status |
| CREDIT | `Adjustment__c`, posted only | `Account__c` | `Posted_Date__c` | Amount, type, status |
| COMMITMENT | `Commitment__c` | `Account__c` | `Opportunity__r.CloseDate` (signing) | Value, type, status |

**Why it exists:** ST-15. Keeping the six kinds as data in one place keeps `TimelineReader` small, and adding a seventh kind is one entry here.

**How it works:**
1. `all()` builds each kind with small private builders: `tiedBy`, `datedBy` or `datedByTimestamp`, `namedBy`, `onlyWhen`, `showing`.
2. `query` orders each kind by its own date, newest first, then by ID, so every kind comes back already in timeline order.
3. Disputes match on the Billing Dispute record type's ID, so Accord's internal default reviews never appear. Credits match on `Status__c = Posted`.
4. `toEvent` copies the readable facts into a `TimelineEvent`. A fact the reader didn't select stays null.

**Decisions worth knowing:**
- **Credits appear once posted, on their posted date.** A draft or a credit waiting for approval has no posted date. Ordering it by when it was created could put an old draft ahead of a newer posted credit, and the merge would break. Work in progress stays in the account's Adjustments list.
- **Dates and timestamps are declared, not detected.** In Apex a `Date` passes `instanceof Datetime`. Converting it would move every date one day earlier for anyone west of Greenwich. The first pipeline run caught exactly that, with due dates a day early. So a kind says which it is, and only disputes, placed by `CreatedDate`, are converted, to the person's own time zone.

**What can go wrong:** If the org had no Billing Dispute record type, the condition would match no case. That leaves no disputes, which is safer than showing every case.

**How it's tested:** Through `CustomerTimelineControllerTest`. Each kind's event is checked against the stored record. The statement's date and due date have to match exactly.
