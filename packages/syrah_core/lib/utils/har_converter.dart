import 'dart:convert';

import '../models/models.dart';

/// Converts NetworkFlows to/from HAR (HTTP Archive) format
/// HAR 1.2 Specification: http://www.softwareishard.com/blog/har-12-spec/
class HarConverter {
  /// Convert a list of flows to HAR format
  static Map<String, dynamic> toHar(
    List<NetworkFlow> flows, {
    String? creator,
    String? version,
    String? comment,
  }) {
    return {
      'log': {
        'version': '1.2',
        'creator': {
          'name': creator ?? 'NetScope',
          'version': version ?? '1.0.0',
        },
        if (comment != null) 'comment': comment,
        'entries': flows.map((f) => _flowToEntry(f)).toList(),
      },
    };
  }

  /// Convert a single flow to HAR entry
  static Map<String, dynamic> _flowToEntry(NetworkFlow flow) {
    final request = flow.request;
    final response = flow.response;

    return {
      'startedDateTime': request.timestamp.toIso8601String(),
      'time': flow.duration?.inMilliseconds ?? 0,
      'request': {
        'method': request.method.name,
        'url': request.url,
        'httpVersion': _httpVersionToString(request.httpVersion),
        'cookies': _parseCookies(request.cookies),
        'headers': _headersToList(request.headers),
        'queryString': _queryParamsToList(request.queryParams),
        'postData': request.bodyText != null
            ? {
                'mimeType': request.contentTypeHeader ?? 'application/octet-stream',
                'text': request.bodyText,
              }
            : null,
        'headersSize': _estimateHeadersSize(request.headers),
        'bodySize': request.contentLength,
      },
      'response': response != null
          ? {
              'status': response.statusCode,
              'statusText': response.statusMessage,
              'httpVersion': _httpVersionToString(response.httpVersion),
              'cookies': response.cookies.map((c) => _setCookieToHar(c)).toList(),
              'headers': _headersToList(response.headers),
              'content': {
                'size': response.contentLength,
                'compression': response.wasCompressed
                    ? (response.contentLength -
                        (response.bodyBytes?.length ?? 0))
                    : 0,
                'mimeType':
                    response.contentTypeHeader ?? 'application/octet-stream',
                'text': response.bodyText,
                if (response.bodyBytes != null && response.bodyText == null)
                  'encoding': 'base64',
              },
              'redirectURL': response.location ?? '',
              'headersSize': _estimateHeadersSize(response.headers),
              'bodySize': response.contentLength,
            }
          : {
              'status': 0,
              'statusText': '',
              'httpVersion': 'HTTP/1.1',
              'cookies': <Map<String, dynamic>>[],
              'headers': <Map<String, dynamic>>[],
              'content': {
                'size': 0,
                'mimeType': 'text/plain',
              },
              'redirectURL': '',
              'headersSize': 0,
              'bodySize': 0,
            },
      'cache': <String, dynamic>{},
      'timings': _timingsToHar(response?.timing),
      if (flow.connectionId != null) 'connection': flow.connectionId,
      if (flow.notes != null) 'comment': flow.notes,
    };
  }

  static String _httpVersionToString(HttpVersion version) {
    switch (version) {
      case HttpVersion.http1_0:
        return 'HTTP/1.0';
      case HttpVersion.http1_1:
        return 'HTTP/1.1';
      case HttpVersion.http2:
        return 'HTTP/2';
      case HttpVersion.http3:
        return 'HTTP/3';
    }
  }

  static List<Map<String, dynamic>> _parseCookies(Map<String, String> cookies) {
    return cookies.entries
        .map((e) => {
              'name': e.key,
              'value': e.value,
            })
        .toList();
  }

  static List<Map<String, dynamic>> _headersToList(Map<String, String> headers) {
    return headers.entries
        .map((e) => {
              'name': e.key,
              'value': e.value,
            })
        .toList();
  }

  static List<Map<String, dynamic>> _queryParamsToList(
    Map<String, List<String>> params,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final entry in params.entries) {
      for (final value in entry.value) {
        result.add({
          'name': entry.key,
          'value': value,
        });
      }
    }
    return result;
  }

  static int _estimateHeadersSize(Map<String, String> headers) {
    int size = 0;
    for (final entry in headers.entries) {
      size += entry.key.length + entry.value.length + 4; // ": " + "\r\n"
    }
    return size;
  }

  static Map<String, dynamic> _setCookieToHar(SetCookie cookie) {
    return {
      'name': cookie.name,
      'value': cookie.value,
      if (cookie.path != null) 'path': cookie.path,
      if (cookie.domain != null) 'domain': cookie.domain,
      if (cookie.expires != null) 'expires': cookie.expires!.toIso8601String(),
      if (cookie.httpOnly) 'httpOnly': true,
      if (cookie.secure) 'secure': true,
    };
  }

  static Map<String, dynamic> _timingsToHar(ResponseTiming? timing) {
    if (timing == null) {
      return {
        'send': 0,
        'wait': 0,
        'receive': 0,
      };
    }

    return {
      'blocked': timing.waitTime.inMilliseconds,
      'dns': timing.dnsTime.inMilliseconds,
      'connect': timing.tcpTime.inMilliseconds,
      'ssl': timing.tlsTime.inMilliseconds,
      'send': 0,
      'wait': timing.timeToFirstByte.inMilliseconds,
      'receive': timing.downloadTime.inMilliseconds,
    };
  }

  /// Parse HAR JSON to list of NetworkFlows
  static List<NetworkFlow> fromHar(Map<String, dynamic> har, String sessionId) {
    final log = har['log'] as Map<String, dynamic>;
    final entries = log['entries'] as List;

    return entries
        .map((e) => _entryToFlow(e as Map<String, dynamic>, sessionId))
        .toList();
  }

  static NetworkFlow _entryToFlow(
    Map<String, dynamic> entry,
    String sessionId,
  ) {
    final requestData = entry['request'] as Map<String, dynamic>;
    final responseData = entry['response'] as Map<String, dynamic>;

    final url = requestData['url'] as String;
    final uri = Uri.parse(url);

    final request = HttpRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      method: HttpMethodExtension.fromString(requestData['method'] as String),
      url: url,
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      queryString: uri.query.isEmpty ? null : uri.query,
      queryParams: uri.queryParametersAll,
      headers: _listToHeaders(requestData['headers'] as List),
      bodyText: (requestData['postData'] as Map<String, dynamic>?)?['text']
          as String?,
      httpVersion: _stringToHttpVersion(requestData['httpVersion'] as String),
      timestamp: DateTime.parse(entry['startedDateTime'] as String),
      isSecure: uri.scheme == 'https',
    );

    HttpResponse? response;
    final status = responseData['status'] as int;
    if (status > 0) {
      final content = responseData['content'] as Map<String, dynamic>;
      response = HttpResponse(
        statusCode: status,
        statusMessage: responseData['statusText'] as String,
        httpVersion: _stringToHttpVersion(responseData['httpVersion'] as String),
        headers: _listToHeaders(responseData['headers'] as List),
        bodyText: content['text'] as String?,
        contentLength: content['size'] as int? ?? 0,
        timestamp: request.timestamp.add(
          Duration(milliseconds: entry['time'] as int? ?? 0),
        ),
      );
    }

    return NetworkFlow(
      id: 'flow_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      request: request,
      response: response,
      state: response != null ? FlowState.completed : FlowState.failed,
      protocol:
          uri.scheme == 'https' ? ProtocolType.https : ProtocolType.http,
      createdAt: request.timestamp,
      updatedAt: DateTime.now(),
      notes: entry['comment'] as String?,
    );
  }

  static Map<String, String> _listToHeaders(List headers) {
    final result = <String, String>{};
    for (final h in headers) {
      final header = h as Map<String, dynamic>;
      result[header['name'] as String] = header['value'] as String;
    }
    return result;
  }

  static HttpVersion _stringToHttpVersion(String version) {
    switch (version.toUpperCase()) {
      case 'HTTP/1.0':
        return HttpVersion.http1_0;
      case 'HTTP/1.1':
        return HttpVersion.http1_1;
      case 'HTTP/2':
      case 'HTTP/2.0':
        return HttpVersion.http2;
      case 'HTTP/3':
        return HttpVersion.http3;
      default:
        return HttpVersion.http1_1;
    }
  }

  /// Convert HAR to JSON string
  static String toHarString(
    List<NetworkFlow> flows, {
    bool pretty = true,
    String? creator,
    String? version,
  }) {
    final har = toHar(flows, creator: creator, version: version);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(har);
    }
    return jsonEncode(har);
  }

  /// Parse HAR from JSON string
  static List<NetworkFlow> fromHarString(String harString, String sessionId) {
    final har = jsonDecode(harString) as Map<String, dynamic>;
    return fromHar(har, sessionId);
  }
}
