import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../../core/constants/asset_server_config.dart';

/// Exception thrown when the Asset Server returns a non-2xx response.
class AssetServerException implements Exception {
  final int statusCode;
  final String message;

  AssetServerException(this.statusCode, this.message);

  @override
  String toString() => 'AssetServerException($statusCode): $message';
}

/// Response from the `/api/health` endpoint.
class HealthResponse {
  final String status;
  final String assetsRoot;
  final bool readWrite;

  HealthResponse({
    required this.status,
    required this.assetsRoot,
    required this.readWrite,
  });

  factory HealthResponse.fromJson(Map<String, dynamic> json) {
    return HealthResponse(
      status: json['status'] as String,
      assetsRoot: json['assetsRoot'] as String,
      readWrite: json['readWrite'] as bool,
    );
  }
}

/// A single entry in a directory listing from `/api/list/{path}`.
class FileEntry {
  final String name;
  final String path;
  final int size;
  final String type;
  final DateTime? modified;

  FileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    this.modified,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int,
      type: json['type'] as String,
      modified: json['modified'] != null
          ? DateTime.tryParse(json['modified'] as String)
          : null,
    );
  }
}

/// HTTP client for communicating with the Asset Server.
///
/// All paths passed to methods are in API_Path format (relative to assets root,
/// no `assets/` prefix). Throws [AssetServerException] on non-2xx responses.
class AssetServerClient {
  final String baseUrl;
  final http.Client _client;

  static const Duration _healthTimeout = Duration(seconds: 5);
  static const Duration _fileTimeout = Duration(seconds: 30);

  AssetServerClient({
    this.baseUrl = AssetServerConfig.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Check server health.
  ///
  /// Uses a 5-second timeout. Throws [AssetServerException] on non-2xx
  /// or rethrows timeout/network errors.
  Future<HealthResponse> health() async {
    final uri = Uri.parse('$baseUrl/api/health');
    final response = await _client.get(uri).timeout(_healthTimeout);
    _throwIfNotOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return HealthResponse.fromJson(json);
  }

  /// Read a file as raw bytes.
  Future<Uint8List> getFile(String apiPath) async {
    final uri = Uri.parse('$baseUrl/api/files/$apiPath');
    final response = await _client.get(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
    return response.bodyBytes;
  }

  /// Read a file as a UTF-8 string.
  Future<String> getFileAsString(String apiPath) async {
    final uri = Uri.parse('$baseUrl/api/files/$apiPath');
    final response = await _client.get(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
    return response.body;
  }

  /// List directory contents.
  Future<List<FileEntry>> listDirectory(String apiPath) async {
    final uri = Uri.parse('$baseUrl/api/list/$apiPath');
    final response = await _client.get(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Write or overwrite a file at the given path.
  Future<void> putFile(String apiPath, Uint8List bytes) async {
    final uri = Uri.parse('$baseUrl/api/files/$apiPath');
    final response = await _client
        .put(uri, body: bytes, headers: _binaryHeaders)
        .timeout(_fileTimeout);
    _throwIfNotOk(response);
  }

  /// Create a new file at the given path. Fails with 409 if it already exists.
  Future<void> createFile(String apiPath, Uint8List bytes) async {
    final uri = Uri.parse('$baseUrl/api/files/$apiPath');
    final response = await _client
        .post(uri, body: bytes, headers: _binaryHeaders)
        .timeout(_fileTimeout);
    _throwIfNotOk(response);
  }

  /// Delete a file at the given path.
  Future<void> deleteFile(String apiPath) async {
    final uri = Uri.parse('$baseUrl/api/files/$apiPath');
    final response = await _client.delete(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
  }

  /// Create a directory at the given path.
  Future<void> createFolder(String apiPath) async {
    final uri = Uri.parse('$baseUrl/api/folders/$apiPath');
    final response = await _client.post(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
  }

  /// Syncs the main project's pubspec.yaml with the current image directories.
  ///
  /// Scans every folder under `images/` and updates pubspec.yaml's assets
  /// section to include them all. Call this after creating a new image folder.
  /// Throws [AssetServerException] with 409 if pubspec.yaml has no
  /// `- assets/images/` line to insert under; the file is left untouched.
  Future<void> syncPubspec() async {
    final uri = Uri.parse('$baseUrl/api/sync-pubspec');
    final response = await _client.post(uri).timeout(_fileTimeout);
    _throwIfNotOk(response);
  }

  /// Throws [AssetServerException] if the response status code is not 2xx.
  void _throwIfNotOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message;
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        message = json['error'] as String? ?? response.body;
      } catch (_) {
        message = response.body;
      }
      throw AssetServerException(response.statusCode, message);
    }
  }

  static const Map<String, String> _binaryHeaders = {
    'Content-Type': 'application/octet-stream',
  };
}
