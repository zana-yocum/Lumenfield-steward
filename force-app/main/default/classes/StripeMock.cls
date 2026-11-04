/**
 * ST-05, NFR-03. Stands in for Stripe in tests, so no test ever calls out. Answers by method and
 * path, in the order given; the last answer for a route repeats. Keeps every request, so a test
 * can check what Steward sent. Builds Stripe-shaped bodies for sessions, lists and errors.
 */
@IsTest
public class StripeMock implements HttpCalloutMock {
  /** Every request Steward sent, in order. */
  public final List<HttpRequest> requests = new List<HttpRequest>();
  /** When true, every call fails the way a timeout does. */
  public Boolean timesOut = false;
  private final Map<String, List<HttpResponse>> answers = new Map<String, List<HttpResponse>>();

  /** A checkout session as Stripe describes it: open and unpaid until paidBy. */
  public class Session {
    private final Map<String, Object> fields;

    /**
     * An open, unpaid session.
     * @param id the session's ID, such as cs_test_1
     * @param statementId the client reference Steward gave it
     * @param amountCents the amount, in cents
     */
    public Session(String id, String statementId, Long amountCents) {
      fields = new Map<String, Object>{
        'id' => id,
        'object' => 'checkout.session',
        'url' => 'https://checkout.stripe.com/c/pay/' + id,
        'status' => 'open',
        'payment_status' => 'unpaid',
        'client_reference_id' => statementId,
        'payment_intent' => null,
        'amount_total' => amountCents,
        'created' => Datetime.now().getTime() / 1000
      };
    }

    /**
     * The session, paid: complete, with the payment's ID and no page left to pay on.
     * @param paymentIntent the payment's ID, such as pi_test_1
     * @return this session
     */
    public Session paidBy(String paymentIntent) {
      fields.put('status', 'complete');
      fields.put('payment_status', 'paid');
      fields.put('payment_intent', paymentIntent);
      fields.put('url', null);
      return this;
    }

    /**
     * Its fields, for a list.
     * @return the fields
     */
    public Map<String, Object> fields() {
      return fields;
    }

    /**
     * Its JSON, for an answer.
     * @return the body
     */
    public String json() {
      return JSON.serialize(fields);
    }
  }

  /**
   * Adds an answer for a route.
   * @param route the method and path, such as POST /v1/checkout/sessions
   * @param status the HTTP status
   * @param body the body
   * @return this mock, for chaining
   */
  public StripeMock answer(String route, Integer status, String body) {
    if (!answers.containsKey(route)) {
      answers.put(route, new List<HttpResponse>());
    }
    answers.get(route).add(response(status, body));
    return this;
  }

  /**
   * Answers one request.
   * @param request what Steward sent
   * @return the answer for its route
   */
  public HttpResponse respond(HttpRequest request) {
    requests.add(request);
    if (timesOut) {
      throw new CalloutException('Read timed out');
    }
    String route = request.getMethod() + ' ' + pathOf(request.getEndpoint());
    List<HttpResponse> queued = answers.get(route);
    if (queued == null || queued.isEmpty()) {
      return response(404, error('invalid_request_error', 'resource_missing'));
    }
    return queued.size() > 1 ? queued.remove(0) : queued[0];
  }

  /**
   * The last request Steward sent.
   * @return the request
   */
  public HttpRequest last() {
    return requests.isEmpty() ? null : requests[requests.size() - 1];
  }

  /**
   * The last page of a list of sessions: Stripe has no more after it.
   * @param sessions the sessions
   * @return the JSON body
   */
  public static String lastPage(List<Session> sessions) {
    return JSON.serialize(
      new Map<String, Object>{
        'object' => 'list',
        'data' => fieldsOf(sessions),
        'has_more' => false
      }
    );
  }

  /**
   * A page of a list of sessions with more after it.
   * @param sessions the sessions
   * @return the JSON body
   */
  public static String pageWithMore(List<Session> sessions) {
    return JSON.serialize(
      new Map<String, Object>{
        'object' => 'list',
        'data' => fieldsOf(sessions),
        'has_more' => true
      }
    );
  }

  /**
   * An error as Stripe returns it.
   * @param type Stripe's error type, such as api_error
   * @param code Stripe's error code, or null
   * @return the JSON body
   */
  public static String error(String type, String code) {
    return JSON.serialize(
      new Map<String, Object>{
        'error' => new Map<String, Object>{
          'type' => type,
          'code' => code,
          'message' => 'Mock error for ' + type
        }
      }
    );
  }

  private static List<Map<String, Object>> fieldsOf(List<Session> sessions) {
    List<Map<String, Object>> data = new List<Map<String, Object>>();
    for (Session session : sessions) {
      data.add(session.fields());
    }
    return data;
  }

  private static HttpResponse response(Integer status, String body) {
    HttpResponse response = new HttpResponse();
    response.setStatusCode(status);
    response.setHeader('Content-Type', 'application/json');
    response.setBody(body);
    return response;
  }

  private static String pathOf(String endpoint) {
    return endpoint.removeStart('callout:Stripe_API').substringBefore('?');
  }
}
