import 'package:flutter/foundation.dart';

import '../models/website.dart';
import 'package:dio/dio.dart';

class WebsiteService {
  static final Dio dio = Dio(
    BaseOptions(
      // baseUrl: 'http://localhost:9999',
      baseUrl: 'http://192.168.122.16:9095',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // init interceptor (log request/response)
  static void init() {
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  // GET ALL
  static Future<List<Website>> fetchWebsites() async {
    try {
      final response = await dio.get('/api/websites');

      final List data = response.data;

      return data.map((e) => Website.fromJson(e)).toList();
    } on DioException catch (e) {
      throw Exception(handleError(e));
    }
  }

  // CHECK WEB ACTIVE
  static Map<String, bool> _cache = {};
  static DateTime? _lastFetch;

  static Future<Map<String, bool>> checkBatch(List<String> urls) async {
    try {
      // 🔥 cache 30s
      if (_lastFetch != null &&
          DateTime.now().difference(_lastFetch!).inSeconds < 30) {
        return _cache;
      }

      final res = await dio.post('/api/websites/check-batch', data: urls);

      final result = Map<String, bool>.from(res.data);

      _cache = result;
      _lastFetch = DateTime.now();

      return result;
    } catch (e) {
      return {};
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
