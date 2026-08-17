import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result_model.dart';

/// Persistent scan history using SharedPreferences.
/// Stores up to [maxItems] items (FIFO eviction).
class ScanHistoryService {
  static const String _key = 'scan_history_v1';
  static const int maxItems = 200;

  // In-memory cache — loaded once and kept in sync
  List<ScanHistoryItem> _items = [];
  bool _loaded = false;

  /// Load history from storage (call once before using [items]).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    _items = raw
        .map((s) {
          try {
            return ScanHistoryItem.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanHistoryItem>()
        .toList();
    _loaded = true;
  }

  /// Returns history items, most-recent first.
  List<ScanHistoryItem> get items => List.unmodifiable(_items);

  /// Returns items filtered by [type].
  List<ScanHistoryItem> itemsOfType(ScanType type) =>
      _items.where((i) => i.type == type).toList();

  /// Adds a new scan to history and persists it.
  Future<void> add(ScanHistoryItem item) async {
    await load(); // ensure loaded
    _items.insert(0, item);
    if (_items.length > maxItems) {
      _items = _items.sublist(0, maxItems);
    }
    await _persist();
  }

  /// Removes the item with [id] from history.
  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _persist();
  }

  /// Clears all history.
  Future<void> clearAll() async {
    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Convenience: add OCR result to history
  Future<void> addOcr(OcrResult result) async {
    await add(ScanHistoryItem.fromOcr(result));
  }

  /// Convenience: add barcode result to history
  Future<void> addBarcode(BarcodeResult result) async {
    await add(ScanHistoryItem.fromBarcode(result));
  }

  /// Convenience: add translation result to history
  Future<void> addTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLang,
    required String targetLang,
  }) async {
    await add(ScanHistoryItem.fromTranslation(
      originalText: originalText,
      translatedText: translatedText,
      sourceLang: sourceLang,
      targetLang: targetLang,
    ));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _items.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}
