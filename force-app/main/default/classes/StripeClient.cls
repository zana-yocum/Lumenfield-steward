/**
 * ST-05, S-02. Steward's only caller of Stripe. It calls through the Stripe_API named credential,
 * so the secret key never appears in code or the repository, and only users whose permission sets
 * reach the Stripe_Test_Key principal can call at all.
 *
 * Three operations: create a checkout session for one statement, read one session back, and list
 * completed sessions for reconciliation. Every call is recorded with IntegrationLogger. An answer
 * other than 2xx, a timeout or an answer that can't be read throws StripeException, which carries
 * Stripe's error type and code for the log, never the request or the key.
 */
public with sharing class StripeClient {
  /** The provider's name on Integration_Log__c. */
  public static final String PROVIDER = 'Stripe';
  /** Stripe's word for a session whose payment went through. */
  public static final String PAID = 'paid';
  private static final String SESSIONS = 'callout:Stripe_API/v1/checkout/sessions';
  private static final Integer TIMEOUT_MS = 20000;
  /** Stripe keeps a checkout session open at least 30 minutes; Steward keeps it open an hour. */
  private static final Integer SESSION_MINUTES = 60;
  private static final Integer PAGE_LIMIT = 100;

  /** Stripe said no, didn't answer, or answered with something Steward couldn't read. */
  public class StripeException extends Exception {
  }

  /** A checkout session to create, for one statement's balance. */
  public class CheckoutRequest {
    /** The statement being paid. Stripe keeps it as the session's client reference. */
    public Id statementId;
    /** The household. Kept in the session's metadata for support. */
    public Id accountId;
    /** What the customer sees on Stripe's page, such as Statement STMT-00012. */
    public String description;
    /** The amount, in cents. */
    public Long amountCents;
    /** Where Stripe sends the customer after paying. May contain {CHECKOUT_SESSION_ID}. */
    public String successUrl;
    /** Where Stripe sends the customer if they go back without paying. */
    public String cancelUrl;
  }

  /** A checkout session as Stripe describes it. */
  public class CheckoutSession {
    public String id;
    /** The page the customer pays on. Only while the session is open. */
    public String url;
    /** open, complete or expired. */
    public String status;
    /** paid, unpaid or no_payment_required. */
    public String paymentStatus;
    /** The statement ID Steward gave when creating the session. */
    public String clientReferenceId;
    /** The payment's ID, once there is one: the Lease Payment's external reference. */
    public String paymentIntent;
    /** The amount, in cents. */
    public Long amountTotal;
    /** When the session was created, in seconds since 1970. */
    public Long created;
  }

  /** One page of sessions from a list. */
  public class SessionPage {
    public List<CheckoutSession> sessions = new List<CheckoutSession>();
    /** True when Stripe has more after the last one. */
    public Boolean hasMore = false;
  }

  /**
   * Creates a checkout session for one statement's balance. Sends an idempotency key, so a
   * repeated request can't create a second session.
   * @param request the session to create
   * @return the session, with the page the customer pays on
   */
  public CheckoutSession createCheckoutSession(CheckoutRequest request) {
    Map<String, String> form = new Map<String, String>{
      'mode' => 'payment',
      'client_reference_id' => request.statementId,
      'success_url' => request.successUrl,
      'cancel_url' => request.cancelUrl,
      'expires_at' => String.valueOf(
        Datetime.now().addMinutes(SESSION_MINUTES).getTime() / 1000
      ),
      'payment_method_types[0]' => 'card',
      'line_items[0][quantity]' => '1',
      'line_items[0][price_data][currency]' => 'usd',
      'line_items[0][price_data][unit_amount]' => String.valueOf(
        request.amountCents
      ),
      'line_items[0][price_data][product_data][name]' => request.description,
      'metadata[statement_id]' => request.statementId,
      'metadata[account_id]' => request.accountId,
      'payment_intent_data[metadata][statement_id]' => request.statementId
    };
    HttpRequest http = newRequest('POST', SESSIONS);
    http.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    http.setHeader('Idempotency-Key', idempotencyKey(request));
    http.setBody(formBody(form));
    IntegrationLogger.Call call = new IntegrationLogger.Call(
      PROVIDER,
      'Create checkout session'
    );
    call.accountId = request.accountId;
    call.statementId = request.statementId;
    CheckoutSession session = toSession(send(http, call));
    call.providerReference = session.id;
    return session;
  }

  /**
   * Reads one checkout session back, to see whether it was paid.
   * @param sessionId the session's ID
   * @param accountId the household asking, for the log
   * @return the session
   */
  public CheckoutSession getCheckoutSession(String sessionId, Id accountId) {
    HttpRequest http = newRequest(
      'GET',
      SESSIONS + '/' + EncodingUtil.urlEncode(sessionId, 'UTF-8')
    );
    IntegrationLogger.Call call = new IntegrationLogger.Call(
      PROVIDER,
      'Read checkout session'
    );
    call.accountId = accountId;
    call.providerReference = sessionId;
    CheckoutSession session = toSession(send(http, call));
    call.statementId = idOrNull(session.clientReferenceId);
    return session;
  }

  /**
   * Lists completed checkout sessions created since a moment, oldest last, a page at a time.
   * @param createdSince seconds since 1970; sessions created earlier are left out
   * @param startingAfter the last session of the previous page, or null for the first page
   * @return the page
   */
  public SessionPage listCompletedSessions(
    Long createdSince,
    String startingAfter
  ) {
    String url =
      SESSIONS +
      '?status=complete&limit=' +
      PAGE_LIMIT +
      '&' +
      EncodingUtil.urlEncode('created[gte]', 'UTF-8') +
      '=' +
      createdSince;
    if (String.isNotBlank(startingAfter)) {
      url +=
        '&starting_after=' + EncodingUtil.urlEncode(startingAfter, 'UTF-8');
    }
    IntegrationLogger.Call call = new IntegrationLogger.Call(
      PROVIDER,
      'List completed sessions'
    );
    Map<String, Object> body = send(newRequest('GET', url), call);
    SessionPage page = new SessionPage();
    page.hasMore = body.get('has_more') == true;
    List<Object> data = (List<Object>) body.get('data');
    for (Object row : data == null ? new List<Object>() : data) {
      page.sessions.add(toSession((Map<String, Object>) row));
    }
    call.details = page.sessions.size() + ' sessions';
    return page;
  }

  private HttpRequest newRequest(String method, String endpoint) {
    HttpRequest http = new HttpRequest();
    http.setMethod(method);
    http.setEndpoint(endpoint);
    http.setTimeout(TIMEOUT_MS);
    return http;
  }

  /**
   * Sends a request and records the call, whatever happens.
   * @param http the request
   * @param call the log entry to fill in
   * @return the answer's body, read as JSON
   */
  private Map<String, Object> send(
    HttpRequest http,
    IntegrationLogger.Call call
  ) {
    Long started = System.currentTimeMillis();
    IntegrationLogger.record(call);
    HttpResponse response;
    try {
      response = new Http().send(http);
    } catch (CalloutException noAnswer) {
      call.outcome = IntegrationLogger.FAILED;
      call.durationMs = System.currentTimeMillis() - started;
      call.details = 'No answer: ' + noAnswer.getMessage();
      throw new StripeException('No answer from Stripe.');
    }
    call.durationMs = System.currentTimeMillis() - started;
    call.statusCode = response.getStatusCode();
    Map<String, Object> body = readJson(response.getBody());
    if (call.statusCode < 200 || call.statusCode > 299 || body == null) {
      call.outcome = IntegrationLogger.FAILED;
      call.details = describeError(body);
      throw new StripeException(
        'Stripe answered ' + call.statusCode + ': ' + call.details
      );
    }
    call.outcome = IntegrationLogger.SUCCEEDED;
    return body;
  }

  private static Map<String, Object> readJson(String text) {
    try {
      Object parsed = JSON.deserializeUntyped(text);
      return parsed instanceof Map<String, Object>
        ? (Map<String, Object>) parsed
        : null;
    } catch (Exception unreadable) {
      return null;
    }
  }

  /**
   * Stripe's error, as type, code and message. Stripe's messages name the parameter at fault, never
   * a key or card details.
   * @param body the answer, read as JSON, or null
   * @return one line for the log
   */
  private static String describeError(Map<String, Object> body) {
    if (body == null) {
      return 'An answer that isn\'t JSON.';
    }
    Object error = body.get('error');
    if (!(error instanceof Map<String, Object>)) {
      return 'An answer without the expected fields.';
    }
    Map<String, Object> details = (Map<String, Object>) error;
    List<String> parts = new List<String>();
    for (String key : new List<String>{ 'type', 'code', 'message' }) {
      if (details.get(key) != null) {
        parts.add(String.valueOf(details.get(key)));
      }
    }
    return String.join(parts, ' / ');
  }

  private static CheckoutSession toSession(Map<String, Object> row) {
    CheckoutSession session = new CheckoutSession();
    session.id = (String) row.get('id');
    session.url = (String) row.get('url');
    session.status = (String) row.get('status');
    session.paymentStatus = (String) row.get('payment_status');
    session.clientReferenceId = (String) row.get('client_reference_id');
    Object intent = row.get('payment_intent');
    session.paymentIntent = intent instanceof String
      ? (String) intent
      : (String) ((Map<String, Object>) intent)?.get('id');
    session.amountTotal = toLong(row.get('amount_total'));
    session.created = toLong(row.get('created'));
    return session;
  }

  // JSON numbers arrive as Integer, Long or Decimal, and Apex won't cast one to another as an Object.
  private static Long toLong(Object value) {
    return value == null ? null : Long.valueOf(String.valueOf(value));
  }

  private static Id idOrNull(String value) {
    try {
      return String.isBlank(value) ? null : Id.valueOf(value);
    } catch (StringException notAnId) {
      return null;
    }
  }

  private static String formBody(Map<String, String> form) {
    List<String> pairs = new List<String>();
    for (String key : form.keySet()) {
      String value = form.get(key);
      if (value != null) {
        pairs.add(
          EncodingUtil.urlEncode(key, 'UTF-8') +
            '=' +
            EncodingUtil.urlEncode(value, 'UTF-8')
        );
      }
    }
    return String.join(pairs, '&');
  }

  /**
   * A key that's the same only for the same request: the statement, the amount and a random part
   * made once per request. Stripe answers a repeat of the same key with the first session.
   * @param request the session being created
   * @return the key
   */
  private static String idempotencyKey(CheckoutRequest request) {
    return 'steward-checkout-' +
      request.statementId +
      '-' +
      request.amountCents +
      '-' +
      EncodingUtil.convertToHex(Crypto.generateAesKey(128)).left(16);
  }
}
