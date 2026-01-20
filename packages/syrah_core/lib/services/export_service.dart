import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/models.dart';
import '../utils/har_converter.dart';
import '../utils/curl_generator.dart';
import '../utils/code_generator.dart';

/// Export formats supported by NetScope
enum ExportFormat {
  har,
  harGzip,
  json,
  curl,
  markdown,
  netscope,
}

/// Service for exporting network flows and sessions
class ExportService {
  /// Export flows to the specified format
  static Uint8List exportFlows(
    List<NetworkFlow> flows, {
    required ExportFormat format,
    String? sessionName,
  }) {
    switch (format) {
      case ExportFormat.har:
        return _exportHar(flows, compress: false);
      case ExportFormat.harGzip:
        return _exportHar(flows, compress: true);
      case ExportFormat.json:
        return _exportJson(flows);
      case ExportFormat.curl:
        return _exportCurl(flows);
      case ExportFormat.markdown:
        return _exportMarkdown(flows, sessionName: sessionName);
      case ExportFormat.netscope:
        return _exportNetscope(flows, sessionName: sessionName);
    }
  }

  /// Export as HAR
  static Uint8List _exportHar(List<NetworkFlow> flows, {bool compress = false}) {
    final harString = HarConverter.toHarString(
      flows,
      pretty: !compress,
      creator: 'NetScope',
      version: '1.0.0',
    );

    final bytes = utf8.encode(harString);

    if (compress) {
      return Uint8List.fromList(GZipEncoder().encode(bytes)!);
    }

    return Uint8List.fromList(bytes);
  }

  /// Export as JSON
  static Uint8List _exportJson(List<NetworkFlow> flows) {
    final data = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'flowCount': flows.length,
      'flows': flows.map((f) => f.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Export as cURL commands
  static Uint8List _exportCurl(List<NetworkFlow> flows) {
    final buffer = StringBuffer();

    buffer.writeln('# NetScope Export');
    buffer.writeln('# Exported at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Flow count: ${flows.length}');
    buffer.writeln();

    for (int i = 0; i < flows.length; i++) {
      final flow = flows[i];
      buffer.writeln('# Request ${i + 1}: ${flow.request.method.name} ${flow.request.url}');
      if (flow.response != null) {
        buffer.writeln('# Response: ${flow.response!.statusCode} ${flow.response!.statusMessage}');
      }
      buffer.writeln();
      buffer.writeln(CurlGenerator.generate(flow.request));
      buffer.writeln();
      buffer.writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Export as Markdown
  static Uint8List _exportMarkdown(List<NetworkFlow> flows, {String? sessionName}) {
    final buffer = StringBuffer();

    buffer.writeln('# ${sessionName ?? 'NetScope Export'}');
    buffer.writeln();
    buffer.writeln('**Exported at:** ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('**Total Requests:** ${flows.length}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (int i = 0; i < flows.length; i++) {
      final flow = flows[i];
      final request = flow.request;
      final response = flow.response;

      buffer.writeln('## ${i + 1}. ${request.method.name} ${request.path}');
      buffer.writeln();

      // Request section
      buffer.writeln('### Request');
      buffer.writeln();
      buffer.writeln('- **URL:** `${request.url}`');
      buffer.writeln('- **Method:** ${request.method.name}');
      buffer.writeln('- **Timestamp:** ${request.timestamp.toIso8601String()}');
      buffer.writeln();

      if (request.headers.isNotEmpty) {
        buffer.writeln('#### Headers');
        buffer.writeln();
        buffer.writeln('| Header | Value |');
        buffer.writeln('|--------|-------|');
        for (final entry in request.headers.entries) {
          buffer.writeln('| ${entry.key} | ${_escapeMarkdown(entry.value)} |');
        }
        buffer.writeln();
      }

      if (request.bodyText != null && request.bodyText!.isNotEmpty) {
        buffer.writeln('#### Body');
        buffer.writeln();
        final lang = _getLanguageHint(request.contentType);
        buffer.writeln('```$lang');
        buffer.writeln(request.bodyText);
        buffer.writeln('```');
        buffer.writeln();
      }

      // Response section
      if (response != null) {
        buffer.writeln('### Response');
        buffer.writeln();
        buffer.writeln('- **Status:** ${response.statusCode} ${response.statusMessage}');
        buffer.writeln('- **Duration:** ${flow.formattedDuration}');
        buffer.writeln('- **Size:** ${flow.formattedSize}');
        buffer.writeln();

        if (response.headers.isNotEmpty) {
          buffer.writeln('#### Headers');
          buffer.writeln();
          buffer.writeln('| Header | Value |');
          buffer.writeln('|--------|-------|');
          for (final entry in response.headers.entries) {
            buffer.writeln('| ${entry.key} | ${_escapeMarkdown(entry.value)} |');
          }
          buffer.writeln();
        }

        if (response.bodyText != null && response.bodyText!.isNotEmpty) {
          buffer.writeln('#### Body');
          buffer.writeln();
          final lang = _getLanguageHint(response.contentType);
          // Truncate long bodies in markdown export
          final body = response.bodyText!.length > 10000
              ? '${response.bodyText!.substring(0, 10000)}\n\n... (truncated)'
              : response.bodyText!;
          buffer.writeln('```$lang');
          buffer.writeln(body);
          buffer.writeln('```');
          buffer.writeln();
        }
      }

      buffer.writeln('---');
      buffer.writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Export in NetScope native format (compressed JSON with metadata)
  static Uint8List _exportNetscope(List<NetworkFlow> flows, {String? sessionName}) {
    final data = {
      'format': 'netscope',
      'version': '1.0',
      'sessionName': sessionName,
      'exportedAt': DateTime.now().toIso8601String(),
      'flowCount': flows.length,
      'flows': flows.map((f) => f.toJson()).toList(),
    };

    final jsonString = jsonEncode(data);
    final compressed = GZipEncoder().encode(utf8.encode(jsonString))!;
    return Uint8List.fromList(compressed);
  }

  /// Import flows from HAR data
  static List<NetworkFlow> importHar(Uint8List data, String sessionId) {
    List<int> bytes = data;

    // Check if gzipped
    if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
      bytes = GZipDecoder().decodeBytes(data);
    }

    final jsonString = utf8.decode(bytes);
    return HarConverter.fromHarString(jsonString, sessionId);
  }

  /// Import flows from NetScope format
  static List<NetworkFlow> importNetscope(Uint8List data, String sessionId) {
    List<int> bytes = data;

    // Decompress if gzipped
    if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
      bytes = GZipDecoder().decodeBytes(data);
    }

    final jsonString = utf8.decode(bytes);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    if (json['format'] != 'netscope') {
      throw FormatException('Invalid NetScope format');
    }

    final flowsJson = json['flows'] as List;
    return flowsJson
        .map((f) => NetworkFlow.fromJson(f as Map<String, dynamic>))
        .map((f) => f.copyWith(sessionId: sessionId))
        .toList();
  }

  /// Generate code from a single request
  static String generateCode(HttpRequest request, CodeLanguage language) {
    return CodeGenerator.generate(request, language);
  }

  /// Generate cURL command from a request
  static String generateCurl(HttpRequest request, {bool oneLine = false}) {
    if (oneLine) {
      return CurlGenerator.generateOneLine(request);
    }
    return CurlGenerator.generate(request);
  }

  static String _escapeMarkdown(String text) {
    return text
        .replaceAll('|', '\\|')
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
  }

  static String _getLanguageHint(ContentType type) {
    switch (type) {
      case ContentType.json:
      case ContentType.graphql:
        return 'json';
      case ContentType.xml:
        return 'xml';
      case ContentType.html:
        return 'html';
      default:
        return '';
    }
  }
}

/// Supported import formats
enum ImportFormat {
  har,
  netscope,
  curl,
}

/// Helper for detecting import format
class ImportFormatDetector {
  /// Detect the format of import data
  static ImportFormat? detect(Uint8List data) {
    try {
      List<int> bytes = data;

      // Check for gzip
      if (data.length > 2 && data[0] == 0x1f && data[1] == 0x8b) {
        bytes = GZipDecoder().decodeBytes(data);
      }

      final content = utf8.decode(bytes);

      // Try to parse as JSON
      try {
        final json = jsonDecode(content) as Map<String, dynamic>;

        // Check for NetScope format
        if (json['format'] == 'netscope') {
          return ImportFormat.netscope;
        }

        // Check for HAR format
        if (json.containsKey('log') && (json['log'] as Map).containsKey('entries')) {
          return ImportFormat.har;
        }
      } catch (_) {
        // Not JSON
      }

      // Check for cURL
      if (content.trim().startsWith('curl ')) {
        return ImportFormat.curl;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
