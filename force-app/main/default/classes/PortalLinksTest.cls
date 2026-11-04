/**
 * ST-05. Proves a statement's portal address, worked out outside the site, is the org's site
 * domain, the portal's path and the statement page with the statement's ID.
 */
@IsTest
private class PortalLinksTest {
  @IsTest
  static void aStatementsPageIsOnThePortal() {
    Id statementId = TestIds.missing(Billing_Statement__c.SObjectType);

    String page = PortalLinks.statementPage(statementId);

    String orgDomain = URL.getOrgDomainUrl().toExternalForm();
    Assert.isTrue(page.startsWith('https://'), page);
    Assert.isTrue(
      page.endsWith('/portal/statement?recordId=' + statementId),
      'The statement page: ' + page
    );
    if (orgDomain.contains('.my.salesforce.com')) {
      Assert.isTrue(
        page.contains('.my.site.com/'),
        'On the site domain: ' + page
      );
    }
    Assert.isFalse(
      page.contains('.my.salesforce.com'),
      'Never the org\'s own domain'
    );
  }
}
