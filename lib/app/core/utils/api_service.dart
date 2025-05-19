import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../values/constants.dart';
import './helpers.dart';

class ApiService extends GetxService {
  final String baseUrl;
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Create a client with connection pooling
  final http.Client _client = http.Client();
  final int _maxRetries = 3;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.baseUrl;

  // Dispose client when service is closed
  @override
  void onClose() {
    _client.close();
    super.onClose();
  }

  // Set auth token for authenticated requests
  void setAuthToken(String token) {
    _headers['Authorization'] = 'Bearer $token';
  }

  // Clear auth token (for logout)
  void clearAuthToken() {
    _headers.remove('Authorization');
  }

  // GET request with retry mechanism
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException catch (e) {
      if (retryCount < _maxRetries) {
        // Exponential backoff: 1s, 2s, 4s
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return get(endpoint, queryParams: queryParams, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server: ${e.message}');
    } on TimeoutException {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return get(endpoint, queryParams: queryParams, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar('Error', 'Request timed out', isError: true);
      throw Exception('Request timed out');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // POST request with retry mechanism
  Future<dynamic> post(
    String endpoint, 
    dynamic body, {
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .post(uri, headers: _headers, body: json.encode(body))
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException catch (e) {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return post(endpoint, body, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server: ${e.message}');
    } on TimeoutException {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return post(endpoint, body, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar('Error', 'Request timed out', isError: true);
      throw Exception('Request timed out');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // PUT request with retry mechanism
  Future<dynamic> put(
    String endpoint, 
    dynamic body, {
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .put(uri, headers: _headers, body: json.encode(body))
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException catch (e) {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return put(endpoint, body, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server: ${e.message}');
    } on TimeoutException {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return put(endpoint, body, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar('Error', 'Request timed out', isError: true);
      throw Exception('Request timed out');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // DELETE request with retry mechanism
  Future<dynamic> delete(
    String endpoint, {
    int retryCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await _client
          .delete(uri, headers: _headers)
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException catch (e) {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return delete(endpoint, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server: ${e.message}');
    } on TimeoutException {
      if (retryCount < _maxRetries) {
        final waitTime = Duration(milliseconds: 1000 * (1 << retryCount));
        await Future.delayed(waitTime);
        return delete(endpoint, retryCount: retryCount + 1);
      }
      
      Helpers.showSnackBar('Error', 'Request timed out', isError: true);
      throw Exception('Request timed out');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // Process HTTP response with more detailed error handling
  dynamic _processResponse(http.Response response) {
    final contentType = response.headers['content-type'];
    final isJson = contentType != null && contentType.contains('application/json');

    switch (response.statusCode) {
      case 200:
      case 201:
        if (!isJson) {
          return response.body;
        }
        try {
          return json.decode(response.body);
        } catch (e) {
          Helpers.showSnackBar('Error', 'Invalid response format', isError: true);
          throw Exception('Invalid response format');
        }
      case 400:
        String message = 'Bad request';
        if (isJson) {
          try {
            final decoded = json.decode(response.body);
            message = decoded['message'] ?? decoded['error'] ?? 'Bad request';
          } catch (_) {}
        }
        Helpers.showSnackBar('Error', message, isError: true);
        throw Exception(message);
      case 401:
      case 403:
        String message = 'Unauthorized';
        if (isJson) {
          try {
            final decoded = json.decode(response.body);
            message = decoded['message'] ?? decoded['error'] ?? 'Unauthorized';
          } catch (_) {}
        }
        Helpers.showSnackBar('Error', message, isError: true);
        throw Exception(message);
      case 404:
        Helpers.showSnackBar('Error', 'Not found', isError: true);
        throw Exception('Not found');
      case 408:
        Helpers.showSnackBar('Error', 'Request timeout', isError: true);
        throw Exception('Request timeout');
      case 429:
        Helpers.showSnackBar('Error', 'Too many requests', isError: true);
        throw Exception('Too many requests');
      case 500:
      case 502:
      case 503:
      case 504:
        Helpers.showSnackBar('Error', 'Server error', isError: true);
        throw Exception('Server error');
      default:
        Helpers.showSnackBar('Error', 'Unknown error', isError: true);
        throw Exception('Unknown error');
    }
  }
}
