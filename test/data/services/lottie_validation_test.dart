// Feature: asset-management, Property 8: Lottie Structure Validation
// **Validates: Requirements 13.3**

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/services/upload_validator.dart';

/// The four required Lottie fields.
const _requiredFields = ['v', 'layers', 'w', 'h'];

/// Characters for generating random string values.
const _valueChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Extension on [Any] to provide generators for Lottie JSON maps.
extension LottieGenerators on Any {
  /// Generates a JSON map that contains ALL four required Lottie fields
  /// plus some random extra fields.
  Generator<Map<String, dynamic>> get validLottieMap => simple(
        generate: (random, size) {
          final map = <String, dynamic>{};
          // Add all required fields with plausible values
          map['v'] = '${random.nextInt(5) + 1}.${random.nextInt(10)}.${random.nextInt(10)}';
          map['layers'] = <dynamic>[
            for (var i = 0; i < random.nextInt(3) + 1; i++)
              {'ty': random.nextInt(5), 'nm': 'layer_$i'},
          ];
          map['w'] = random.nextInt(1920) + 1;
          map['h'] = random.nextInt(1080) + 1;

          // Add random extra fields
          final extraCount = random.nextInt(size.clamp(0, 5));
          for (var i = 0; i < extraCount; i++) {
            final keyLen = random.nextInt(8) + 1;
            final keyBuf = StringBuffer();
            for (var j = 0; j < keyLen; j++) {
              keyBuf.write(_valueChars[random.nextInt(_valueChars.length)]);
            }
            final key = keyBuf.toString();
            // Don't overwrite required fields
            if (!_requiredFields.contains(key)) {
              map[key] = random.nextBool() ? random.nextInt(100) : 'val_$i';
            }
          }
          return map;
        },
        shrink: (input) => [],
      );

  /// Generates a random non-empty subset of the required fields to REMOVE,
  /// producing an invalid Lottie map (missing at least one required field).
  Generator<Map<String, dynamic>> get invalidLottieMap => simple(
        generate: (random, size) {
          final map = <String, dynamic>{};
          // Start with all required fields
          map['v'] = '5.0.0';
          map['layers'] = <dynamic>[
            {'ty': 1, 'nm': 'layer'},
          ];
          map['w'] = 100;
          map['h'] = 100;

          // Remove at least one required field (1 to 4 fields removed)
          final numToRemove = random.nextInt(_requiredFields.length) + 1;
          final fieldsToRemove = List<String>.from(_requiredFields)..shuffle(random);
          for (var i = 0; i < numToRemove; i++) {
            map.remove(fieldsToRemove[i]);
          }

          // Add some random extra fields
          final extraCount = random.nextInt(size.clamp(0, 3));
          for (var i = 0; i < extraCount; i++) {
            final keyLen = random.nextInt(6) + 1;
            final keyBuf = StringBuffer();
            for (var j = 0; j < keyLen; j++) {
              keyBuf.write(_valueChars[random.nextInt(_valueChars.length)]);
            }
            final key = keyBuf.toString();
            if (!_requiredFields.contains(key)) {
              map[key] = 'extra_$i';
            }
          }
          return map;
        },
        shrink: (input) => [],
      );

  /// Generates a random subset (0 to 4) of the required fields to include.
  /// Used to verify: accepted iff all 4 present.
  Generator<Set<String>> get randomFieldSubset => simple(
        generate: (random, size) {
          final subset = <String>{};
          for (final field in _requiredFields) {
            if (random.nextBool()) {
              subset.add(field);
            }
          }
          return subset;
        },
        shrink: (input) => [],
      );
}

/// Helper to encode a map as UTF-8 JSON bytes (the input format for validateLottieStructure).
List<int> _toBytes(Map<String, dynamic> map) {
  return utf8.encode(jsonEncode(map));
}

void main() {
  group('Property 8: Lottie Structure Validation', () {
    Glados(any.validLottieMap, ExploreConfig(numRuns: 100)).test(
      'accepts JSON maps containing all four required fields (v, layers, w, h)',
      (map) {
        // Verify all required fields are present
        for (final field in _requiredFields) {
          expect(map.containsKey(field), isTrue,
              reason: 'Generated valid map should contain "$field"');
        }

        final result = UploadValidator.validateLottieStructure(_toBytes(map));

        expect(result, isNull,
            reason:
                'validateLottieStructure should return null (valid) when all required fields are present. Map keys: ${map.keys.toList()}');
      },
    );

    Glados(any.invalidLottieMap, ExploreConfig(numRuns: 100)).test(
      'rejects JSON maps missing one or more required fields',
      (map) {
        // Verify at least one required field is missing
        final missingFields =
            _requiredFields.where((f) => !map.containsKey(f)).toList();
        expect(missingFields, isNotEmpty,
            reason: 'Generated invalid map should be missing at least one required field');

        final result = UploadValidator.validateLottieStructure(_toBytes(map));

        expect(result, isNotNull,
            reason:
                'validateLottieStructure should return an error message when fields are missing. Missing: $missingFields');
      },
    );

    Glados(any.randomFieldSubset, ExploreConfig(numRuns: 100)).test(
      'accepted iff all four required fields are present (random subsets)',
      (includedFields) {
        // Build a map with only the included fields
        final map = <String, dynamic>{};
        if (includedFields.contains('v')) map['v'] = '5.0.0';
        if (includedFields.contains('layers')) {
          map['layers'] = <dynamic>[
            {'ty': 1},
          ];
        }
        if (includedFields.contains('w')) map['w'] = 200;
        if (includedFields.contains('h')) map['h'] = 150;

        final result = UploadValidator.validateLottieStructure(_toBytes(map));
        final allPresent = includedFields.containsAll(_requiredFields);

        if (allPresent) {
          expect(result, isNull,
              reason:
                  'Should accept when all 4 fields present. Included: $includedFields');
        } else {
          expect(result, isNotNull,
              reason:
                  'Should reject when not all 4 fields present. Included: $includedFields');
        }
      },
    );
  });
}
