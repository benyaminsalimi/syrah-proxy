import 'dart:convert';

import '../models/models.dart';

/// Supported code generation languages
enum CodeLanguage {
  python,
  javascript,
  typescript,
  dart,
  swift,
  kotlin,
  java,
  go,
  ruby,
  php,
  csharp,
  rust,
}

/// Generates code snippets from HTTP requests
class CodeGenerator {
  /// Generate code for the specified language
  static String generate(HttpRequest request, CodeLanguage language) {
    switch (language) {
      case CodeLanguage.python:
        return _generatePython(request);
      case CodeLanguage.javascript:
        return _generateJavaScript(request);
      case CodeLanguage.typescript:
        return _generateTypeScript(request);
      case CodeLanguage.dart:
        return _generateDart(request);
      case CodeLanguage.swift:
        return _generateSwift(request);
      case CodeLanguage.kotlin:
        return _generateKotlin(request);
      case CodeLanguage.java:
        return _generateJava(request);
      case CodeLanguage.go:
        return _generateGo(request);
      case CodeLanguage.ruby:
        return _generateRuby(request);
      case CodeLanguage.php:
        return _generatePhp(request);
      case CodeLanguage.csharp:
        return _generateCSharp(request);
      case CodeLanguage.rust:
        return _generateRust(request);
    }
  }

  /// Python (requests library)
  static String _generatePython(HttpRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('import requests');
    buffer.writeln();

    // URL
    buffer.writeln("url = '${request.url}'");
    buffer.writeln();

    // Headers
    if (request.headers.isNotEmpty) {
      buffer.writeln('headers = {');
      for (final entry in request.headers.entries) {
        buffer.writeln("    '${entry.key}': '${_escapeString(entry.value)}',");
      }
      buffer.writeln('}');
      buffer.writeln();
    }

    // Body
    String? bodyVar;
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      if (request.contentType == ContentType.json) {
        try {
          final json = jsonDecode(request.bodyText!);
          buffer.writeln('data = ${_formatPythonDict(json)}');
          bodyVar = 'json=data';
        } catch (_) {
          buffer.writeln("data = '''${_escapeMultilineString(request.bodyText!)}'''");
          bodyVar = 'data=data';
        }
      } else {
        buffer.writeln("data = '''${_escapeMultilineString(request.bodyText!)}'''");
        bodyVar = 'data=data';
      }
      buffer.writeln();
    }

    // Request
    final methodLower = request.method.name.toLowerCase();
    final args = <String>['url'];
    if (request.headers.isNotEmpty) args.add('headers=headers');
    if (bodyVar != null) args.add(bodyVar);

    buffer.writeln('response = requests.$methodLower(${args.join(', ')})');
    buffer.writeln();
    buffer.writeln('print(response.status_code)');
    buffer.writeln('print(response.text)');

    return buffer.toString();
  }

  /// JavaScript (fetch API)
  static String _generateJavaScript(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln("const url = '${request.url}';");
    buffer.writeln();

    // Options
    buffer.writeln('const options = {');
    buffer.writeln("  method: '${request.method.name}',");

    // Headers
    if (request.headers.isNotEmpty) {
      buffer.writeln('  headers: {');
      for (final entry in request.headers.entries) {
        buffer.writeln("    '${entry.key}': '${_escapeString(entry.value)}',");
      }
      buffer.writeln('  },');
    }

    // Body
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      if (request.contentType == ContentType.json) {
        try {
          final json = jsonDecode(request.bodyText!);
          buffer.writeln('  body: JSON.stringify(${_formatJsObject(json)}),');
        } catch (_) {
          buffer.writeln("  body: `${_escapeTemplateString(request.bodyText!)}`,");
        }
      } else {
        buffer.writeln("  body: `${_escapeTemplateString(request.bodyText!)}`,");
      }
    }

    buffer.writeln('};');
    buffer.writeln();

    buffer.writeln('fetch(url, options)');
    buffer.writeln('  .then(response => response.json())');
    buffer.writeln('  .then(data => console.log(data))');
    buffer.writeln('  .catch(error => console.error(error));');

    return buffer.toString();
  }

  /// TypeScript (fetch API with types)
  static String _generateTypeScript(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln("const url: string = '${request.url}';");
    buffer.writeln();

    buffer.writeln('const options: RequestInit = {');
    buffer.writeln("  method: '${request.method.name}',");

    if (request.headers.isNotEmpty) {
      buffer.writeln('  headers: {');
      for (final entry in request.headers.entries) {
        buffer.writeln("    '${entry.key}': '${_escapeString(entry.value)}',");
      }
      buffer.writeln('  },');
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      if (request.contentType == ContentType.json) {
        try {
          final json = jsonDecode(request.bodyText!);
          buffer.writeln('  body: JSON.stringify(${_formatJsObject(json)}),');
        } catch (_) {
          buffer.writeln("  body: `${_escapeTemplateString(request.bodyText!)}`,");
        }
      } else {
        buffer.writeln("  body: `${_escapeTemplateString(request.bodyText!)}`,");
      }
    }

    buffer.writeln('};');
    buffer.writeln();

    buffer.writeln('async function makeRequest(): Promise<void> {');
    buffer.writeln('  try {');
    buffer.writeln('    const response = await fetch(url, options);');
    buffer.writeln('    const data = await response.json();');
    buffer.writeln('    console.log(data);');
    buffer.writeln('  } catch (error) {');
    buffer.writeln('    console.error(error);');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('makeRequest();');

    return buffer.toString();
  }

  /// Dart (http package)
  static String _generateDart(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln("import 'dart:convert';");
    buffer.writeln("import 'package:http/http.dart' as http;");
    buffer.writeln();

    buffer.writeln('Future<void> main() async {');
    buffer.writeln("  final url = Uri.parse('${request.url}');");
    buffer.writeln();

    if (request.headers.isNotEmpty) {
      buffer.writeln('  final headers = {');
      for (final entry in request.headers.entries) {
        buffer.writeln("    '${entry.key}': '${_escapeString(entry.value)}',");
      }
      buffer.writeln('  };');
      buffer.writeln();
    }

    String? bodyArg;
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      if (request.contentType == ContentType.json) {
        try {
          final json = jsonDecode(request.bodyText!);
          buffer.writeln('  final body = jsonEncode(${_formatDartMap(json)});');
          bodyArg = 'body: body';
        } catch (_) {
          buffer.writeln("  final body = '''${_escapeMultilineString(request.bodyText!)}''';");
          bodyArg = 'body: body';
        }
      } else {
        buffer.writeln("  final body = '''${_escapeMultilineString(request.bodyText!)}''';");
        bodyArg = 'body: body';
      }
      buffer.writeln();
    }

    final methodLower = request.method.name.toLowerCase();
    final args = <String>['url'];
    if (request.headers.isNotEmpty) args.add('headers: headers');
    if (bodyArg != null) args.add(bodyArg);

    buffer.writeln('  final response = await http.$methodLower(');
    buffer.writeln('    ${args.join(',\n    ')},');
    buffer.writeln('  );');
    buffer.writeln();
    buffer.writeln("  print('Status: \${response.statusCode}');");
    buffer.writeln("  print('Body: \${response.body}');");
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Swift (URLSession)
  static String _generateSwift(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('import Foundation');
    buffer.writeln();

    buffer.writeln('let url = URL(string: "${request.url}")!');
    buffer.writeln('var request = URLRequest(url: url)');
    buffer.writeln('request.httpMethod = "${request.method.name}"');
    buffer.writeln();

    if (request.headers.isNotEmpty) {
      for (final entry in request.headers.entries) {
        buffer.writeln('request.setValue("${_escapeString(entry.value)}", forHTTPHeaderField: "${entry.key}")');
      }
      buffer.writeln();
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln('let body = """');
      buffer.writeln(request.bodyText);
      buffer.writeln('"""');
      buffer.writeln('request.httpBody = body.data(using: .utf8)');
      buffer.writeln();
    }

    buffer.writeln('let task = URLSession.shared.dataTask(with: request) { data, response, error in');
    buffer.writeln('    if let error = error {');
    buffer.writeln('        print("Error: \\(error)")');
    buffer.writeln('        return');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln('    if let httpResponse = response as? HTTPURLResponse {');
    buffer.writeln('        print("Status: \\(httpResponse.statusCode)")');
    buffer.writeln('    }');
    buffer.writeln('    ');
    buffer.writeln('    if let data = data, let body = String(data: data, encoding: .utf8) {');
    buffer.writeln('        print("Body: \\(body)")');
    buffer.writeln('    }');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('task.resume()');

    return buffer.toString();
  }

  /// Kotlin (OkHttp)
  static String _generateKotlin(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('import okhttp3.*');
    buffer.writeln('import okhttp3.MediaType.Companion.toMediaType');
    buffer.writeln('import okhttp3.RequestBody.Companion.toRequestBody');
    buffer.writeln();

    buffer.writeln('val client = OkHttpClient()');
    buffer.writeln();

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      final mediaType = request.contentTypeHeader ?? 'application/json';
      buffer.writeln('val mediaType = "$mediaType".toMediaType()');
      buffer.writeln('val body = """');
      buffer.writeln(request.bodyText);
      buffer.writeln('""".trimIndent().toRequestBody(mediaType)');
      buffer.writeln();
    }

    buffer.writeln('val request = Request.Builder()');
    buffer.writeln('    .url("${request.url}")');

    for (final entry in request.headers.entries) {
      buffer.writeln('    .addHeader("${entry.key}", "${_escapeString(entry.value)}")');
    }

    final method = request.method.name.toLowerCase();
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln('    .$method(body)');
    } else if (method == 'post' || method == 'put' || method == 'patch') {
      buffer.writeln('    .$method("".toRequestBody(null))');
    } else {
      buffer.writeln('    .$method()');
    }

    buffer.writeln('    .build()');
    buffer.writeln();

    buffer.writeln('client.newCall(request).execute().use { response ->');
    buffer.writeln('    println("Status: \${response.code}")');
    buffer.writeln('    println("Body: \${response.body?.string()}")');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Java (HttpURLConnection)
  static String _generateJava(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('import java.net.*;');
    buffer.writeln('import java.io.*;');
    buffer.writeln();

    buffer.writeln('public class HttpExample {');
    buffer.writeln('    public static void main(String[] args) throws Exception {');
    buffer.writeln('        URL url = new URL("${request.url}");');
    buffer.writeln('        HttpURLConnection conn = (HttpURLConnection) url.openConnection();');
    buffer.writeln('        conn.setRequestMethod("${request.method.name}");');
    buffer.writeln();

    for (final entry in request.headers.entries) {
      buffer.writeln('        conn.setRequestProperty("${entry.key}", "${_escapeString(entry.value)}");');
    }
    buffer.writeln();

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln('        conn.setDoOutput(true);');
      buffer.writeln('        try (OutputStream os = conn.getOutputStream()) {');
      buffer.writeln('            byte[] input = """');
      buffer.writeln('                ${request.bodyText}');
      buffer.writeln('                """.getBytes("utf-8");');
      buffer.writeln('            os.write(input, 0, input.length);');
      buffer.writeln('        }');
      buffer.writeln();
    }

    buffer.writeln('        int status = conn.getResponseCode();');
    buffer.writeln('        System.out.println("Status: " + status);');
    buffer.writeln();
    buffer.writeln('        try (BufferedReader br = new BufferedReader(');
    buffer.writeln('                new InputStreamReader(conn.getInputStream(), "utf-8"))) {');
    buffer.writeln('            StringBuilder response = new StringBuilder();');
    buffer.writeln('            String line;');
    buffer.writeln('            while ((line = br.readLine()) != null) {');
    buffer.writeln('                response.append(line);');
    buffer.writeln('            }');
    buffer.writeln('            System.out.println("Body: " + response);');
    buffer.writeln('        }');
    buffer.writeln('    }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Go (net/http)
  static String _generateGo(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('package main');
    buffer.writeln();
    buffer.writeln('import (');
    buffer.writeln('    "fmt"');
    buffer.writeln('    "io"');
    buffer.writeln('    "net/http"');
    if (request.bodyText != null) buffer.writeln('    "strings"');
    buffer.writeln(')');
    buffer.writeln();

    buffer.writeln('func main() {');

    String? bodyReader;
    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln('    body := strings.NewReader(`${request.bodyText}`)');
      bodyReader = 'body';
    }

    buffer.writeln('    req, err := http.NewRequest("${request.method.name}", "${request.url}", $bodyReader)');
    buffer.writeln('    if err != nil {');
    buffer.writeln('        panic(err)');
    buffer.writeln('    }');
    buffer.writeln();

    for (final entry in request.headers.entries) {
      buffer.writeln('    req.Header.Set("${entry.key}", "${_escapeString(entry.value)}")');
    }
    buffer.writeln();

    buffer.writeln('    client := &http.Client{}');
    buffer.writeln('    resp, err := client.Do(req)');
    buffer.writeln('    if err != nil {');
    buffer.writeln('        panic(err)');
    buffer.writeln('    }');
    buffer.writeln('    defer resp.Body.Close()');
    buffer.writeln();

    buffer.writeln('    fmt.Println("Status:", resp.StatusCode)');
    buffer.writeln();
    buffer.writeln('    respBody, err := io.ReadAll(resp.Body)');
    buffer.writeln('    if err != nil {');
    buffer.writeln('        panic(err)');
    buffer.writeln('    }');
    buffer.writeln('    fmt.Println("Body:", string(respBody))');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Ruby (Net::HTTP)
  static String _generateRuby(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln("require 'net/http'");
    buffer.writeln("require 'uri'");
    buffer.writeln("require 'json'");
    buffer.writeln();

    buffer.writeln("uri = URI.parse('${request.url}')");
    buffer.writeln();

    buffer.writeln('http = Net::HTTP.new(uri.host, uri.port)');
    if (request.isSecure) {
      buffer.writeln('http.use_ssl = true');
    }
    buffer.writeln();

    final methodClass = _rubyMethodClass(request.method);
    buffer.writeln('request = Net::HTTP::$methodClass.new(uri.request_uri)');

    for (final entry in request.headers.entries) {
      buffer.writeln("request['${entry.key}'] = '${_escapeString(entry.value)}'");
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln("request.body = <<~BODY");
      buffer.writeln(request.bodyText);
      buffer.writeln('BODY');
    }
    buffer.writeln();

    buffer.writeln('response = http.request(request)');
    buffer.writeln('puts "Status: #{response.code}"');
    buffer.writeln('puts "Body: #{response.body}"');

    return buffer.toString();
  }

  static String _rubyMethodClass(HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        return 'Get';
      case HttpMethod.post:
        return 'Post';
      case HttpMethod.put:
        return 'Put';
      case HttpMethod.patch:
        return 'Patch';
      case HttpMethod.delete:
        return 'Delete';
      case HttpMethod.head:
        return 'Head';
      case HttpMethod.options:
        return 'Options';
      default:
        return 'Get';
    }
  }

  /// PHP (cURL)
  static String _generatePhp(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('<?php');
    buffer.writeln();
    buffer.writeln('\$curl = curl_init();');
    buffer.writeln();

    buffer.writeln('curl_setopt_array(\$curl, [');
    buffer.writeln("    CURLOPT_URL => '${request.url}',");
    buffer.writeln('    CURLOPT_RETURNTRANSFER => true,');
    buffer.writeln("    CURLOPT_CUSTOMREQUEST => '${request.method.name}',");

    if (request.headers.isNotEmpty) {
      buffer.writeln('    CURLOPT_HTTPHEADER => [');
      for (final entry in request.headers.entries) {
        buffer.writeln("        '${entry.key}: ${_escapeString(entry.value)}',");
      }
      buffer.writeln('    ],');
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln("    CURLOPT_POSTFIELDS => <<<'EOT'");
      buffer.writeln(request.bodyText);
      buffer.writeln('EOT,');
    }

    buffer.writeln(']);');
    buffer.writeln();

    buffer.writeln('\$response = curl_exec(\$curl);');
    buffer.writeln('\$httpCode = curl_getinfo(\$curl, CURLINFO_HTTP_CODE);');
    buffer.writeln('curl_close(\$curl);');
    buffer.writeln();

    buffer.writeln('echo "Status: " . \$httpCode . "\\n";');
    buffer.writeln('echo "Body: " . \$response . "\\n";');
    buffer.writeln('?>');

    return buffer.toString();
  }

  /// C# (HttpClient)
  static String _generateCSharp(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('using System;');
    buffer.writeln('using System.Net.Http;');
    buffer.writeln('using System.Text;');
    buffer.writeln('using System.Threading.Tasks;');
    buffer.writeln();

    buffer.writeln('class Program');
    buffer.writeln('{');
    buffer.writeln('    static async Task Main()');
    buffer.writeln('    {');
    buffer.writeln('        using var client = new HttpClient();');
    buffer.writeln();

    final methodClass = _csharpMethodClass(request.method);
    buffer.writeln('        var request = new HttpRequestMessage(HttpMethod.$methodClass, "${request.url}");');
    buffer.writeln();

    for (final entry in request.headers.entries) {
      buffer.writeln('        request.Headers.TryAddWithoutValidation("${entry.key}", "${_escapeString(entry.value)}");');
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      final mediaType = request.contentTypeHeader ?? 'application/json';
      buffer.writeln('        request.Content = new StringContent(@"');
      buffer.writeln(request.bodyText!.replaceAll('"', '""'));
      buffer.writeln('", Encoding.UTF8, "$mediaType");');
    }
    buffer.writeln();

    buffer.writeln('        var response = await client.SendAsync(request);');
    buffer.writeln('        var body = await response.Content.ReadAsStringAsync();');
    buffer.writeln();
    buffer.writeln('        Console.WriteLine(\$"Status: {(int)response.StatusCode}");');
    buffer.writeln('        Console.WriteLine(\$"Body: {body}");');
    buffer.writeln('    }');
    buffer.writeln('}');

    return buffer.toString();
  }

  static String _csharpMethodClass(HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        return 'Get';
      case HttpMethod.post:
        return 'Post';
      case HttpMethod.put:
        return 'Put';
      case HttpMethod.patch:
        return 'Patch';
      case HttpMethod.delete:
        return 'Delete';
      case HttpMethod.head:
        return 'Head';
      case HttpMethod.options:
        return 'Options';
      default:
        return 'Get';
    }
  }

  /// Rust (reqwest)
  static String _generateRust(HttpRequest request) {
    final buffer = StringBuffer();

    buffer.writeln('use reqwest::header::{HeaderMap, HeaderValue};');
    buffer.writeln();

    buffer.writeln('#[tokio::main]');
    buffer.writeln('async fn main() -> Result<(), Box<dyn std::error::Error>> {');
    buffer.writeln('    let client = reqwest::Client::new();');
    buffer.writeln();

    if (request.headers.isNotEmpty) {
      buffer.writeln('    let mut headers = HeaderMap::new();');
      for (final entry in request.headers.entries) {
        buffer.writeln('    headers.insert("${entry.key}", HeaderValue::from_static("${_escapeString(entry.value)}"));');
      }
      buffer.writeln();
    }

    final methodLower = request.method.name.toLowerCase();
    buffer.writeln('    let response = client');
    buffer.writeln('        .$methodLower("${request.url}")');

    if (request.headers.isNotEmpty) {
      buffer.writeln('        .headers(headers)');
    }

    if (request.bodyText != null && request.bodyText!.isNotEmpty) {
      buffer.writeln('        .body(r#"${request.bodyText}"#)');
    }

    buffer.writeln('        .send()');
    buffer.writeln('        .await?;');
    buffer.writeln();

    buffer.writeln('    println!("Status: {}", response.status());');
    buffer.writeln('    println!("Body: {}", response.text().await?);');
    buffer.writeln();
    buffer.writeln('    Ok(())');
    buffer.writeln('}');

    return buffer.toString();
  }

  // Helper methods
  static String _escapeString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  static String _escapeMultilineString(String input) {
    return input.replaceAll("'''", "\\'''");
  }

  static String _escapeTemplateString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('`', '\\`')
        .replaceAll('\$', '\\\$');
  }

  static String _formatPythonDict(dynamic value, [int indent = 0]) {
    final spaces = '    ' * indent;
    if (value == null) return 'None';
    if (value is bool) return value ? 'True' : 'False';
    if (value is num) return value.toString();
    if (value is String) return "'${_escapeString(value)}'";
    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((e) => _formatPythonDict(e, indent + 1)).join(',\n$spaces    ');
      return '[\n$spaces    $items\n$spaces]';
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final items = value.entries.map((e) => "'${e.key}': ${_formatPythonDict(e.value, indent + 1)}").join(',\n$spaces    ');
      return '{\n$spaces    $items\n$spaces}';
    }
    return value.toString();
  }

  static String _formatJsObject(dynamic value, [int indent = 0]) {
    final spaces = '  ' * indent;
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is String) return "'${_escapeString(value)}'";
    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((e) => _formatJsObject(e, indent + 1)).join(',\n$spaces  ');
      return '[\n$spaces  $items\n$spaces]';
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final items = value.entries.map((e) => "'${e.key}': ${_formatJsObject(e.value, indent + 1)}").join(',\n$spaces  ');
      return '{\n$spaces  $items\n$spaces}';
    }
    return value.toString();
  }

  static String _formatDartMap(dynamic value, [int indent = 0]) {
    final spaces = '    ' * indent;
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is String) return "'${_escapeString(value)}'";
    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value.map((e) => _formatDartMap(e, indent + 1)).join(',\n$spaces    ');
      return '[\n$spaces    $items,\n$spaces]';
    }
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final items = value.entries.map((e) => "'${e.key}': ${_formatDartMap(e.value, indent + 1)}").join(',\n$spaces    ');
      return '{\n$spaces    $items,\n$spaces}';
    }
    return value.toString();
  }
}
