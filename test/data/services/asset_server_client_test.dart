import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';

void main() {
  group('AssetServerClient', () {
    group('health()', () {
      test('returns HealthResponse with correct fields from JSON', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://localhost:8080/api/health');
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'assetsRoot': '/home/user/project/assets',
              'readWrite': true,
            }),
            200,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);
        final response = await client.health();

        expect(response.status, 'ok');
        expect(response.assetsRoot, '/home/user/project/assets');
        expect(response.readWrite, true);
      });

      test('throws AssetServerException on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Service unavailable'}),
            503,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () => client.health(),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', 'Service unavailable')),
        );
      });
    });

    group('getFile()', () {
      test('returns Uint8List bytes from response', () async {
        final expectedBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/files/images/book_1/cover.webp');
          expect(request.method, 'GET');
          return http.Response.bytes(expectedBytes, 200);
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);
        final result = await client.getFile('images/book_1/cover.webp');

        expect(result, equals(expectedBytes));
      });

      test('throws AssetServerException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'File not found: images/missing.png'}),
            404,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () => client.getFile('images/missing.png'),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  'File not found: images/missing.png')),
        );
      });
    });

    group('getFileAsString()', () {
      test('returns string body', () async {
        final jsonContent = jsonEncode({'key': 'value', 'count': 42});
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/files/data/series.json');
          expect(request.method, 'GET');
          return http.Response(jsonContent, 200);
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);
        final result = await client.getFileAsString('data/series.json');

        expect(result, equals(jsonContent));
      });
    });

    group('listDirectory()', () {
      test('parses JSON array into List<FileEntry>', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/list/images/book_1');
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode([
              {
                'name': 'cover.webp',
                'path': 'images/book_1/cover.webp',
                'size': 2048,
                'type': 'file',
                'modified': '2024-01-15T10:30:00.000Z',
              },
              {
                'name': 'level_1.webp',
                'path': 'images/book_1/level_1.webp',
                'size': 4096,
                'type': 'file',
                'modified': null,
              },
            ]),
            200,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);
        final entries = await client.listDirectory('images/book_1');

        expect(entries, hasLength(2));
        expect(entries[0].name, 'cover.webp');
        expect(entries[0].path, 'images/book_1/cover.webp');
        expect(entries[0].size, 2048);
        expect(entries[0].type, 'file');
        expect(entries[0].modified, isNotNull);
        expect(entries[1].name, 'level_1.webp');
        expect(entries[1].modified, isNull);
      });

      test('throws AssetServerException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'error': 'Directory not found: images/nonexistent'}),
            404,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () => client.listDirectory('images/nonexistent'),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)),
        );
      });
    });

    group('putFile()', () {
      test('sends PUT request with bytes', () async {
        final fileBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/files/images/book_1/cover.webp');
          expect(request.method, 'PUT');
          expect(request.bodyBytes, equals(fileBytes));
          expect(
              request.headers['Content-Type'], 'application/octet-stream');
          return http.Response(
            jsonEncode({'success': true, 'path': 'images/book_1/cover.webp'}),
            200,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        // Should complete without throwing
        await client.putFile('images/book_1/cover.webp', fileBytes);
      });

      test('throws AssetServerException on error response', () async {
        final fileBytes = Uint8List.fromList([1, 2, 3]);
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'Extension .exe not allowed for directory images/'
            }),
            415,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () => client.putFile('images/book_1/malware.exe', fileBytes),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 415)
              .having((e) => e.message, 'message',
                  'Extension .exe not allowed for directory images/')),
        );
      });
    });

    group('createFile()', () {
      test('sends POST request with bytes', () async {
        final fileBytes = Uint8List.fromList([10, 20, 30, 40]);
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/files/images/rewards/new_reward.webp');
          expect(request.method, 'POST');
          expect(request.bodyBytes, equals(fileBytes));
          expect(
              request.headers['Content-Type'], 'application/octet-stream');
          return http.Response(
            jsonEncode(
                {'success': true, 'path': 'images/rewards/new_reward.webp'}),
            201,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        // Should complete without throwing
        await client.createFile('images/rewards/new_reward.webp', fileBytes);
      });

      test('throws AssetServerException on 409 conflict', () async {
        final fileBytes = Uint8List.fromList([10, 20, 30]);
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'File already exists: images/rewards/existing.webp'
            }),
            409,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () =>
              client.createFile('images/rewards/existing.webp', fileBytes),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message',
                  'File already exists: images/rewards/existing.webp')),
        );
      });
    });

    group('deleteFile()', () {
      test('sends DELETE request', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/files/images/book_1/old_image.webp');
          expect(request.method, 'DELETE');
          return http.Response(
            jsonEncode({'success': true}),
            200,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        // Should complete without throwing
        await client.deleteFile('images/book_1/old_image.webp');
      });

      test('throws AssetServerException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode(
                {'error': 'File not found: images/book_1/missing.webp'}),
            404,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        expect(
          () => client.deleteFile('images/book_1/missing.webp'),
          throwsA(isA<AssetServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  'File not found: images/book_1/missing.webp')),
        );
      });
    });

    group('createFolder()', () {
      test('sends POST to /api/folders/', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:8080/api/folders/images/book_4');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({'success': true, 'path': 'images/book_4'}),
            201,
          );
        });

        final client =
            AssetServerClient(baseUrl: 'http://localhost:8080', client: mockClient);

        // Should complete without throwing
        await client.createFolder('images/book_4');
      });
    });
  });
}
