import 'package:freezed_annotation/freezed_annotation.dart';
import 'http_request.dart';

part 'http_response.freezed.dart';
part 'http_response.g.dart';

/// Status code categories
enum StatusCategory {
  informational, // 1xx
  success, // 2xx
  redirection, // 3xx
  clientError, // 4xx
  serverError, // 5xx
  unknown,
}

/// Represents an HTTP response captured by the proxy
@freezed
class HttpResponse with _$HttpResponse {
  const HttpResponse._();

  const factory HttpResponse({
    /// HTTP status code
    required int statusCode,

    /// HTTP status message (e.g., "OK", "Not Found")
    required String statusMessage,

    /// HTTP version
    @Default(HttpVersion.http1_1) HttpVersion httpVersion,

    /// Response headers
    @Default({}) Map<String, String> headers,

    /// Response body as bytes
    List<int>? bodyBytes,

    /// Response body as string (if text-based)
    String? bodyText,

    /// Content type of the body
    @Default(ContentType.unknown) ContentType contentType,

    /// Content length in bytes
    @Default(0) int contentLength,

    /// Whether the response body was compressed
    @Default(false) bool wasCompressed,

    /// Original compression encoding (gzip, br, deflate)
    String? compressionEncoding,

    /// Timestamp when response was received
    required DateTime timestamp,

    /// Response timing information
    ResponseTiming? timing,

    /// Cookies set by the response
    @Default([]) List<SetCookie> cookies,

    /// Whether the response was served from cache
    @Default(false) bool fromCache,

    /// Whether the response was modified by a rule
    @Default(false) bool wasModified,

    /// Error message if the request failed
    String? error,
  }) = _HttpResponse;

  factory HttpResponse.fromJson(Map<String, dynamic> json) =>
      _$HttpResponseFromJson(json);

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

  /// Get the status category
  StatusCategory get statusCategory {
    if (statusCode >= 100 && statusCode < 200) {
      return StatusCategory.informational;
    } else if (statusCode >= 200 && statusCode < 300) {
      return StatusCategory.success;
    } else if (statusCode >= 300 && statusCode < 400) {
      return StatusCategory.redirection;
    } else if (statusCode >= 400 && statusCode < 500) {
      return StatusCategory.clientError;
    } else if (statusCode >= 500 && statusCode < 600) {
      return StatusCategory.serverError;
    }
    return StatusCategory.unknown;
  }

  /// Check if this is a successful response
  bool get isSuccess => statusCategory == StatusCategory.success;

  /// Check if this is an error response
  bool get isError =>
      statusCategory == StatusCategory.clientError ||
      statusCategory == StatusCategory.serverError;

  /// Check if this is a redirect response
  bool get isRedirect => statusCategory == StatusCategory.redirection;

  /// Get the content type header value
  String? get contentTypeHeader => getHeader('content-type');

  /// Get the location header (for redirects)
  String? get location => getHeader('location');

  /// Get the cache-control header
  String? get cacheControl => getHeader('cache-control');

  /// Get the ETag header
  String? get etag => getHeader('etag');

  /// Format status for display (e.g., "200 OK")
  String get displayStatus => '$statusCode $statusMessage';
}

/// Response timing information
@freezed
class ResponseTiming with _$ResponseTiming {
  const ResponseTiming._();

  const factory ResponseTiming({
    /// Time to establish connection (DNS + TCP + TLS)
    @Default(Duration.zero) Duration connectionTime,

    /// Time for DNS lookup
    @Default(Duration.zero) Duration dnsTime,

    /// Time for TCP connection
    @Default(Duration.zero) Duration tcpTime,

    /// Time for TLS handshake
    @Default(Duration.zero) Duration tlsTime,

    /// Time to first byte (TTFB)
    @Default(Duration.zero) Duration timeToFirstByte,

    /// Time to download response body
    @Default(Duration.zero) Duration downloadTime,

    /// Total request duration
    @Default(Duration.zero) Duration totalTime,

    /// Time spent waiting (queued)
    @Default(Duration.zero) Duration waitTime,
  }) = _ResponseTiming;

  factory ResponseTiming.fromJson(Map<String, dynamic> json) =>
      _$ResponseTimingFromJson(json);

  /// Get formatted total time string
  String get formattedTotalTime {
    final ms = totalTime.inMilliseconds;
    if (ms < 1000) {
      return '${ms}ms';
    } else if (ms < 60000) {
      return '${(ms / 1000).toStringAsFixed(2)}s';
    } else {
      final minutes = ms ~/ 60000;
      final seconds = (ms % 60000) / 1000;
      return '${minutes}m ${seconds.toStringAsFixed(0)}s';
    }
  }
}

/// Represents a Set-Cookie header
@freezed
class SetCookie with _$SetCookie {
  const SetCookie._();

  const factory SetCookie({
    required String name,
    required String value,
    String? domain,
    String? path,
    DateTime? expires,
    int? maxAge,
    @Default(false) bool secure,
    @Default(false) bool httpOnly,
    String? sameSite,
  }) = _SetCookie;

  factory SetCookie.fromJson(Map<String, dynamic> json) =>
      _$SetCookieFromJson(json);

  /// Parse a Set-Cookie header value
  factory SetCookie.parse(String cookieString) {
    final parts = cookieString.split(';').map((e) => e.trim()).toList();
    if (parts.isEmpty) {
      throw FormatException('Invalid cookie string: $cookieString');
    }

    final nameValue = parts[0].split('=');
    if (nameValue.length < 2) {
      throw FormatException('Invalid cookie name=value: ${parts[0]}');
    }

    final name = nameValue[0].trim();
    final value = nameValue.sublist(1).join('=').trim();

    String? domain;
    String? path;
    DateTime? expires;
    int? maxAge;
    bool secure = false;
    bool httpOnly = false;
    String? sameSite;

    for (var i = 1; i < parts.length; i++) {
      final attr = parts[i];
      final attrParts = attr.split('=');
      final attrName = attrParts[0].trim().toLowerCase();
      final attrValue = attrParts.length > 1 ? attrParts[1].trim() : null;

      switch (attrName) {
        case 'domain':
          domain = attrValue;
          break;
        case 'path':
          path = attrValue;
          break;
        case 'expires':
          if (attrValue != null) {
            try {
              expires = DateTime.parse(attrValue);
            } catch (_) {
              // Ignore parse errors
            }
          }
          break;
        case 'max-age':
          if (attrValue != null) {
            maxAge = int.tryParse(attrValue);
          }
          break;
        case 'secure':
          secure = true;
          break;
        case 'httponly':
          httpOnly = true;
          break;
        case 'samesite':
          sameSite = attrValue;
          break;
      }
    }

    return SetCookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      expires: expires,
      maxAge: maxAge,
      secure: secure,
      httpOnly: httpOnly,
      sameSite: sameSite,
    );
  }
}
