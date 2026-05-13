import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/upload_validator.dart';

void main() {
  group('Lottie Validation - UploadValidator.validateLottieStructure', () {
    test('valid Lottie JSON passes validation', () {
      final validLottie = {
        'v': '5.7.1',
        'layers': [
          {'ty': 4, 'nm': 'Shape Layer 1'},
          {'ty': 0, 'nm': 'Precomp Layer'},
        ],
        'w': 512,
        'h': 512,
        'fr': 30,
        'ip': 0,
        'op': 60,
      };

      final bytes = utf8.encode(jsonEncode(validLottie));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNull, reason: 'Valid Lottie should pass validation');
    });

    test('valid Lottie with minimal required fields passes', () {
      final minimalLottie = {
        'v': '4.0.0',
        'layers': <dynamic>[],
        'w': 100,
        'h': 100,
      };

      final bytes = utf8.encode(jsonEncode(minimalLottie));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNull);
    });

    test('missing "v" field is rejected', () {
      final missingV = {
        'layers': [
          {'ty': 4},
        ],
        'w': 512,
        'h': 512,
      };

      final bytes = utf8.encode(jsonEncode(missingV));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNotNull);
      expect(result, contains('v'));
    });

    test('missing "layers" field is rejected', () {
      final missingLayers = {
        'v': '5.0.0',
        'w': 512,
        'h': 512,
      };

      final bytes = utf8.encode(jsonEncode(missingLayers));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNotNull);
      expect(result, contains('layers'));
    });

    test('missing "w" field is rejected', () {
      final missingW = {
        'v': '5.0.0',
        'layers': <dynamic>[],
        'h': 512,
      };

      final bytes = utf8.encode(jsonEncode(missingW));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNotNull);
      expect(result, contains('w'));
    });

    test('missing "h" field is rejected', () {
      final missingH = {
        'v': '5.0.0',
        'layers': <dynamic>[],
        'w': 512,
      };

      final bytes = utf8.encode(jsonEncode(missingH));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNotNull);
      expect(result, contains('h'));
    });

    test('missing multiple fields reports all missing', () {
      final missingMultiple = {
        'v': '5.0.0',
        // missing layers, w, h
      };

      final bytes = utf8.encode(jsonEncode(missingMultiple));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNotNull);
      expect(result, contains('layers'));
      expect(result, contains('w'));
      expect(result, contains('h'));
    });

    test('non-JSON file is rejected', () {
      final notJson = utf8.encode('This is not JSON at all!');
      final result = UploadValidator.validateLottieStructure(notJson);

      expect(result, isNotNull);
      expect(result, contains('not valid JSON'));
    });

    test('empty file is rejected', () {
      final emptyBytes = utf8.encode('');
      final result = UploadValidator.validateLottieStructure(emptyBytes);

      expect(result, isNotNull);
    });

    test('JSON array (not object) is rejected', () {
      final jsonArray = utf8.encode(jsonEncode([1, 2, 3]));
      final result = UploadValidator.validateLottieStructure(jsonArray);

      expect(result, isNotNull);
      expect(result, contains('not a valid JSON object'));
    });

    test('JSON with extra fields but all required fields passes', () {
      final extraFields = {
        'v': '5.7.1',
        'layers': <dynamic>[],
        'w': 1920,
        'h': 1080,
        'fr': 60,
        'ip': 0,
        'op': 120,
        'ddd': 0,
        'assets': <dynamic>[],
        'fonts': {'list': <dynamic>[]},
      };

      final bytes = utf8.encode(jsonEncode(extraFields));
      final result = UploadValidator.validateLottieStructure(bytes);

      expect(result, isNull);
    });

    test('malformed JSON with partial content is rejected', () {
      final malformed = utf8.encode('{"v": "5.0.0", "layers": [');
      final result = UploadValidator.validateLottieStructure(malformed);

      expect(result, isNotNull);
    });
  });
}
