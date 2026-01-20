import 'package:test/test.dart';
import 'package:syrah_core/utils/graphql_parser.dart';

void main() {
  group('GraphQLParser', () {
    group('isGraphQL', () {
      test('returns true for application/graphql content type', () {
        expect(
          GraphQLParser.isGraphQL(
            '{}',
            {'content-type': 'application/graphql'},
          ),
          isTrue,
        );
      });

      test('returns true for standard GraphQL JSON payload', () {
        final body = '{"query": "query { users { id } }"}';
        expect(GraphQLParser.isGraphQL(body, null), isTrue);
      });

      test('returns true for raw query starting with query', () {
        expect(
          GraphQLParser.isGraphQL('query { users { id } }', null),
          isTrue,
        );
      });

      test('returns true for raw query starting with mutation', () {
        expect(
          GraphQLParser.isGraphQL('mutation { createUser(name: "test") { id } }', null),
          isTrue,
        );
      });

      test('returns true for raw query starting with subscription', () {
        expect(
          GraphQLParser.isGraphQL('subscription { userCreated { id } }', null),
          isTrue,
        );
      });

      test('returns true for shorthand query starting with {', () {
        expect(
          GraphQLParser.isGraphQL('{ users { id } }', null),
          isTrue,
        );
      });

      test('returns false for null body', () {
        expect(GraphQLParser.isGraphQL(null, null), isFalse);
      });

      test('returns false for empty body', () {
        expect(GraphQLParser.isGraphQL('', null), isFalse);
      });

      test('returns false for regular JSON', () {
        expect(
          GraphQLParser.isGraphQL('{"name": "test"}', null),
          isFalse,
        );
      });
    });

    group('parse', () {
      test('parses single query operation', () {
        final body = '''
        {
          "query": "query GetUsers { users { id name } }",
          "variables": {"limit": 10}
        }
        ''';

        final operations = GraphQLParser.parse(body);
        expect(operations, isNotNull);
        expect(operations!.length, 1);
        expect(operations[0].type, GraphQLOperationType.query);
        expect(operations[0].name, 'GetUsers');
        expect(operations[0].variables, {'limit': 10});
      });

      test('parses mutation operation', () {
        final body = '''
        {
          "query": "mutation CreateUser(\$name: String!) { createUser(name: \$name) { id } }",
          "operationName": "CreateUser",
          "variables": {"name": "John"}
        }
        ''';

        final operations = GraphQLParser.parse(body);
        expect(operations, isNotNull);
        expect(operations!.length, 1);
        expect(operations[0].type, GraphQLOperationType.mutation);
        expect(operations[0].name, 'CreateUser');
        expect(operations[0].variables, {'name': 'John'});
      });

      test('parses subscription operation', () {
        final body = '''
        {
          "query": "subscription OnUserCreated { userCreated { id name } }"
        }
        ''';

        final operations = GraphQLParser.parse(body);
        expect(operations, isNotNull);
        expect(operations!.length, 1);
        expect(operations[0].type, GraphQLOperationType.subscription);
      });

      test('parses batched operations', () {
        final body = '''
        [
          {"query": "query { users { id } }"},
          {"query": "query { posts { id } }"}
        ]
        ''';

        final operations = GraphQLParser.parse(body);
        expect(operations, isNotNull);
        expect(operations!.length, 2);
      });

      test('returns null for null body', () {
        expect(GraphQLParser.parse(null), isNull);
      });

      test('returns null for empty body', () {
        expect(GraphQLParser.parse(''), isNull);
      });

      test('parses shorthand query syntax', () {
        final body = '{"query": "{ users { id name } }"}';

        final operations = GraphQLParser.parse(body);
        expect(operations, isNotNull);
        expect(operations!.length, 1);
        expect(operations[0].type, GraphQLOperationType.query);
        expect(operations[0].selections, contains('users'));
      });
    });

    group('isIntrospectionQuery', () {
      test('returns true for __schema query', () {
        expect(
          GraphQLParser.isIntrospectionQuery('query { __schema { types { name } } }'),
          isTrue,
        );
      });

      test('returns true for __type query', () {
        expect(
          GraphQLParser.isIntrospectionQuery('query { __type(name: "User") { name } }'),
          isTrue,
        );
      });

      test('returns false for regular query', () {
        expect(
          GraphQLParser.isIntrospectionQuery('query { users { id } }'),
          isFalse,
        );
      });

      test('returns false for null query', () {
        expect(GraphQLParser.isIntrospectionQuery(null), isFalse);
      });
    });

    group('formatQuery', () {
      test('formats simple query with proper indentation', () {
        final query = '{ users { id name } }';
        final formatted = GraphQLParser.formatQuery(query);
        expect(formatted, contains('\n'));
        expect(formatted, contains('users'));
      });

      test('handles nested braces', () {
        final query = 'query { users { posts { id } } }';
        final formatted = GraphQLParser.formatQuery(query);
        expect(formatted, contains('users'));
        expect(formatted, contains('posts'));
      });

      test('preserves strings with braces', () {
        final query = 'query { user(filter: "{json}") { id } }';
        final formatted = GraphQLParser.formatQuery(query);
        expect(formatted, contains('"{json}"'));
      });
    });

    group('extractVariableDefinitions', () {
      test('extracts variable definitions', () {
        final query = r'query GetUser($id: ID!, $name: String) { user(id: $id) { name } }';
        final vars = GraphQLParser.extractVariableDefinitions(query);

        expect(vars['id'], 'ID!');
        expect(vars['name'], 'String');
      });

      test('returns empty map for query without variables', () {
        final query = 'query { users { id } }';
        final vars = GraphQLParser.extractVariableDefinitions(query);
        expect(vars, isEmpty);
      });
    });
  });

  group('GraphQLResponseParser', () {
    group('parse', () {
      test('parses successful response', () {
        final body = '''
        {
          "data": {"users": [{"id": "1", "name": "John"}]}
        }
        ''';

        final response = GraphQLResponseParser.parse(body);
        expect(response, isNotNull);
        expect(response!.hasData, isTrue);
        expect(response.hasErrors, isFalse);
        expect(response.data['users'], isNotEmpty);
      });

      test('parses response with errors', () {
        final body = '''
        {
          "errors": [
            {"message": "Not found", "locations": [{"line": 1, "column": 5}]}
          ]
        }
        ''';

        final response = GraphQLResponseParser.parse(body);
        expect(response, isNotNull);
        expect(response!.hasErrors, isTrue);
        expect(response.errors!.length, 1);
        expect(response.errors![0].message, 'Not found');
        expect(response.errors![0].locations!.length, 1);
        expect(response.errors![0].locations![0].line, 1);
      });

      test('parses response with data and errors', () {
        final body = '''
        {
          "data": {"user": null},
          "errors": [{"message": "User not found"}]
        }
        ''';

        final response = GraphQLResponseParser.parse(body);
        expect(response, isNotNull);
        expect(response!.hasData, isTrue);
        expect(response.hasErrors, isTrue);
      });

      test('parses response with extensions', () {
        final body = '''
        {
          "data": {"users": []},
          "extensions": {"tracing": {"duration": 100}}
        }
        ''';

        final response = GraphQLResponseParser.parse(body);
        expect(response, isNotNull);
        expect(response!.extensions, isNotNull);
        expect(response.extensions!['tracing'], isNotNull);
      });

      test('returns null for null body', () {
        expect(GraphQLResponseParser.parse(null), isNull);
      });

      test('returns null for empty body', () {
        expect(GraphQLResponseParser.parse(''), isNull);
      });

      test('returns null for invalid JSON', () {
        expect(GraphQLResponseParser.parse('not json'), isNull);
      });

      test('returns null for non-object JSON', () {
        expect(GraphQLResponseParser.parse('[1, 2, 3]'), isNull);
      });
    });
  });

  group('GraphQLOperation', () {
    test('toJson returns correct structure', () {
      const op = GraphQLOperation(
        type: GraphQLOperationType.query,
        name: 'GetUser',
        variables: {'id': '123'},
        query: 'query GetUser { user { id } }',
        selections: ['user'],
      );

      final json = op.toJson();
      expect(json['type'], 'query');
      expect(json['name'], 'GetUser');
      expect(json['variables'], {'id': '123'});
      expect(json['query'], 'query GetUser { user { id } }');
      expect(json['selections'], ['user']);
    });

    test('toString returns formatted string with name', () {
      const op = GraphQLOperation(
        type: GraphQLOperationType.mutation,
        name: 'CreateUser',
        query: 'mutation CreateUser { createUser { id } }',
      );

      expect(op.toString(), 'mutation CreateUser');
    });

    test('toString returns formatted string without name', () {
      const op = GraphQLOperation(
        type: GraphQLOperationType.query,
        query: '{ users { id } }',
      );

      expect(op.toString(), 'query');
    });
  });

  group('GraphQLError', () {
    test('fromJson parses correctly', () {
      final json = {
        'message': 'Field not found',
        'locations': [{'line': 2, 'column': 3}],
        'path': ['user', 'name'],
        'extensions': {'code': 'NOT_FOUND'},
      };

      final error = GraphQLError.fromJson(json);
      expect(error.message, 'Field not found');
      expect(error.locations!.length, 1);
      expect(error.locations![0].line, 2);
      expect(error.locations![0].column, 3);
      expect(error.path, ['user', 'name']);
      expect(error.extensions!['code'], 'NOT_FOUND');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'message': 'Error'};

      final error = GraphQLError.fromJson(json);
      expect(error.message, 'Error');
      expect(error.locations, isNull);
      expect(error.path, isNull);
      expect(error.extensions, isNull);
    });

    test('fromJson uses default message for missing message', () {
      final json = <String, dynamic>{};

      final error = GraphQLError.fromJson(json);
      expect(error.message, 'Unknown error');
    });

    test('toJson returns correct structure', () {
      const error = GraphQLError(
        message: 'Test error',
        locations: [GraphQLErrorLocation(line: 1, column: 1)],
        path: ['query'],
        extensions: {'code': 'ERR'},
      );

      final json = error.toJson();
      expect(json['message'], 'Test error');
      expect(json['locations'], isNotNull);
      expect(json['path'], ['query']);
      expect(json['extensions'], {'code': 'ERR'});
    });
  });

  group('GraphQLResponse', () {
    test('toJson returns correct structure', () {
      const response = GraphQLResponse(
        data: {'user': {'id': '1'}},
        errors: [GraphQLError(message: 'Warning')],
        extensions: {'timing': 100},
      );

      final json = response.toJson();
      expect(json['data'], {'user': {'id': '1'}});
      expect(json['errors'], isNotNull);
      expect(json['extensions'], {'timing': 100});
    });

    test('toJson excludes null fields', () {
      const response = GraphQLResponse(data: {'test': true});

      final json = response.toJson();
      expect(json.containsKey('data'), isTrue);
      expect(json.containsKey('errors'), isFalse);
      expect(json.containsKey('extensions'), isFalse);
    });
  });
}
