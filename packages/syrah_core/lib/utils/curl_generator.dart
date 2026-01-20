import '../models/models.dart';

/// Generates cURL commands from HTTP requests
class CurlGenerator {
  /// Generate a cURL command from an HttpRequest
  static String generate(
    HttpRequest request, {
    bool compressed = true,
    bool insecure = false,
    bool verbose = false,
    bool silent = false,
    bool followRedirects = true,
    int? timeout,
  }) {
    final parts = <String>['curl'];

    // Add flags
    if (compressed) {
      parts.add('--compressed');
    }
    if (insecure && request.isSecure) {
      parts.add('--insecure');
    }
    if (verbose) {
      parts.add('--verbose');
    }
    if (silent) {
      parts.add('--silent');
    }
    if (followRedirects) {
      parts.add('--location');
    }
    if (timeout != null) {
      parts.add('--max-time $timeout');
    }

    // Add method (for non-GET requests)
    if (request.method != HttpMethod.get) {
      parts.add('-X ${request.method.name}');
    }

    // Add headers
    for (final entry in request.headers.entries) {
      // Skip headers that curl handles automatically
      if (_shouldSkipHeader(entry.key)) continue;

      final escapedValue = _escapeShellString(entry.value);
      parts.add("-H '${entry.key}: $escapedValue'");
    }

    // Add body
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      final escapedBody = _escapeShellString(request.bodyText!);
      if (request.bodyText!.length > 1000) {
        // For large bodies, use a file reference or data-binary
        parts.add("--data-raw '\$'$escapedBody''");
      } else {
        parts.add("-d '$escapedBody'");
      }
    } else if (request.bodyBytes != null && request.bodyBytes!.isNotEmpty) {
      parts.add('--data-binary @<file>');
    }

    // Add URL (always last)
    parts.add("'${_escapeShellString(request.url)}'");

    return parts.join(' \\\n  ');
  }

  /// Generate a one-line cURL command
  static String generateOneLine(HttpRequest request) {
    final parts = <String>['curl'];

    // Add method
    if (request.method != HttpMethod.get) {
      parts.add('-X ${request.method.name}');
    }

    // Add essential headers only
    for (final entry in request.headers.entries) {
      if (_isEssentialHeader(entry.key)) {
        parts.add("-H '${entry.key}: ${_escapeShellString(entry.value)}'");
      }
    }

    // Add body
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      parts.add("-d '${_escapeShellString(request.bodyText!)}'");
    }

    // Add URL
    parts.add("'${_escapeShellString(request.url)}'");

    return parts.join(' ');
  }

  /// Generate a PowerShell Invoke-WebRequest command
  static String generatePowerShell(HttpRequest request) {
    final parts = <String>['Invoke-WebRequest'];

    // Add URI
    parts.add("-Uri '${request.url}'");

    // Add method
    parts.add('-Method ${request.method.name}');

    // Add headers
    if (request.headers.isNotEmpty) {
      final headerParts = <String>[];
      for (final entry in request.headers.entries) {
        if (_shouldSkipHeader(entry.key)) continue;
        headerParts.add("'${entry.key}'='${_escapePowerShellString(entry.value)}'");
      }
      if (headerParts.isNotEmpty) {
        parts.add('-Headers @{${headerParts.join('; ')}}');
      }
    }

    // Add body
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      parts.add("-Body '${_escapePowerShellString(request.bodyText!)}'");
    }

    return parts.join(' `\n  ');
  }

  /// Generate a wget command
  static String generateWget(HttpRequest request) {
    final parts = <String>['wget'];

    // Add method
    parts.add('--method=${request.method.name}');

    // Add headers
    for (final entry in request.headers.entries) {
      if (_shouldSkipHeader(entry.key)) continue;
      parts.add("--header='${entry.key}: ${_escapeShellString(entry.value)}'");
    }

    // Add body
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      parts.add("--body-data='${_escapeShellString(request.bodyText!)}'");
    }

    // Add URL
    parts.add("'${_escapeShellString(request.url)}'");

    return parts.join(' \\\n  ');
  }

  /// Parse a cURL command into an HttpRequest
  static HttpRequest? parse(String curlCommand) {
    try {
      // Remove newlines and continuation characters
      final normalized = curlCommand
          .replaceAll('\\\n', ' ')
          .replaceAll('\\\r\n', ' ')
          .trim();

      // Extract URL - try single quotes, double quotes, or unquoted
      final urlMatchSingle = RegExp(r"'([^']+)'$").firstMatch(normalized);
      final urlMatchDouble = RegExp(r'"([^"]+)"$').firstMatch(normalized);
      final urlMatchUnquoted = RegExp(r'(\S+)$').firstMatch(normalized);

      String? url;
      if (urlMatchSingle != null) {
        url = urlMatchSingle.group(1);
      } else if (urlMatchDouble != null) {
        url = urlMatchDouble.group(1);
      } else if (urlMatchUnquoted != null) {
        url = urlMatchUnquoted.group(1);
      }

      if (url == null) return null;
      final uri = Uri.parse(url);

      // Extract method
      final methodMatch = RegExp(r'-X\s+(\w+)').firstMatch(normalized);
      final method = methodMatch != null
          ? HttpMethodExtension.fromString(methodMatch.group(1)!)
          : HttpMethod.get;

      // Extract headers
      final headers = <String, String>{};
      final headerMatchesSingle = RegExp(r"-H\s+'([^:]+):\s*([^']*)'").allMatches(normalized);
      final headerMatchesDouble = RegExp(r'-H\s+"([^:]+):\s*([^"]*)"').allMatches(normalized);

      for (final match in headerMatchesSingle) {
        final name = match.group(1);
        final value = match.group(2);
        if (name != null && value != null) {
          headers[name] = value;
        }
      }
      for (final match in headerMatchesDouble) {
        final name = match.group(1);
        final value = match.group(2);
        if (name != null && value != null) {
          headers[name] = value;
        }
      }

      // Extract body
      String? body;
      final bodyMatchSingle = RegExp(r"-d\s+'([^']*)'|--data\s+'([^']*)'").firstMatch(normalized);
      final bodyMatchDouble = RegExp(r'-d\s+"([^"]*)"|--data\s+"([^"]*)"').firstMatch(normalized);
      if (bodyMatchSingle != null) {
        body = bodyMatchSingle.group(1) ?? bodyMatchSingle.group(2);
      } else if (bodyMatchDouble != null) {
        body = bodyMatchDouble.group(1) ?? bodyMatchDouble.group(2);
      }

      return HttpRequest(
        id: 'parsed_${DateTime.now().millisecondsSinceEpoch}',
        method: method,
        url: url,
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        path: uri.path,
        queryString: uri.query.isEmpty ? null : uri.query,
        queryParams: uri.queryParametersAll,
        headers: headers,
        bodyText: body,
        timestamp: DateTime.now(),
        isSecure: uri.scheme == 'https',
      );
    } catch (e) {
      return null;
    }
  }

  static bool _shouldSkipHeader(String header) {
    final lower = header.toLowerCase();
    return lower == 'host' ||
        lower == 'content-length' ||
        lower == 'connection' ||
        lower == 'accept-encoding';
  }

  static bool _isEssentialHeader(String header) {
    final lower = header.toLowerCase();
    return lower == 'content-type' ||
        lower == 'authorization' ||
        lower == 'accept' ||
        lower == 'cookie';
  }

  static String _escapeShellString(String input) {
    return input
        .replaceAll("'", "'\"'\"'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  static String _escapePowerShellString(String input) {
    return input
        .replaceAll("'", "''")
        .replaceAll('`', '``')
        .replaceAll('\n', '`n')
        .replaceAll('\r', '`r');
  }
}
