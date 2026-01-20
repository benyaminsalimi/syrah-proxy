import 'package:freezed_annotation/freezed_annotation.dart';

part 'http_request.freezed.dart';
part 'http_request.g.dart';

/// HTTP methods supported by the proxy
enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
  head,
  options,
  trace,
  connect,
}

/// Represents the body content type
enum ContentType {
  json,
  xml,
  html,
  text,
  formData,
  binary,
  graphql,
  unknown,
}

/// HTTP version
enum HttpVersion {
  http1_0,
  http1_1,
  http2,
  http3,
}

/// Represents an HTTP request captured by the proxy
@freezed
class HttpRequest with _$HttpRequest {
  const HttpRequest._();

  const factory HttpRequest({
    /// Unique identifier for this request
    required String id,

    /// HTTP method (GET, POST, etc.)
    required HttpMethod method,

    /// Full URL including query parameters
    required String url,

    /// Scheme (http or https)
    required String scheme,

    /// Host name
    required String host,

    /// Port number
    required int port,

    /// URL path
    required String path,

    /// Query string (without leading ?)
    String? queryString,

    /// Parsed query parameters
    @Default({}) Map<String, List<String>> queryParams,

    /// Request headers
    @Default({}) Map<String, String> headers,

    /// Request body as bytes
    List<int>? bodyBytes,

    /// Request body as string (if text-based)
    String? bodyText,

    /// Content type of the body
    @Default(ContentType.unknown) ContentType contentType,

    /// Content length in bytes
    @Default(0) int contentLength,

    /// HTTP version used
    @Default(HttpVersion.http1_1) HttpVersion httpVersion,

    /// Timestamp when request was captured
    required DateTime timestamp,

    /// Whether this is a secure (HTTPS) request
    @Default(false) bool isSecure,

    /// Client IP address
    String? clientAddress,

    /// GraphQL operation name (if applicable)
    String? graphqlOperationName,

    /// GraphQL operation type (query, mutation, subscription)
    String? graphqlOperationType,

    /// Cookies parsed from headers
    @Default({}) Map<String, String> cookies,
  }) = _HttpRequest;

  factory HttpRequest.fromJson(Map<String, dynamic> json) =>
      _$HttpRequestFromJson(json);

  /// Get a specific header value (case-insensitive)
  String? getHeader(String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get the content type header value
  String? get contentTypeHeader => getHeader('content-type');

  /// Get the user agent header value
  String? get userAgent => getHeader('user-agent');

  /// Get the authorization header value
  String? get authorization => getHeader('authorization');

  /// Check if this is a WebSocket upgrade request
  bool get isWebSocketUpgrade {
    final upgrade = getHeader('upgrade');
    return upgrade?.toLowerCase() == 'websocket';
  }

  /// Check if this is a GraphQL request
  bool get isGraphQL =>
      graphqlOperationName != null || contentType == ContentType.graphql;

  /// Get the display URL (without query string for brevity)
  String get displayUrl {
    if (queryString != null && queryString!.isNotEmpty) {
      return '$path?...';
    }
    return path;
  }

  /// Get the full authority (host:port)
  String get authority {
    if ((scheme == 'https' && port == 443) ||
        (scheme == 'http' && port == 80)) {
      return host;
    }
    return '$host:$port';
  }
}

/// Extension for parsing HTTP methods from strings
extension HttpMethodExtension on HttpMethod {
  String get name {
    switch (this) {
      case HttpMethod.get:
        return 'GET';
      case HttpMethod.post:
        return 'POST';
      case HttpMethod.put:
        return 'PUT';
      case HttpMethod.patch:
        return 'PATCH';
      case HttpMethod.delete:
        return 'DELETE';
      case HttpMethod.head:
        return 'HEAD';
      case HttpMethod.options:
        return 'OPTIONS';
      case HttpMethod.trace:
        return 'TRACE';
      case HttpMethod.connect:
        return 'CONNECT';
    }
  }

  static HttpMethod fromString(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'PATCH':
        return HttpMethod.patch;
      case 'DELETE':
        return HttpMethod.delete;
      case 'HEAD':
        return HttpMethod.head;
      case 'OPTIONS':
        return HttpMethod.options;
      case 'TRACE':
        return HttpMethod.trace;
      case 'CONNECT':
        return HttpMethod.connect;
      default:
        return HttpMethod.get;
    }
  }
}
