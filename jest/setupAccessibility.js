// NFR-05: adds toBeAccessible() to every Jest test. It runs axe-core's WCAG checks on what the
// component rendered. Base components are stubs in Jest, so it checks Steward's own markup.
import { registerSa11yMatcher } from "@sa11y/jest";

registerSa11yMatcher();
