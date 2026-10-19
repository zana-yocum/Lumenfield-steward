// NFR-05: every component test can also check accessibility, with @sa11y/jest's toBeAccessible.
// The portal's components import @salesforce/community/basePath, which Jest can't resolve alone,
// and the shared stylesheet c/stewardPortalStyles, a CSS-only module the default resolver skips.
const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    "^@salesforce/community/basePath$": "<rootDir>/jest/communityBasePath.js",
    "^c/stewardPortalStyles$":
      "<rootDir>/force-app/main/default/lwc/stewardPortalStyles/stewardPortalStyles.css"
  },
  setupFilesAfterEnv: [
    ...jestConfig.setupFilesAfterEnv,
    "<rootDir>/jest/setupAccessibility.js"
  ]
};
