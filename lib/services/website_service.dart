import '../models/website.dart';
import 'package:dio/dio.dart';

class WebsiteService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:9999',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // init interceptor (log request/response)
  static void init() {
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
  }

  // GET ALL
  static Future<List<Website>> fetchWebsites() async {
    try {
      final response = await dio.get('/api/websites');
      print(response.data);
      final List data = response.data;

      return data.map((e) => Website.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // CHECK WEB ACTIVE
  static Future<Map<String, bool>> checkBatch(List<String> urls) async {
    try {
      final res = await dio.post('/api/websites/check-batch', data: urls);

      return Map<String, bool>.from(res.data);
    } catch (_) {
      return {};
    }
  }

  static final Map<String, bool> _cache = {};

  static Future<bool> checkWebsite(String url) async {
    if (_cache.containsKey(url)) {
      return _cache[url]!;
    }

    try {
      final response = await dio.get(
        '/api/websites/check',
        queryParameters: {'url': url},
      );

      final result =
          response.data == true || response.data.toString() == "true";

      _cache[url] = result;

      return result;
    } catch (_) {
      return false;
    }
  }

  // FILTER
  static Future<List<Website>> filter({
    String? department,
    String? type,
    bool? status,
  }) async {
    try {
      final response = await dio.get(
        '/api/websites',
        queryParameters: {
          if (department != null) 'department': department,
          if (type != null) 'type': type,
          if (status != null) 'status': status,
        },
      );

      final List data = response.data;

      return data.map((e) => Website.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // ERROR HANDLE
  static String handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      return "Timeout kết nối server";
    }

    if (e.type == DioExceptionType.badResponse) {
      return "Server lỗi: ${e.response?.statusCode}";
    }

    if (e.type == DioExceptionType.unknown) {
      return "Không kết nối được server";
    }

    return "Lỗi không xác định";
  }
}
