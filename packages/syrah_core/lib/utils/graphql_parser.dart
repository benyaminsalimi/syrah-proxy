import 'dart:convert';

/// GraphQL operation type
enum GraphQLOperationType {
  query,
  mutation,
  subscription,
}

/// Represents a parsed GraphQL operation
class GraphQLOperation {
  final GraphQLOperationType type;
  final String? name;
  final Map<String, dynamic>? variables;
  final String query;
  final List<String> selections;

  const GraphQLOperation({
    required this.type,
    this.name,
    this.variables,
    required this.query,
    this.selections = const [],
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'name': name,
    'variables': variables,
    'query': query,
    'selections': selections,
  };

  @override
  String toString() {
    final typeStr = type.name;
    final nameStr = name != null ? ' $name' : '';
    return '$typeStr$nameStr';
  }
}

/// Parses GraphQL requests and responses
class GraphQLParser {
  /// Check if a request body contains GraphQL
  static bool isGraphQL(String? body, Map<String, String>? headers) {
    if (body == null || body.isEmpty) return false;

    // Check content type
    final contentType = headers?['content-type'] ?? headers?['Content-Type'] ?? '';
    if (contentType.contains('application/graphql')) return true;

    // Check for GraphQL JSON payload
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        // Standard GraphQL request has 'query' field
        if (json.containsKey('query')) return true;
      } else if (json is List && json.isNotEmpty) {
        // Batched GraphQL requests
        final first = json.first;
        if (first is Map && first.containsKey('query')) return true;
      }
    } catch (_) {
      // Not JSON
    }

    // Check for raw GraphQL query
    final trimmed = body.trim();
    if (trimmed.startsWith('query ') ||
        trimmed.startsWith('mutation ') ||
        trimmed.startsWith('subscription ') ||
        trimmed.startsWith('{')) {
      return true;
    }

    return false;
  }

  /// Parse a GraphQL request body
  static List<GraphQLOperation>? parse(String? body) {
    if (body == null || body.isEmpty) return null;

    try {
      final json = jsonDecode(body);

      // Single operation
      if (json is Map<String, dynamic>) {
        final op = _parseOperation(json);
        return op != null ? [op] : null;
      }

      // Batched operations
      if (json is List) {
        final operations = <GraphQLOperation>[];
        for (final item in json) {
          if (item is Map<String, dynamic>) {
            final op = _parseOperation(item);
            if (op != null) operations.add(op);
          }
        }
        return operations.isNotEmpty ? operations : null;
      }
    } catch (_) {
      // Try parsing as raw GraphQL query
      final op = _parseRawQuery(body);
      return op != null ? [op] : null;
    }

    return null;
  }

  static GraphQLOperation? _parseOperation(Map<String, dynamic> json) {
    final query = json['query'] as String?;
    if (query == null) return null;

    final variables = json['variables'] as Map<String, dynamic>?;
    final operationName = json['operationName'] as String?;

    // Parse the query to extract operation type and selections
    final parsed = _parseQuery(query);

    return GraphQLOperation(
      type: parsed.type,
      name: operationName ?? parsed.name,
      variables: variables,
      query: query,
      selections: parsed.selections,
    );
  }

  static GraphQLOperation? _parseRawQuery(String query) {
    final parsed = _parseQuery(query);
    return GraphQLOperation(
      type: parsed.type,
      name: parsed.name,
      query: query,
      selections: parsed.selections,
    );
  }

  static _ParsedQuery _parseQuery(String query) {
    final trimmed = query.trim();
    var type = GraphQLOperationType.query;
    String? name;
    final selections = <String>[];

    // Match operation type and name
    final operationMatch = RegExp(
      r'^(query|mutation|subscription)\s*(\w+)?',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (operationMatch != null) {
      final typeStr = operationMatch.group(1)?.toLowerCase();
      switch (typeStr) {
        case 'query':
          type = GraphQLOperationType.query;
          break;
        case 'mutation':
          type = GraphQLOperationType.mutation;
          break;
        case 'subscription':
          type = GraphQLOperationType.subscription;
          break;
      }
      name = operationMatch.group(2);
    }

    // Extract top-level selections (field names)
    final selectionsMatch = RegExp(r'\{\s*([^{}]+)\s*[\({]', multiLine: true);
    final matches = selectionsMatch.allMatches(trimmed);

    for (final match in matches) {
      final content = match.group(1);
      if (content != null) {
        // Extract field names
        final fieldMatch = RegExp(r'^\s*(\w+)', multiLine: true);
        final fields = fieldMatch.allMatches(content);
        for (final field in fields) {
          final fieldName = field.group(1);
          if (fieldName != null && !selections.contains(fieldName)) {
            selections.add(fieldName);
          }
        }
      }
    }

    // Also try simple selections at root level
    final simpleMatch = RegExp(r'\{\s*(\w+)');
    final simple = simpleMatch.firstMatch(trimmed);
    if (simple != null) {
      final fieldName = simple.group(1);
      if (fieldName != null && !selections.contains(fieldName)) {
        selections.insert(0, fieldName);
      }
    }

    return _ParsedQuery(type, name, selections);
  }

  /// Extract introspection queries
  static bool isIntrospectionQuery(String? query) {
    if (query == null) return false;
    final lower = query.toLowerCase();
    return lower.contains('__schema') || lower.contains('__type');
  }

  /// Format a GraphQL query for display
  static String formatQuery(String query) {
    // Simple formatting - add newlines and indentation
    var formatted = query;
    var indentLevel = 0;
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;

    for (var i = 0; i < formatted.length; i++) {
      final char = formatted[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      if (inString) {
        buffer.write(char);
        continue;
      }

      switch (char) {
        case '{':
          buffer.write(' {\n');
          indentLevel++;
          buffer.write('  ' * indentLevel);
          break;
        case '}':
          buffer.write('\n');
          indentLevel--;
          buffer.write('  ' * indentLevel);
          buffer.write('}');
          break;
        case ',':
          buffer.write(',\n');
          buffer.write('  ' * indentLevel);
          break;
        case ' ':
        case '\n':
        case '\t':
        case '\r':
          // Skip extra whitespace
          if (buffer.isNotEmpty && !buffer.toString().endsWith('\n') && !buffer.toString().endsWith(' ')) {
            buffer.write(' ');
          }
          break;
        default:
          buffer.write(char);
      }
    }

    return buffer.toString().trim();
  }

  /// Extract variable definitions from a query
  static Map<String, String> extractVariableDefinitions(String query) {
    final variables = <String, String>{};

    // Match variable definitions like ($id: ID!, $name: String)
    final varMatch = RegExp(r'\$(\w+)\s*:\s*([^\),!]+[!]?)');
    final matches = varMatch.allMatches(query);

    for (final match in matches) {
      final name = match.group(1);
      final type = match.group(2);
      if (name != null && type != null) {
        variables[name] = type.trim();
      }
    }

    return variables;
  }
}

class _ParsedQuery {
  final GraphQLOperationType type;
  final String? name;
  final List<String> selections;

  _ParsedQuery(this.type, this.name, this.selections);
}

/// GraphQL response parser
class GraphQLResponseParser {
  /// Parse a GraphQL response
  static GraphQLResponse? parse(String? body) {
    if (body == null || body.isEmpty) return null;

    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;

      final data = json['data'];
      final errors = json['errors'] as List?;
      final extensions = json['extensions'] as Map<String, dynamic>?;

      return GraphQLResponse(
        data: data,
        errors: errors?.map((e) => GraphQLError.fromJson(e)).toList(),
        extensions: extensions,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Represents a GraphQL response
class GraphQLResponse {
  final dynamic data;
  final List<GraphQLError>? errors;
  final Map<String, dynamic>? extensions;

  const GraphQLResponse({
    this.data,
    this.errors,
    this.extensions,
  });

  bool get hasErrors => errors != null && errors!.isNotEmpty;

  bool get hasData => data != null;

  Map<String, dynamic> toJson() => {
    if (data != null) 'data': data,
    if (errors != null) 'errors': errors!.map((e) => e.toJson()).toList(),
    if (extensions != null) 'extensions': extensions,
  };
}

/// Represents a GraphQL error
class GraphQLError {
  final String message;
  final List<GraphQLErrorLocation>? locations;
  final List<dynamic>? path;
  final Map<String, dynamic>? extensions;

  const GraphQLError({
    required this.message,
    this.locations,
    this.path,
    this.extensions,
  });

  factory GraphQLError.fromJson(Map<String, dynamic> json) {
    return GraphQLError(
      message: json['message'] as String? ?? 'Unknown error',
      locations: (json['locations'] as List?)
          ?.map((l) => GraphQLErrorLocation.fromJson(l))
          .toList(),
      path: json['path'] as List?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    if (locations != null) 'locations': locations!.map((l) => l.toJson()).toList(),
    if (path != null) 'path': path,
    if (extensions != null) 'extensions': extensions,
  };
}

/// Represents a location in a GraphQL document
class GraphQLErrorLocation {
  final int line;
  final int column;

  const GraphQLErrorLocation({
    required this.line,
    required this.column,
  });

  factory GraphQLErrorLocation.fromJson(Map<String, dynamic> json) {
    return GraphQLErrorLocation(
      line: json['line'] as int? ?? 0,
      column: json['column'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'line': line,
    'column': column,
  };
}
