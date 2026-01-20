import 'package:test/test.dart';
import 'package:syrah_core/models/http_request.dart';
import 'package:syrah_core/utils/curl_generator.dart';

void main() {
  group('CurlGenerator', () {
    late HttpRequest simpleGetRequest;
    late HttpRequest postRequestWithBody;
    late HttpRequest postRequestWithHeaders;

    setUp(() {
      simpleGetRequest = HttpRequest(
        id: 'test-1',
        method: HttpMethod.get,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      postRequestWithBody = HttpRequest(
        id: 'test-2',
        method: HttpMethod.post,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        headers: {'Content-Type': 'application/json'},
        bodyText: '{"name": "John", "email": "john@example.com"}',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      postRequestWithHeaders = HttpRequest(
        id: 'test-3',
        method: HttpMethod.post,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token123',
          'X-Custom-Header': 'custom-value',
        },
        bodyText: '{"name": "John"}',
        timestamp: DateTime.now(),
        isSecure: true,
      );
    });

    group('generate', () {
      test('generates basic GET curl command', () {
        final curl = CurlGenerator.generate(simpleGetRequest);

        expect(curl, contains('curl'));
        expect(curl, contains("'https://api.example.com/users'"));
        expect(curl, contains('--compressed'));
        expect(curl, contains('--location'));
      });

      test('generates POST curl command with method flag', () {
        final curl = CurlGenerator.generate(postRequestWithBody);

        expect(curl, contains('-X POST'));
        expect(curl, contains("-d '{\"name\": \"John\""));
      });

      test('includes headers in curl command', () {
        final curl = CurlGenerator.generate(postRequestWithHeaders);

        expect(curl, contains("-H 'Content-Type: application/json'"));
        expect(curl, contains("-H 'Authorization: Bearer token123'"));
        expect(curl, contains("-H 'X-Custom-Header: custom-value'"));
      });

      test('adds insecure flag when specified for HTTPS', () {
        final curl = CurlGenerator.generate(simpleGetRequest, insecure: true);

        expect(curl, contains('--insecure'));
      });

      test('does not add insecure flag for HTTP requests', () {
        final httpRequest = HttpRequest(
          id: 'test-http',
          method: HttpMethod.get,
          url: 'http://api.example.com/users',
          scheme: 'http',
          host: 'api.example.com',
          port: 80,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: false,
        );

        final curl = CurlGenerator.generate(httpRequest, insecure: true);
        expect(curl, isNot(contains('--insecure')));
      });

      test('adds verbose flag when specified', () {
        final curl = CurlGenerator.generate(simpleGetRequest, verbose: true);

        expect(curl, contains('--verbose'));
      });

      test('adds silent flag when specified', () {
        final curl = CurlGenerator.generate(simpleGetRequest, silent: true);

        expect(curl, contains('--silent'));
      });

      test('excludes location flag when followRedirects is false', () {
        final curl = CurlGenerator.generate(simpleGetRequest, followRedirects: false);

        expect(curl, isNot(contains('--location')));
      });

      test('adds timeout when specified', () {
        final curl = CurlGenerator.generate(simpleGetRequest, timeout: 30);

        expect(curl, contains('--max-time 30'));
      });

      test('skips host header', () {
        final request = HttpRequest(
          id: 'test-host',
          method: HttpMethod.get,
          url: 'https://api.example.com/users',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          headers: {'Host': 'api.example.com'},
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, isNot(contains("-H 'Host:")));
      });

      test('skips content-length header', () {
        final request = HttpRequest(
          id: 'test-length',
          method: HttpMethod.post,
          url: 'https://api.example.com/users',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          headers: {'Content-Length': '50'},
          bodyText: '{"test": true}',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, isNot(contains("-H 'Content-Length:")));
      });

      test('escapes single quotes in header values', () {
        final request = HttpRequest(
          id: 'test-quote',
          method: HttpMethod.get,
          url: 'https://api.example.com/users',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          headers: {'X-Custom': "value'with'quotes"},
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains("'\"'\"'"));
      });
    });

    group('generateOneLine', () {
      test('generates single line curl command', () {
        final curl = CurlGenerator.generateOneLine(postRequestWithHeaders);

        expect(curl, isNot(contains('\n')));
        expect(curl, contains('curl'));
        expect(curl, contains('-X POST'));
      });

      test('includes only essential headers', () {
        final curl = CurlGenerator.generateOneLine(postRequestWithHeaders);

        expect(curl, contains('Content-Type'));
        expect(curl, contains('Authorization'));
        expect(curl, isNot(contains('X-Custom-Header')));
      });
    });

    group('generatePowerShell', () {
      test('generates PowerShell Invoke-WebRequest command', () {
        final ps = CurlGenerator.generatePowerShell(postRequestWithBody);

        expect(ps, contains('Invoke-WebRequest'));
        expect(ps, contains("-Uri 'https://api.example.com/users'"));
        expect(ps, contains('-Method POST'));
      });

      test('includes headers in PowerShell format', () {
        final ps = CurlGenerator.generatePowerShell(postRequestWithHeaders);

        expect(ps, contains('-Headers @{'));
        expect(ps, contains("'Content-Type'='application/json'"));
      });

      test('includes body in PowerShell command', () {
        final ps = CurlGenerator.generatePowerShell(postRequestWithBody);

        expect(ps, contains('-Body'));
        expect(ps, contains('name'));
      });
    });

    group('generateWget', () {
      test('generates wget command', () {
        final wget = CurlGenerator.generateWget(simpleGetRequest);

        expect(wget, contains('wget'));
        expect(wget, contains('--method=GET'));
        expect(wget, contains("'https://api.example.com/users'"));
      });

      test('includes headers in wget format', () {
        final wget = CurlGenerator.generateWget(postRequestWithHeaders);

        expect(wget, contains("--header='Content-Type: application/json'"));
        expect(wget, contains("--header='Authorization: Bearer token123'"));
      });

      test('includes body in wget command', () {
        final wget = CurlGenerator.generateWget(postRequestWithBody);

        expect(wget, contains("--body-data="));
      });
    });

    group('parse', () {
      test('parses simple GET curl command', () {
        final curl = "curl 'https://api.example.com/users'";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.method, HttpMethod.get);
        expect(request.url, 'https://api.example.com/users');
        expect(request.host, 'api.example.com');
        expect(request.path, '/users');
      });

      test('parses POST curl command', () {
        final curl = "curl -X POST 'https://api.example.com/users'";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.method, HttpMethod.post);
      });

      test('parses curl command with headers', () {
        final curl = """curl -H 'Content-Type: application/json' -H 'Authorization: Bearer token' 'https://api.example.com/users'""";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.headers['Content-Type'], 'application/json');
        expect(request.headers['Authorization'], 'Bearer token');
      });

      test('parses curl command with body', () {
        final curl = """curl -X POST -d '{"name": "John"}' 'https://api.example.com/users'""";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.bodyText, '{"name": "John"}');
      });

      test('parses curl command with line continuations', () {
        final curl = """curl \\
          -X POST \\
          -H 'Content-Type: application/json' \\
          'https://api.example.com/users'""";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.method, HttpMethod.post);
        expect(request.headers['Content-Type'], 'application/json');
      });

      test('handles URL with query parameters', () {
        final curl = "curl 'https://api.example.com/users?limit=10&offset=0'";

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.queryString, 'limit=10&offset=0');
        expect(request.queryParams['limit'], ['10']);
        expect(request.queryParams['offset'], ['0']);
      });

      test('returns null for invalid curl command', () {
        expect(CurlGenerator.parse('not a curl command'), isNull);
      });

      test('handles double-quoted URL', () {
        final curl = 'curl "https://api.example.com/users"';

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.url, 'https://api.example.com/users');
      });

      test('handles URL without quotes', () {
        final curl = 'curl https://api.example.com/users';

        final request = CurlGenerator.parse(curl);

        expect(request, isNotNull);
        expect(request!.url, 'https://api.example.com/users');
      });
    });

    group('HTTP methods', () {
      test('handles PUT method', () {
        final request = HttpRequest(
          id: 'test-put',
          method: HttpMethod.put,
          url: 'https://api.example.com/users/1',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users/1',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains('-X PUT'));
      });

      test('handles PATCH method', () {
        final request = HttpRequest(
          id: 'test-patch',
          method: HttpMethod.patch,
          url: 'https://api.example.com/users/1',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users/1',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains('-X PATCH'));
      });

      test('handles DELETE method', () {
        final request = HttpRequest(
          id: 'test-delete',
          method: HttpMethod.delete,
          url: 'https://api.example.com/users/1',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users/1',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains('-X DELETE'));
      });

      test('handles HEAD method', () {
        final request = HttpRequest(
          id: 'test-head',
          method: HttpMethod.head,
          url: 'https://api.example.com/users',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains('-X HEAD'));
      });

      test('handles OPTIONS method', () {
        final request = HttpRequest(
          id: 'test-options',
          method: HttpMethod.options,
          url: 'https://api.example.com/users',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        final curl = CurlGenerator.generate(request);
        expect(curl, contains('-X OPTIONS'));
      });
    });
  });
}
