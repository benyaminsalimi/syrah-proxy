import 'package:test/test.dart';
import 'package:syrah_core/models/http_request.dart';
import 'package:syrah_core/utils/code_generator.dart';

void main() {
  group('CodeGenerator', () {
    late HttpRequest simpleGetRequest;
    late HttpRequest postRequestWithJson;
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

      postRequestWithJson = HttpRequest(
        id: 'test-2',
        method: HttpMethod.post,
        url: 'https://api.example.com/users',
        scheme: 'https',
        host: 'api.example.com',
        port: 443,
        path: '/users',
        headers: {'Content-Type': 'application/json'},
        bodyText: '{"name": "John", "email": "john@example.com"}',
        contentType: ContentType.json,
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
        },
        bodyText: '{"name": "John"}',
        contentType: ContentType.json,
        timestamp: DateTime.now(),
        isSecure: true,
      );
    });

    group('Python', () {
      test('generates Python code with requests library', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.python);

        expect(code, contains('import requests'));
        expect(code, contains("url = 'https://api.example.com/users'"));
        expect(code, contains('requests.get(url'));
        expect(code, contains('print(response.status_code)'));
      });

      test('generates Python code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.python);

        expect(code, contains('headers = {'));
        expect(code, contains("'Content-Type': 'application/json'"));
        expect(code, contains("'Authorization': 'Bearer token123'"));
        expect(code, contains('headers=headers'));
      });

      test('generates Python code with JSON body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.python);

        expect(code, contains('requests.post('));
        expect(code, contains('data ='));
        expect(code, contains("'name':"));
      });
    });

    group('JavaScript', () {
      test('generates JavaScript code with fetch API', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.javascript);

        expect(code, contains("const url = 'https://api.example.com/users'"));
        expect(code, contains('const options = {'));
        expect(code, contains("method: 'GET'"));
        expect(code, contains('fetch(url, options)'));
        expect(code, contains('.then(response => response.json())'));
      });

      test('generates JavaScript code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.javascript);

        expect(code, contains('headers: {'));
        expect(code, contains("'Content-Type': 'application/json'"));
      });

      test('generates JavaScript code with JSON body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.javascript);

        expect(code, contains("method: 'POST'"));
        expect(code, contains('body: JSON.stringify('));
      });
    });

    group('TypeScript', () {
      test('generates TypeScript code with types', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.typescript);

        expect(code, contains('const url: string ='));
        expect(code, contains('const options: RequestInit ='));
        expect(code, contains('async function makeRequest(): Promise<void>'));
        expect(code, contains('await fetch(url, options)'));
      });

      test('generates TypeScript code with proper error handling', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.typescript);

        expect(code, contains('try {'));
        expect(code, contains('} catch (error) {'));
        expect(code, contains('console.error(error)'));
      });
    });

    group('Dart', () {
      test('generates Dart code with http package', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.dart);

        expect(code, contains("import 'dart:convert'"));
        expect(code, contains("import 'package:http/http.dart' as http"));
        expect(code, contains('Future<void> main() async'));
        expect(code, contains("Uri.parse('https://api.example.com/users')"));
        expect(code, contains('await http.get('));
      });

      test('generates Dart code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.dart);

        expect(code, contains('final headers = {'));
        expect(code, contains("'Content-Type': 'application/json'"));
        expect(code, contains('headers: headers'));
      });

      test('generates Dart code with JSON body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.dart);

        expect(code, contains('await http.post('));
        expect(code, contains('body:'));
      });
    });

    group('Swift', () {
      test('generates Swift code with URLSession', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.swift);

        expect(code, contains('import Foundation'));
        expect(code, contains('let url = URL(string: "https://api.example.com/users")!'));
        expect(code, contains('var request = URLRequest(url: url)'));
        expect(code, contains('request.httpMethod = "GET"'));
        expect(code, contains('URLSession.shared.dataTask(with: request)'));
      });

      test('generates Swift code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.swift);

        expect(code, contains('request.setValue('));
        expect(code, contains('forHTTPHeaderField:'));
      });

      test('generates Swift code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.swift);

        expect(code, contains('let body = """'));
        expect(code, contains('request.httpBody = body.data(using: .utf8)'));
      });
    });

    group('Kotlin', () {
      test('generates Kotlin code with OkHttp', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.kotlin);

        expect(code, contains('import okhttp3.*'));
        expect(code, contains('val client = OkHttpClient()'));
        expect(code, contains('val request = Request.Builder()'));
        expect(code, contains('.url("https://api.example.com/users")'));
        expect(code, contains('.get()'));
        expect(code, contains('client.newCall(request).execute()'));
      });

      test('generates Kotlin code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.kotlin);

        expect(code, contains('.addHeader('));
        expect(code, contains('"Content-Type"'));
      });

      test('generates Kotlin code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.kotlin);

        expect(code, contains('val mediaType ='));
        expect(code, contains('.toRequestBody(mediaType)'));
        expect(code, contains('.post(body)'));
      });
    });

    group('Java', () {
      test('generates Java code with HttpURLConnection', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.java);

        expect(code, contains('import java.net.*;'));
        expect(code, contains('import java.io.*;'));
        expect(code, contains('public class HttpExample'));
        expect(code, contains('URL url = new URL('));
        expect(code, contains('HttpURLConnection conn'));
        expect(code, contains('conn.setRequestMethod("GET")'));
      });

      test('generates Java code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.java);

        expect(code, contains('conn.setRequestProperty('));
      });

      test('generates Java code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.java);

        expect(code, contains('conn.setDoOutput(true)'));
        expect(code, contains('OutputStream os = conn.getOutputStream()'));
      });
    });

    group('Go', () {
      test('generates Go code with net/http', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.go);

        expect(code, contains('package main'));
        expect(code, contains('import ('));
        expect(code, contains('"net/http"'));
        expect(code, contains('http.NewRequest("GET"'));
        expect(code, contains('client := &http.Client{}'));
        expect(code, contains('client.Do(req)'));
      });

      test('generates Go code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.go);

        expect(code, contains('req.Header.Set('));
      });

      test('generates Go code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.go);

        expect(code, contains('"strings"'));
        expect(code, contains('strings.NewReader('));
      });
    });

    group('Ruby', () {
      test('generates Ruby code with Net::HTTP', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.ruby);

        expect(code, contains("require 'net/http'"));
        expect(code, contains("require 'uri'"));
        expect(code, contains('URI.parse('));
        expect(code, contains('Net::HTTP.new('));
        expect(code, contains('Net::HTTP::Get.new('));
      });

      test('generates Ruby code with SSL for HTTPS', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.ruby);

        expect(code, contains('http.use_ssl = true'));
      });

      test('generates Ruby code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.ruby);

        expect(code, contains("request['Content-Type']"));
      });
    });

    group('PHP', () {
      test('generates PHP code with cURL', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.php);

        expect(code, contains('<?php'));
        expect(code, contains(r'$curl = curl_init()'));
        expect(code, contains('curl_setopt_array('));
        expect(code, contains('CURLOPT_URL'));
        expect(code, contains('CURLOPT_RETURNTRANSFER'));
        expect(code, contains('curl_exec('));
      });

      test('generates PHP code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.php);

        expect(code, contains('CURLOPT_HTTPHEADER'));
        expect(code, contains('Content-Type: application/json'));
      });

      test('generates PHP code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.php);

        expect(code, contains('CURLOPT_POSTFIELDS'));
      });
    });

    group('C#', () {
      test('generates C# code with HttpClient', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.csharp);

        expect(code, contains('using System;'));
        expect(code, contains('using System.Net.Http;'));
        expect(code, contains('class Program'));
        expect(code, contains('static async Task Main()'));
        expect(code, contains('using var client = new HttpClient()'));
        expect(code, contains('new HttpRequestMessage(HttpMethod.Get'));
        expect(code, contains('await client.SendAsync(request)'));
      });

      test('generates C# code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.csharp);

        expect(code, contains('request.Headers.TryAddWithoutValidation('));
      });

      test('generates C# code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.csharp);

        expect(code, contains('new StringContent('));
      });
    });

    group('Rust', () {
      test('generates Rust code with reqwest', () {
        final code = CodeGenerator.generate(simpleGetRequest, CodeLanguage.rust);

        expect(code, contains('use reqwest::header'));
        expect(code, contains('#[tokio::main]'));
        expect(code, contains('async fn main()'));
        expect(code, contains('let client = reqwest::Client::new()'));
        expect(code, contains('.get("https://api.example.com/users")'));
        expect(code, contains('.send()'));
        expect(code, contains('.await?'));
      });

      test('generates Rust code with headers', () {
        final code = CodeGenerator.generate(postRequestWithHeaders, CodeLanguage.rust);

        expect(code, contains('let mut headers = HeaderMap::new()'));
        expect(code, contains('headers.insert('));
        expect(code, contains('.headers(headers)'));
      });

      test('generates Rust code with body', () {
        final code = CodeGenerator.generate(postRequestWithJson, CodeLanguage.rust);

        expect(code, contains('.body(r#"'));
      });
    });

    group('All HTTP methods', () {
      for (final method in HttpMethod.values) {
        test('handles ${method.name} method', () {
          final request = HttpRequest(
            id: 'test-${method.name}',
            method: method,
            url: 'https://api.example.com/test',
            scheme: 'https',
            host: 'api.example.com',
            port: 443,
            path: '/test',
            timestamp: DateTime.now(),
            isSecure: true,
          );

          for (final lang in CodeLanguage.values) {
            final code = CodeGenerator.generate(request, lang);
            expect(code, isNotEmpty);
          }
        });
      }
    });

    group('Edge cases', () {
      test('handles empty headers', () {
        for (final lang in CodeLanguage.values) {
          final code = CodeGenerator.generate(simpleGetRequest, lang);
          expect(code, isNotEmpty);
        }
      });

      test('handles special characters in URL', () {
        final request = HttpRequest(
          id: 'test-special',
          method: HttpMethod.get,
          url: 'https://api.example.com/users?name=John%20Doe&filter=a%26b',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/users',
          queryString: 'name=John%20Doe&filter=a%26b',
          timestamp: DateTime.now(),
          isSecure: true,
        );

        for (final lang in CodeLanguage.values) {
          final code = CodeGenerator.generate(request, lang);
          expect(code, isNotEmpty);
        }
      });

      test('handles non-JSON body', () {
        final request = HttpRequest(
          id: 'test-text',
          method: HttpMethod.post,
          url: 'https://api.example.com/upload',
          scheme: 'https',
          host: 'api.example.com',
          port: 443,
          path: '/upload',
          headers: {'Content-Type': 'text/plain'},
          bodyText: 'Plain text body content',
          contentType: ContentType.text,
          timestamp: DateTime.now(),
          isSecure: true,
        );

        for (final lang in CodeLanguage.values) {
          final code = CodeGenerator.generate(request, lang);
          expect(code, isNotEmpty);
          expect(code, contains('Plain text body content'));
        }
      });
    });
  });
}
