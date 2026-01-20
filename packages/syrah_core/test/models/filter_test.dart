import 'package:test/test.dart';
import 'package:syrah_core/models/filter.dart';
import 'package:syrah_core/models/network_flow.dart';
import 'package:syrah_core/models/http_request.dart';
import 'package:syrah_core/models/http_response.dart';

void main() {
  group('Filter', () {
    late NetworkFlow testFlow;
    late NetworkFlow errorFlow;
    late NetworkFlow taggedFlow;

    setUp(() {
      final request = HttpRequest(
        id: 'req-1',
        method: HttpMethod.get,
        url: 'https://api.example.com/users?page=1',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        queryString: 'page=1',
        headers: {
          'Authorization': 'Bearer token123',
          'Content-Type': 'application/json',
        },
        bodyText: '{"filter": "active"}',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      final response = HttpResponse(
        statusCode: 200,
        statusMessage: 'OK',
        headers: {'Content-Type': 'application/json'},
        bodyText: '{"users": [{"id": 1}]}',
        timestamp: DateTime.now(),
      );

      testFlow = NetworkFlow(
        id: 'flow-1',
        sessionId: 'session-1',
        request: request,
        response: response,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        tags: ['api', 'users'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final errorRequest = HttpRequest(
        id: 'req-2',
        method: HttpMethod.post,
        url: 'https://api.example.com/error',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/error',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      final errorResponse = HttpResponse(
        statusCode: 500,
        statusMessage: 'Internal Server Error',
        headers: {'Content-Type': 'text/html'},
        bodyText: '<html>Error</html>',
        timestamp: DateTime.now(),
      );

      errorFlow = NetworkFlow(
        id: 'flow-2',
        sessionId: 'session-1',
        request: errorRequest,
        response: errorResponse,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      taggedFlow = NetworkFlow(
        id: 'flow-3',
        sessionId: 'session-1',
        request: request,
        response: response,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        tags: ['important', 'debug'],
        notes: 'This is a test note',
        isMarked: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    group('SimpleFilter', () {
      group('equals operator', () {
        test('matches when values are equal', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'GET',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('matches case-insensitively', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'get',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when values differ', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'POST',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('notEquals operator', () {
        test('matches when values differ', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.notEquals,
            value: 'POST',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when values are equal', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.notEquals,
            value: 'GET',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('contains operator', () {
        test('matches when value contains substring', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.contains,
            value: 'example.com',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('matches case-insensitively', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.contains,
            value: 'EXAMPLE.COM',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when substring not found', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.contains,
            value: 'notfound',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('notContains operator', () {
        test('matches when value does not contain substring', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.notContains,
            value: 'notfound',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when substring found', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.notContains,
            value: 'example.com',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('startsWith operator', () {
        test('matches when value starts with prefix', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.startsWith,
            value: 'https://api',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when value does not start with prefix', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.startsWith,
            value: 'http://',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('endsWith operator', () {
        test('matches when value ends with suffix', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.path,
            operator: FilterOperator.endsWith,
            value: '/users',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when value does not end with suffix', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.path,
            operator: FilterOperator.endsWith,
            value: '/posts',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('regex operator', () {
        test('matches when regex pattern matches', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.regex,
            value: r'api\.example\.com/\w+',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when regex pattern does not match', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.regex,
            value: r'^http:',
          );

          expect(filter.matches(testFlow), isFalse);
        });

        test('handles invalid regex gracefully', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.url,
            operator: FilterOperator.regex,
            value: '[invalid regex',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('numeric operators', () {
        test('greaterThan matches when value is greater', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.statusCode,
            operator: FilterOperator.greaterThan,
            value: '199',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('greaterThan does not match when value is less', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.statusCode,
            operator: FilterOperator.greaterThan,
            value: '200',
          );

          expect(filter.matches(testFlow), isFalse);
        });

        test('lessThan matches when value is less', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.statusCode,
            operator: FilterOperator.lessThan,
            value: '201',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('greaterOrEqual matches when value is equal', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.statusCode,
            operator: FilterOperator.greaterOrEqual,
            value: '200',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('lessOrEqual matches when value is equal', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.statusCode,
            operator: FilterOperator.lessOrEqual,
            value: '200',
          );

          expect(filter.matches(testFlow), isTrue);
        });
      });

      group('exists operator', () {
        test('matches when field has value', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.requestBody,
            operator: FilterOperator.exists,
            value: '',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when field is empty', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.requestBody,
            operator: FilterOperator.exists,
            value: '',
          );

          final flowWithoutBody = NetworkFlow(
            id: 'flow-no-body',
            sessionId: 'session-1',
            request: HttpRequest(
              id: 'req-no-body',
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

          expect(filter.matches(flowWithoutBody), isFalse);
        });
      });

      group('notExists operator', () {
        test('matches when field has no value', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.requestBody,
            operator: FilterOperator.notExists,
            value: '',
          );

          final flowWithoutBody = NetworkFlow(
            id: 'flow-no-body',
            sessionId: 'session-1',
            request: HttpRequest(
              id: 'req-no-body',
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

          expect(filter.matches(flowWithoutBody), isTrue);
        });
      });

      group('inList operator', () {
        test('matches when value is in list', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.inList,
            value: 'GET, POST, PUT',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when value is not in list', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.inList,
            value: 'POST, PUT, DELETE',
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('notInList operator', () {
        test('matches when value is not in list', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.notInList,
            value: 'POST, PUT, DELETE',
          );

          expect(filter.matches(testFlow), isTrue);
        });
      });

      group('header filters', () {
        test('matches request header', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.requestHeader,
            operator: FilterOperator.contains,
            value: 'Bearer',
            headerName: 'Authorization',
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('matches response header', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.responseHeader,
            operator: FilterOperator.contains,
            value: 'json',
            headerName: 'Content-Type',
          );

          expect(filter.matches(testFlow), isTrue);
        });
      });

      group('disabled filter', () {
        test('always matches when disabled', () {
          final filter = Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'POST',
            isEnabled: false,
          );

          expect(filter.matches(testFlow), isTrue);
        });
      });
    });

    group('CombinedFilter', () {
      group('AND combinator', () {
        test('matches when all filters match', () {
          final filter = Filter.combined(
            id: 'test',
            combinator: FilterCombinator.and,
            filters: [
              Filter.simple(
                id: 'f1',
                field: FilterField.method,
                operator: FilterOperator.equals,
                value: 'GET',
              ),
              Filter.simple(
                id: 'f2',
                field: FilterField.statusCode,
                operator: FilterOperator.equals,
                value: '200',
              ),
            ],
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when any filter fails', () {
          final filter = Filter.combined(
            id: 'test',
            combinator: FilterCombinator.and,
            filters: [
              Filter.simple(
                id: 'f1',
                field: FilterField.method,
                operator: FilterOperator.equals,
                value: 'GET',
              ),
              Filter.simple(
                id: 'f2',
                field: FilterField.statusCode,
                operator: FilterOperator.equals,
                value: '404',
              ),
            ],
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      group('OR combinator', () {
        test('matches when any filter matches', () {
          final filter = Filter.combined(
            id: 'test',
            combinator: FilterCombinator.or,
            filters: [
              Filter.simple(
                id: 'f1',
                field: FilterField.method,
                operator: FilterOperator.equals,
                value: 'POST',
              ),
              Filter.simple(
                id: 'f2',
                field: FilterField.statusCode,
                operator: FilterOperator.equals,
                value: '200',
              ),
            ],
          );

          expect(filter.matches(testFlow), isTrue);
        });

        test('does not match when no filter matches', () {
          final filter = Filter.combined(
            id: 'test',
            combinator: FilterCombinator.or,
            filters: [
              Filter.simple(
                id: 'f1',
                field: FilterField.method,
                operator: FilterOperator.equals,
                value: 'POST',
              ),
              Filter.simple(
                id: 'f2',
                field: FilterField.statusCode,
                operator: FilterOperator.equals,
                value: '404',
              ),
            ],
          );

          expect(filter.matches(testFlow), isFalse);
        });
      });

      test('matches with empty filters list', () {
        final filter = Filter.combined(
          id: 'test',
          combinator: FilterCombinator.and,
          filters: [],
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('disabled combined filter always matches', () {
        final filter = Filter.combined(
          id: 'test',
          combinator: FilterCombinator.and,
          filters: [
            Filter.simple(
              id: 'f1',
              field: FilterField.method,
              operator: FilterOperator.equals,
              value: 'POST',
            ),
          ],
          isEnabled: false,
        );

        expect(filter.matches(testFlow), isTrue);
      });
    });

    group('QuickSearchFilter', () {
      test('matches URL', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'example.com',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('matches method', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'GET',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('matches status code', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: '200',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('matches tags', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'api',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('matches notes', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'test note',
        );

        expect(filter.matches(taggedFlow), isTrue);
      });

      test('matches request body', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'active',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('matches response body', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'users',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('returns true for empty search', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: '',
        );

        expect(filter.matches(testFlow), isTrue);
      });

      test('returns false for non-matching search', () {
        final filter = Filter.quickSearch(
          id: 'test',
          searchText: 'nonexistent',
        );

        expect(filter.matches(testFlow), isFalse);
      });
    });
  });

  group('FilterState', () {
    late NetworkFlow testFlow;
    late NetworkFlow errorFlow;

    setUp(() {
      final request = HttpRequest(
        id: 'req-1',
        method: HttpMethod.get,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      final response = HttpResponse(
        statusCode: 200,
        statusMessage: 'OK',
        headers: {'Content-Type': 'application/json'},
        timestamp: DateTime.now(),
      );

      testFlow = NetworkFlow(
        id: 'flow-1',
        sessionId: 'session-1',
        request: request,
        response: response,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final errorRequest = HttpRequest(
        id: 'req-2',
        method: HttpMethod.get,
        url: 'https://api.example.com/error',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/error',
        timestamp: DateTime.now(),
        isSecure: true,
      );

      final errorResponse = HttpResponse(
        statusCode: 500,
        statusMessage: 'Internal Server Error',
        timestamp: DateTime.now(),
      );

      errorFlow = NetworkFlow(
        id: 'flow-2',
        sessionId: 'session-1',
        request: errorRequest,
        response: errorResponse,
        state: FlowState.completed,
        protocol: ProtocolType.https,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    test('hasActiveFilter returns false when no filters set', () {
      const state = FilterState();
      expect(state.hasActiveFilter, isFalse);
    });

    test('hasActiveFilter returns true with search text', () {
      const state = FilterState(searchText: 'test');
      expect(state.hasActiveFilter, isTrue);
    });

    test('hasActiveFilter returns true with filters', () {
      final state = FilterState(
        filters: [
          Filter.simple(
            id: 'test',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'GET',
          ),
        ],
      );
      expect(state.hasActiveFilter, isTrue);
    });

    test('matches filters search text', () {
      const state = FilterState(searchText: 'users');
      expect(state.matches(testFlow), isTrue);
    });

    test('matches applies all filters', () {
      final state = FilterState(
        filters: [
          Filter.simple(
            id: 'f1',
            field: FilterField.method,
            operator: FilterOperator.equals,
            value: 'GET',
          ),
        ],
      );
      expect(state.matches(testFlow), isTrue);
    });

    test('matches respects showMarkedOnly', () {
      const state = FilterState(showMarkedOnly: true);
      expect(state.matches(testFlow), isFalse);

      final markedFlow = testFlow.copyWith(isMarked: true);
      expect(state.matches(markedFlow), isTrue);
    });

    test('matches respects showErrorsOnly', () {
      const state = FilterState(showErrorsOnly: true);
      expect(state.matches(testFlow), isFalse);
      expect(state.matches(errorFlow), isTrue);
    });

    test('matches respects hiddenPatterns', () {
      const state = FilterState(hiddenPatterns: ['api.example.com']);
      expect(state.matches(testFlow), isFalse);
    });

    test('matches respects selectedMethods', () {
      const state = FilterState(selectedMethods: [HttpMethod.post]);
      expect(state.matches(testFlow), isFalse);

      const state2 = FilterState(selectedMethods: [HttpMethod.get]);
      expect(state2.matches(testFlow), isTrue);
    });

    test('matches respects selectedStatusCodes', () {
      const state = FilterState(selectedStatusCodes: [200]);
      expect(state.matches(testFlow), isTrue);
      expect(state.matches(errorFlow), isFalse);
    });

    test('matches respects selectedContentTypes', () {
      const state = FilterState(selectedContentTypes: ['json']);
      expect(state.matches(testFlow), isTrue);

      const state2 = FilterState(selectedContentTypes: ['html']);
      expect(state2.matches(testFlow), isFalse);
    });

    test('matches respects date range', () {
      final now = DateTime.now();
      final state = FilterState(
        fromDate: now.subtract(const Duration(hours: 1)),
        toDate: now.add(const Duration(hours: 1)),
      );
      expect(state.matches(testFlow), isTrue);

      final pastState = FilterState(
        fromDate: now.add(const Duration(hours: 1)),
      );
      expect(pastState.matches(testFlow), isFalse);
    });
  });

  group('FilterPreset', () {
    test('builtInPresets contains expected presets', () {
      final presets = FilterPreset.builtInPresets;

      expect(presets, isNotEmpty);
      expect(presets.any((p) => p.id == 'errors'), isTrue);
      expect(presets.any((p) => p.id == 'xhr'), isTrue);
      expect(presets.any((p) => p.id == 'images'), isTrue);
      expect(presets.any((p) => p.id == 'slow'), isTrue);
      expect(presets.any((p) => p.id == 'large'), isTrue);

      for (final preset in presets) {
        expect(preset.isBuiltIn, isTrue);
      }
    });

    test('errors preset filters errors', () {
      final preset = FilterPreset.builtInPresets.firstWhere((p) => p.id == 'errors');

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
        response: HttpResponse(
          statusCode: 500,
          statusMessage: 'Error',
          timestamp: DateTime.now(),
        ),
        state: FlowState.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final okFlow = NetworkFlow(
        id: 'flow-ok',
        sessionId: 'session-1',
        request: HttpRequest(
          id: 'req-2',
          method: HttpMethod.get,
          url: 'https://example.com',
          scheme: 'https',
          host: 'example.com',
          port: 443,
          path: '/',
          timestamp: DateTime.now(),
          isSecure: true,
        ),
        response: HttpResponse(
          statusCode: 200,
          statusMessage: 'OK',
          timestamp: DateTime.now(),
        ),
        state: FlowState.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(preset.filter.matches(errorFlow), isTrue);
      expect(preset.filter.matches(okFlow), isFalse);
    });
  });
}
