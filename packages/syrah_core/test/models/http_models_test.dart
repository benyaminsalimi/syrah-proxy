import 'package:test/test.dart';
import 'package:syrah_core/models/http_request.dart';
import 'package:syrah_core/models/http_response.dart';
import 'package:syrah_core/models/network_flow.dart';

void main() {
  group('HttpRequest', () {
    late HttpRequest request;

    setUp(() {
      request = HttpRequest(
        id: 'test-request',
        method: HttpMethod.post,
        url: 'https://api.example.com:8443/users/create?foo=bar&baz=qux',
        scheme: 'https',
        host: 'api.example.com',
        port: 8443,
        path: '/users/create',
        queryString: 'foo=bar&baz=qux',
        queryParams: {
          'foo': ['bar'],
          'baz': ['qux'],
        },
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token123',
          'X-Custom-Header': 'custom-value',
          'Upgrade': 'websocket',
        },
        bodyText: '{"name": "John Doe"}',
        cookies: {'session': 'abc123'},
        contentType: ContentType.json,
        contentLength: 20,
        httpVersion: HttpVersion.http2,
        timestamp: DateTime.now(),
        isSecure: true,
        graphqlOperationName: 'CreateUser',
        graphqlOperationType: 'mutation',
      );
    });

    group('getHeader', () {
      test('returns header value case-insensitively', () {
        expect(request.getHeader('content-type'), 'application/json');
        expect(request.getHeader('Content-Type'), 'application/json');
        expect(request.getHeader('CONTENT-TYPE'), 'application/json');
      });

      test('returns null for non-existent header', () {
        expect(request.getHeader('Non-Existent'), isNull);
      });
    });

    group('convenience getters', () {
      test('contentTypeHeader returns content type', () {
        expect(request.contentTypeHeader, 'application/json');
      });

      test('authorization returns auth header', () {
        expect(request.authorization, 'Bearer token123');
      });
    });

    group('isWebSocketUpgrade', () {
      test('returns true when Upgrade header is websocket', () {
        expect(request.isWebSocketUpgrade, isTrue);
      });

      test('returns false when no Upgrade header', () {
        final nonWsRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        expect(nonWsRequest.isWebSocketUpgrade, isFalse);
      });
    });

    group('isGraphQL', () {
      test('returns true when graphqlOperationName is set', () {
        expect(request.isGraphQL, isTrue);
      });

      test('returns true when contentType is graphql', () {
        final gqlRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.post,
          url: 'https://example.com/graphql',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/graphql',
          contentType: ContentType.graphql,
          timestamp: DateTime.now(),
          isSecure: true,
        );

        expect(gqlRequest.isGraphQL, isTrue);
      });

      test('returns false for regular request', () {
        final regularRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        expect(regularRequest.isGraphQL, isFalse);
      });
    });

    group('displayUrl', () {
      test('returns path with ellipsis when query string present', () {
        expect(request.displayUrl, '/users/create?...');
      });

      test('returns path without ellipsis when no query string', () {
        final simpleRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.get,
          url: 'https://example.com/users',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        expect(simpleRequest.displayUrl, '/users');
      });
    });

    group('authority', () {
      test('returns host:port for non-standard port', () {
        expect(request.authority, 'api.example.com:8443');
      });

      test('returns just host for standard HTTPS port', () {
        final standardRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.get,
          url: 'https://example.com/users',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        expect(standardRequest.authority, 'example.com');
      });

      test('returns just host for standard HTTP port', () {
        final httpRequest = HttpRequest(
          id: 'test',
          method: HttpMethod.get,
          url: 'http://example.com/users',
          scheme: 'http',
          host: 'example.com',
          port: 80,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: false,
        );

        expect(httpRequest.authority, 'example.com');
      });
    });
  });

  group('HttpMethodExtension', () {
    test('name returns uppercase method name', () {
      expect(HttpMethod.get.name, 'GET');
      expect(HttpMethod.post.name, 'POST');
      expect(HttpMethod.put.name, 'PUT');
      expect(HttpMethod.patch.name, 'PATCH');
      expect(HttpMethod.delete.name, 'DELETE');
      expect(HttpMethod.head.name, 'HEAD');
      expect(HttpMethod.options.name, 'OPTIONS');
      expect(HttpMethod.trace.name, 'TRACE');
      expect(HttpMethod.connect.name, 'CONNECT');
    });

    test('fromString parses method names', () {
      expect(HttpMethodExtension.fromString('GET'), HttpMethod.get);
      expect(HttpMethodExtension.fromString('get'), HttpMethod.get);
      expect(HttpMethodExtension.fromString('POST'), HttpMethod.post);
      expect(HttpMethodExtension.fromString('PUT'), HttpMethod.put);
      expect(HttpMethodExtension.fromString('PATCH'), HttpMethod.patch);
      expect(HttpMethodExtension.fromString('DELETE'), HttpMethod.delete);
      expect(HttpMethodExtension.fromString('HEAD'), HttpMethod.head);
      expect(HttpMethodExtension.fromString('OPTIONS'), HttpMethod.options);
      expect(HttpMethodExtension.fromString('TRACE'), HttpMethod.trace);
      expect(HttpMethodExtension.fromString('CONNECT'), HttpMethod.connect);
    });

    test('fromString returns GET for unknown method', () {
      expect(HttpMethodExtension.fromString('UNKNOWN'), HttpMethod.get);
    });
  });

  group('HttpResponse', () {
    late HttpResponse successResponse;
    late HttpResponse errorResponse;
    late HttpResponse redirectResponse;

    setUp(() {
      successResponse = HttpResponse(
        statusCode: 200,
        statusMessage: 'OK',
        httpVersion: HttpVersion.http2,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
          'ETag': '"abc123"',
        },
        bodyText: '{"success": true}',
        contentType: ContentType.json,
        contentLength: 17,
        wasCompressed: true,
        compressionEncoding: 'gzip',
        timestamp: DateTime.now(),
      );

      errorResponse = HttpResponse(
        statusCode: 500,
        statusMessage: 'Internal Server Error',
        headers: {'Content-Type': 'text/html'},
        bodyText: '<html>Error</html>',
        timestamp: DateTime.now(),
      );

      redirectResponse = HttpResponse(
        statusCode: 301,
        statusMessage: 'Moved Permanently',
        headers: {'Location': 'https://new.example.com'},
        timestamp: DateTime.now(),
      );
    });

    group('getHeader', () {
      test('returns header value case-insensitively', () {
        expect(successResponse.getHeader('content-type'), 'application/json');
        expect(successResponse.getHeader('Content-Type'), 'application/json');
      });

      test('returns null for non-existent header', () {
        expect(successResponse.getHeader('Non-Existent'), isNull);
      });
    });

    group('statusCategory', () {
      test('returns informational for 1xx', () {
        final response = HttpResponse(
          statusCode: 100,
          statusMessage: 'Continue',
          timestamp: DateTime.now(),
        );
        expect(response.statusCategory, StatusCategory.informational);
      });

      test('returns success for 2xx', () {
        expect(successResponse.statusCategory, StatusCategory.success);
      });

      test('returns redirection for 3xx', () {
        expect(redirectResponse.statusCategory, StatusCategory.redirection);
      });

      test('returns clientError for 4xx', () {
        final response = HttpResponse(
          statusCode: 404,
          statusMessage: 'Not Found',
          timestamp: DateTime.now(),
        );
        expect(response.statusCategory, StatusCategory.clientError);
      });

      test('returns serverError for 5xx', () {
        expect(errorResponse.statusCategory, StatusCategory.serverError);
      });

      test('returns unknown for invalid codes', () {
        final response = HttpResponse(
          statusCode: 999,
          statusMessage: 'Unknown',
          timestamp: DateTime.now(),
        );
        expect(response.statusCategory, StatusCategory.unknown);
      });
    });

    group('isSuccess', () {
      test('returns true for 2xx response', () {
        expect(successResponse.isSuccess, isTrue);
      });

      test('returns false for non-2xx response', () {
        expect(errorResponse.isSuccess, isFalse);
        expect(redirectResponse.isSuccess, isFalse);
      });
    });

    group('isError', () {
      test('returns true for 4xx and 5xx response', () {
        expect(errorResponse.isError, isTrue);

        final clientError = HttpResponse(
          statusCode: 404,
          statusMessage: 'Not Found',
          timestamp: DateTime.now(),
        );
        expect(clientError.isError, isTrue);
      });

      test('returns false for success response', () {
        expect(successResponse.isError, isFalse);
      });
    });

    group('isRedirect', () {
      test('returns true for 3xx response', () {
        expect(redirectResponse.isRedirect, isTrue);
      });

      test('returns false for non-3xx response', () {
        expect(successResponse.isRedirect, isFalse);
      });
    });

    group('convenience getters', () {
      test('contentTypeHeader returns content type', () {
        expect(successResponse.contentTypeHeader, 'application/json');
      });

      test('location returns location header', () {
        expect(redirectResponse.location, 'https://new.example.com');
      });

      test('cacheControl returns cache-control header', () {
        expect(successResponse.cacheControl, 'no-cache');
      });

      test('etag returns ETag header', () {
        expect(successResponse.etag, '"abc123"');
      });

      test('displayStatus formats status code and message', () {
        expect(successResponse.displayStatus, '200 OK');
        expect(errorResponse.displayStatus, '500 Internal Server Error');
      });
    });
  });

  group('ResponseTiming', () {
    test('formattedTotalTime returns milliseconds for short durations', () {
      const timing = ResponseTiming(
        totalTime: Duration(milliseconds: 500),
      );
      expect(timing.formattedTotalTime, '500ms');
    });

    test('formattedTotalTime returns seconds for medium durations', () {
      const timing = ResponseTiming(
        totalTime: Duration(milliseconds: 2500),
      );
      expect(timing.formattedTotalTime, '2.50s');
    });

    test('formattedTotalTime returns minutes for long durations', () {
      const timing = ResponseTiming(
        totalTime: Duration(minutes: 2, seconds: 30),
      );
      expect(timing.formattedTotalTime, '2m 30s');
    });
  });

  group('SetCookie', () {
    group('parse', () {
      test('parses simple cookie', () {
        final cookie = SetCookie.parse('session=abc123');

        expect(cookie.name, 'session');
        expect(cookie.value, 'abc123');
      });

      test('parses cookie with domain', () {
        final cookie = SetCookie.parse('session=abc123; Domain=example.com');

        expect(cookie.domain, 'example.com');
      });

      test('parses cookie with path', () {
        final cookie = SetCookie.parse('session=abc123; Path=/api');

        expect(cookie.path, '/api');
      });

      test('parses cookie with max-age', () {
        final cookie = SetCookie.parse('session=abc123; Max-Age=3600');

        expect(cookie.maxAge, 3600);
      });

      test('parses cookie with secure flag', () {
        final cookie = SetCookie.parse('session=abc123; Secure');

        expect(cookie.secure, isTrue);
      });

      test('parses cookie with httpOnly flag', () {
        final cookie = SetCookie.parse('session=abc123; HttpOnly');

        expect(cookie.httpOnly, isTrue);
      });

      test('parses cookie with SameSite', () {
        final cookie = SetCookie.parse('session=abc123; SameSite=Strict');

        expect(cookie.sameSite, 'Strict');
      });

      test('parses full cookie string', () {
        final cookie = SetCookie.parse(
          'session=abc123; Domain=example.com; Path=/; Max-Age=3600; Secure; HttpOnly; SameSite=Lax',
        );

        expect(cookie.name, 'session');
        expect(cookie.value, 'abc123');
        expect(cookie.domain, 'example.com');
        expect(cookie.path, '/');
        expect(cookie.maxAge, 3600);
        expect(cookie.secure, isTrue);
        expect(cookie.httpOnly, isTrue);
        expect(cookie.sameSite, 'Lax');
      });

      test('handles cookie value with equals sign', () {
        final cookie = SetCookie.parse('token=abc=123=def');

        expect(cookie.name, 'token');
        expect(cookie.value, 'abc=123=def');
      });

      test('throws for empty cookie string', () {
        expect(() => SetCookie.parse(''), throwsA(isA<FormatException>()));
      });

      test('throws for invalid cookie format', () {
        expect(() => SetCookie.parse('invalid'), throwsA(isA<FormatException>()));
      });
    });
  });

  group('NetworkFlow', () {
    late NetworkFlow completedFlow;
    late NetworkFlow pendingFlow;
    late NetworkFlow webSocketFlow;

    setUp(() {
      final request = HttpRequest(
        id: 'req-1',
        method: HttpMethod.get,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        contentLength: 100,
        timestamp: DateTime.now().subtract(const Duration(seconds: 1)),
        isSecure: true,
      );

      final response = HttpResponse(
        statusCode: 200,
        statusMessage: 'OK',
        contentLength: 500,
        timestamp: DateTime.now(),
      );

      completedFlow = NetworkFlow(
        id: 'flow-1',
        sessionId: 'session-1',
        request: request,
        response: response,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        tags: ['api'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      pendingFlow = NetworkFlow(
        id: 'flow-2',
        sessionId: 'session-1',
        request: request,
        state: FlowState.pending,
        protocol: ProtocolType.https,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      webSocketFlow = NetworkFlow(
        id: 'flow-3',
        sessionId: 'session-1',
        request: request,
        state: FlowState.completed,
        protocol: ProtocolType.websocketSecure,
        webSocketMessages: [
          WebSocketMessage(
            id: 'msg-1',
            direction: MessageDirection.sent,
            type: WebSocketMessageType.text,
            dataText: 'Hello',
            timestamp: DateTime.now(),
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    group('duration', () {
      test('returns duration when response exists', () {
        expect(completedFlow.duration, isNotNull);
        expect(completedFlow.duration!.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('returns null when no response', () {
        expect(pendingFlow.duration, isNull);
      });
    });

    group('formattedDuration', () {
      test('returns formatted duration when response exists', () {
        expect(completedFlow.formattedDuration, isNot('-'));
      });

      test('returns dash when no response', () {
        expect(pendingFlow.formattedDuration, '-');
      });
    });

    group('totalSize', () {
      test('returns combined request and response size', () {
        expect(completedFlow.totalSize, 600);
      });

      test('returns only request size when no response', () {
        expect(pendingFlow.totalSize, 100);
      });
    });

    group('formattedSize', () {
      test('formats bytes', () {
        final flow = completedFlow.copyWith(
          request: completedFlow.request.copyWith(contentLength: 500),
          response: completedFlow.response!.copyWith(contentLength: 0),
        );
        expect(flow.formattedSize, '500 B');
      });

      test('formats kilobytes', () {
        final flow = completedFlow.copyWith(
          request: completedFlow.request.copyWith(contentLength: 0),
          response: completedFlow.response!.copyWith(contentLength: 2048),
        );
        expect(flow.formattedSize, '2.0 KB');
      });

      test('formats megabytes', () {
        final flow = completedFlow.copyWith(
          request: completedFlow.request.copyWith(contentLength: 0),
          response: completedFlow.response!.copyWith(contentLength: 2 * 1024 * 1024),
        );
        expect(flow.formattedSize, '2.0 MB');
      });
    });

    group('isSecure', () {
      test('returns true for HTTPS', () {
        expect(completedFlow.isSecure, isTrue);
      });

      test('returns true for secure WebSocket', () {
        expect(webSocketFlow.isSecure, isTrue);
      });

      test('returns false for HTTP', () {
        final httpFlow = completedFlow.copyWith(protocol: ProtocolType.http);
        expect(httpFlow.isSecure, isFalse);
      });
    });

    group('isWebSocket', () {
      test('returns true for WebSocket protocol', () {
        expect(webSocketFlow.isWebSocket, isTrue);
      });

      test('returns false for HTTP protocol', () {
        expect(completedFlow.isWebSocket, isFalse);
      });
    });

    group('isInProgress', () {
      test('returns true for pending flows', () {
        expect(pendingFlow.isInProgress, isTrue);
      });

      test('returns true for waiting flows', () {
        final waitingFlow = pendingFlow.copyWith(state: FlowState.waiting);
        expect(waitingFlow.isInProgress, isTrue);
      });

      test('returns true for receiving flows', () {
        final receivingFlow = pendingFlow.copyWith(state: FlowState.receiving);
        expect(receivingFlow.isInProgress, isTrue);
      });

      test('returns false for completed flows', () {
        expect(completedFlow.isInProgress, isFalse);
      });
    });

    group('displayStatus', () {
      test('returns status code when response exists', () {
        expect(completedFlow.displayStatus, '200');
      });

      test('returns Pending for pending flows', () {
        expect(pendingFlow.displayStatus, 'Pending');
      });

      test('returns Waiting for waiting flows', () {
        final flow = pendingFlow.copyWith(state: FlowState.waiting);
        expect(flow.displayStatus, 'Waiting');
      });

      test('returns Error for failed flows', () {
        final flow = pendingFlow.copyWith(state: FlowState.failed);
        expect(flow.displayStatus, 'Error');
      });
    });

    group('groupHost', () {
      test('returns request host', () {
        expect(completedFlow.groupHost, 'api.example.com');
      });
    });

    group('groupPath', () {
      test('returns first path segment', () {
        expect(completedFlow.groupPath, '/users');
      });

      test('returns root for empty path', () {
        final flow = completedFlow.copyWith(
          request: completedFlow.request.copyWith(path: '/'),
        );
        expect(flow.groupPath, '/');
      });
    });

    group('withResponse', () {
      test('creates copy with response and completed state', () {
        final response = HttpResponse(
          statusCode: 201,
          statusMessage: 'Created',
          timestamp: DateTime.now(),
        );

        final updated = pendingFlow.withResponse(response);

        expect(updated.response, isNotNull);
        expect(updated.response!.statusCode, 201);
        expect(updated.state, FlowState.completed);
      });
    });

    group('withError', () {
      test('creates copy with error and failed state', () {
        final updated = pendingFlow.withError('Connection timeout');

        expect(updated.error, 'Connection timeout');
        expect(updated.state, FlowState.failed);
      });
    });

    group('withWebSocketMessage', () {
      test('adds message to list', () {
        final message = WebSocketMessage(
          id: 'msg-new',
          direction: MessageDirection.received,
          type: WebSocketMessageType.text,
          dataText: 'World',
          timestamp: DateTime.now(),
        );

        final updated = webSocketFlow.withWebSocketMessage(message);

        expect(updated.webSocketMessages.length, 2);
        expect(updated.webSocketMessages.last.dataText, 'World');
      });
    });
  });

  group('WebSocketMessage', () {
    test('displayData returns text for text messages', () {
      final message = WebSocketMessage(
        id: 'msg-1',
        direction: MessageDirection.sent,
        type: WebSocketMessageType.text,
        dataText: 'Hello World',
        timestamp: DateTime.now(),
      );

      expect(message.displayData, 'Hello World');
    });

    test('displayData returns binary description for binary messages', () {
      final message = WebSocketMessage(
        id: 'msg-1',
        direction: MessageDirection.sent,
        type: WebSocketMessageType.binary,
        dataBytes: [1, 2, 3, 4, 5],
        timestamp: DateTime.now(),
      );

      expect(message.displayData, '[Binary: 5 bytes]');
    });

    test('displayData returns Empty for empty messages', () {
      final message = WebSocketMessage(
        id: 'msg-1',
        direction: MessageDirection.sent,
        type: WebSocketMessageType.text,
        timestamp: DateTime.now(),
      );

      expect(message.displayData, '[Empty]');
    });
  });

  group('FlowGroup', () {
    test('totalCount returns count including subgroups', () {
      final flow1 = NetworkFlow(
        id: 'flow-1',
        sessionId: 'session-1',
        request: HttpRequest(
          id: 'req-1',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final group = FlowGroup(
        key: 'example.com',
        displayName: 'example.com',
        flows: [flow1],
        subgroups: [
          FlowGroup(
            key: '/api',
            displayName: '/api',
            flows: [flow1, flow1],
          ),
        ],
      );

      expect(group.totalCount, 3);
    });

    test('hasErrors returns true when any flow has error', () {
      final errorFlow = NetworkFlow(
        id: 'flow-error',
        sessionId: 'session-1',
        request: HttpRequest(
          id: 'req-1',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        ),
        state: FlowState.failed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final group = FlowGroup(
        key: 'example.com',
        displayName: 'example.com',
        flows: [errorFlow],
      );

      expect(group.hasErrors, isTrue);
    });

    test('hasErrors returns true when subgroup has error', () {
      final errorFlow = NetworkFlow(
        id: 'flow-error',
        sessionId: 'session-1',
        request: HttpRequest(
          id: 'req-1',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        ),
        state: FlowState.failed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final group = FlowGroup(
        key: 'example.com',
        displayName: 'example.com',
        flows: [],
        subgroups: [
          FlowGroup(
            key: '/api',
            displayName: '/api',
            flows: [errorFlow],
          ),
        ],
      );

      expect(group.hasErrors, isTrue);
    });
  });
}
