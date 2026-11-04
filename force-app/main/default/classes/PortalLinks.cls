/**
 * ST-05. Addresses of the portal's own pages, for links that leave Salesforce and come back, such
 * as where Stripe sends a customer after paying. On the portal the address comes from the site
 * itself. Elsewhere, such as the agent or a scheduled job, it's worked out from the org's My
 * Domain: with enhanced domains, which Salesforce enforces, a site lives at
 * <my domain>.my.site.com when the org lives at <my domain>.my.salesforce.com.
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
    String siteUrl = Site.getBaseUrl();
    if (String.isNotBlank(siteUrl)) {
      return siteUrl.removeEnd('/');
    }
    return URL.getOrgDomainUrl()
        .toExternalForm()
        .removeEnd('/')
        .replace('.my.salesforce.com', '.my.site.com') +
      '/' +
      PORTAL_PATH;
  }
}
