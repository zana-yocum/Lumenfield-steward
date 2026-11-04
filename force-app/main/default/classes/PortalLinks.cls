/**
 * ST-05. Addresses of the portal's own pages, for links that leave Salesforce and come back, such
 * as where Stripe sends a customer after paying. Always worked out from the org's My Domain: with
 * enhanced domains, which Salesforce enforces, the portal lives at <my domain>.my.site.com/portal
 * when the org lives at <my domain>.my.salesforce.com (checked in the org on 2026-11-04). The same
 * address comes back whether the link is made on the portal, by the agent or by a scheduled job.
 *
 * Site.getBaseUrl isn't used: an LWR site has a Visualforce companion site at its own path
 * (/portalvforcesite here), and a link to that path would leave the customer outside the portal.
 */
public with sharing class PortalLinks {
  /** The portal's path on its domain (digitalExperienceConfigs: urlPathPrefix). */
  @TestVisible
  private static final String PORTAL_PATH = 'portal';
  /** The statement page's path (the Statement__c route). */
  @TestVisible
  private static final String STATEMENT_PATH = 'statement';

  /**
   * The address of one statement's portal page.
   * @param statementId the statement
   * @return the page's address, with the statement's ID as recordId
   */
  public static String statementPage(Id statementId) {
    return baseUrl() + '/' + STATEMENT_PATH + '?recordId=' + statementId;
  }

  /**
   * The portal's address, without a trailing slash.
   * @return the address
   */
  public static String baseUrl() {
    return URL.getOrgDomainUrl()
        .toExternalForm()
        .removeEnd('/')
        .replace('.my.salesforce.com', '.my.site.com') +
      '/' +
      PORTAL_PATH;
  }
}
