import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/secure_key_value_store.dart';
import '../domain/accessibility_profile.dart';

/// Persists [AccessibilityProfile] as JSON in secure storage.
class AccessibilityProfileRepository {
  AccessibilityProfileRepository(this._store);

  static const String storageKey = 'bcc_adapt.accessibility_profile.v1';

  final SecureKeyValueStore _store;

  /// Returns `null` when nothing is stored or the payload is corrupted.
  Future<AccessibilityProfile?> load() async {
    try {
      final raw = await _store.read(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return AccessibilityProfile.fromJson(decoded);
    } catch (e, st) {
      // Never crash the bank app because of a broken local cache.
      debugPrint('AccessibilityProfileRepository.load failed: $e\n$st');
      return null;
    }
  }

  Future<void> save(AccessibilityProfile profile) =>
      _store.write(storageKey, jsonEncode(profile.toJson()));

  Future<void> clear() => _store.delete(storageKey);
}

final accessibilityProfileRepositoryProvider =
    Provider<AccessibilityProfileRepository>(
  (ref) => AccessibilityProfileRepository(ref.watch(secureKeyValueStoreProvider)),
);
