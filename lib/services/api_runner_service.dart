import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_endpoint.dart';

class ApiRunnerService {
  static ApiRunnerService? _instance;
  static ApiRunnerService get instance => _instance ??= ApiRunnerService._();
  ApiRunnerService._();

  Future<ApiResponse> run(ApiEndpoint endpoint) async {
    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse(endpoint.fullUrl);

      // Build headers map
      final headers = <String, String>{};
      for (final h in endpoint.headers) {
        if (h.enabled && h.key.isNotEmpty) {
          headers[h.key] = h.value;
        }
      }

      http.Response response;

      switch (endpoint.method) {
        case HttpMethod.GET:
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
        case HttpMethod.POST:
          response = await http
              .post(uri, headers: headers, body: endpoint.body)
              .timeout(const Duration(seconds: 30));
        case HttpMethod.PUT:
          response = await http
              .put(uri, headers: headers, body: endpoint.body)
              .timeout(const Duration(seconds: 30));
        case HttpMethod.DELETE:
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
        case HttpMethod.PATCH:
          response = await http
              .patch(uri, headers: headers, body: endpoint.body)
              .timeout(const Duration(seconds: 30));
      }

      stopwatch.stop();

      // Try to pretty-print JSON
      String body = response.body;
      try {
        final parsed = jsonDecode(body);
        body = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (_) {}

      final responseHeaders = <String, String>{};
      response.headers.forEach((k, v) => responseHeaders[k] = v);

      return ApiResponse(
        statusCode: response.statusCode,
        body: body,
        headers: responseHeaders,
        duration: stopwatch.elapsed,
        timestamp: DateTime.now(),
        endpointId: endpoint.id,
        endpointName: endpoint.name,
      );
    } catch (e) {
      stopwatch.stop();
      return ApiResponse(
        statusCode: 0,
        body: '{"error": "${e.toString().replaceAll('"', '\\"')}"}',
        headers: const {},
        duration: stopwatch.elapsed,
        timestamp: DateTime.now(),
        endpointId: endpoint.id,
        endpointName: endpoint.name,
      );
    }
  }
}
