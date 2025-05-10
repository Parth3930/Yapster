import 'dart:convert';
import 'dart:io';
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

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.baseUrl;

  // Set auth token for authenticated requests
  void setAuthToken(String token) {
    _headers['Authorization'] = 'Bearer $token';
  }

  // Clear auth token (for logout)
  void clearAuthToken() {
    _headers.remove('Authorization');
  }

  // GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: _headers)
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException {
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // POST request
  Future<dynamic> post(String endpoint, dynamic body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .post(uri, headers: _headers, body: json.encode(body))
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException {
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // PUT request
  Future<dynamic> put(String endpoint, dynamic body) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(uri, headers: _headers, body: json.encode(body))
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException {
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(Duration(milliseconds: AppConstants.connectionTimeout));
      return _processResponse(response);
    } on SocketException {
      Helpers.showSnackBar('Error', 'No internet connection', isError: true);
      throw Exception('No internet connection');
    } on http.ClientException {
      Helpers.showSnackBar(
        'Error',
        'Failed to connect to server',
        isError: true,
      );
      throw Exception('Failed to connect to server');
    } catch (e) {
      Helpers.showSnackBar('Error', e.toString(), isError: true);
      throw Exception(e.toString());
    }
  }

  // Process HTTP response
  dynamic _processResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return json.decode(response.body);
      case 400:
        Helpers.showSnackBar('Error', 'Bad request', isError: true);
        throw Exception('Bad request');
      case 401:
      case 403:
        Helpers.showSnackBar('Error', 'Unauthorized', isError: true);
        throw Exception('Unauthorized');
      case 404:
        Helpers.showSnackBar('Error', 'Not found', isError: true);
        throw Exception('Not found');
      case 500:
      default:
        Helpers.showSnackBar('Error', 'Server error', isError: true);
        throw Exception('Server error');
    }
  }
}
