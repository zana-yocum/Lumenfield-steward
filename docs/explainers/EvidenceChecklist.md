# EvidenceChecklist

**What it does:** Writes the evidence part of a dispute summary: the items the dispute's reason needs, required ones first, against the files attached to the case.

**Why it exists:** ST-09. A specialist needs to see what's missing. The items come from Accord's `Dispute_Evidence_Requirement__mdt` through `DisputeEvidenceCatalog`, the same list the portal shows the customer.

**How it works:**
1. `forDispute` lists the required and optional items for the reason, then the files.
2. Files aren't tagged with the item they're for. So when nothing is attached, every required item is missing, and the checklist says so. When files are attached, it says which items they cover isn't recorded and leaves that to the specialist. The template is told never to decide from a file's name.
3. `fileName` adds the extension unless the title already ends with it (`receipt.pdf`, not `receipt.pdf.pdf`), and calls a file with no title "(untitled)".

**What can go wrong:** A reason with no evidence records reads "none listed." If the files can't be read, the checklist doesn't claim anything is missing.

**How it's tested:** Through `DisputeSummaryPromptTest`: the required items for Promised Credit Not Applied, "Every required item is still missing." with no files, the specialist's line when a file is attached, and file names.
