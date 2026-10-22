// The portal's text lives in custom labels (docs/conventions.md). Jest can't read labels from the
// org, so each one is mocked with its value from the repo's CustomLabels file. Tests then check the
// words a customer actually reads, and a component that names a label that doesn't exist fails.
const fs = require("fs");
const path = require("path");

const LABELS_FILE = path.join(
  __dirname,
  "..",
  "force-app",
  "main",
  "default",
  "labels",
  "CustomLabels.labels-meta.xml"
);

function decode(text) {
  return text
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

const xml = fs.readFileSync(LABELS_FILE, "utf8");
for (const [, block] of xml.matchAll(/<labels>([\s\S]*?)<\/labels>/g)) {
  const name = /<fullName>([^<]+)<\/fullName>/.exec(block)[1];
  const value = decode(/<value>([\s\S]*?)<\/value>/.exec(block)[1]);
  jest.doMock(`@salesforce/label/c.${name}`, () => ({ default: value }), {
    virtual: true
  });
}
