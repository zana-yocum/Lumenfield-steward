// NFR-05: every component test can also check accessibility, with @sa11y/jest's toBeAccessible.
// The portal's custom labels are mocked with their values from the repo (jest/setupLabels.js).
// The shared stylesheet c/portalStyles is a CSS-only module, which the default resolver skips.
// lightning/actions has no stub in sfdx-lwc-jest, so jest/mocks provides one (quick actions).
const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    "^c/portalStyles$":
      "<rootDir>/force-app/main/default/lwc/portalStyles/portalStyles.css",
    "^lightning/actions$": "<rootDir>/jest/mocks/lightningActions.js"
  },
  setupFilesAfterEnv: [
    ...jestConfig.setupFilesAfterEnv,
    "<rootDir>/jest/setupAccessibility.js",
    "<rootDir>/jest/setupLabels.js"
  ]
};
