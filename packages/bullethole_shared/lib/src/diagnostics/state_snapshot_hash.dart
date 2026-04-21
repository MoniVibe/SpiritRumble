import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'bughunt_contract.dart';

class BughuntStateHasher {
  const BughuntStateHasher();

  StateSnapshotHash hashSnapshot(Map<String, Object?> snapshot) {
    final canonicalObject = _canonicalize(snapshot);
    final canonicalJson = jsonEncode(canonicalObject);
    final digest = sha256.convert(utf8.encode(canonicalJson)).toString();
    return StateSnapshotHash(
      algorithm: 'sha256',
      value: digest,
      canonicalJson: canonicalJson,
    );
  }

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (entry) => MapEntry<String, Object?>(
                  entry.key.toString(),
                  entry.value,
                ),
              )
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      final result = <String, Object?>{};
      for (final entry in entries) {
        result[entry.key] = _canonicalize(entry.value);
      }
      return result;
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value is num || value is bool || value == null) {
      return value;
    }
    return value.toString();
  }
}
