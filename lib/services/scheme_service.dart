import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/government_scheme_model.dart';
import 'scheme_database.dart';
import 'scheme_matcher.dart';

enum ApplicationStatus { notApplied, inProgress, applied, received, rejected }

class SchemeBookmark {
  final String schemeId;
  final DateTime savedAt;

  const SchemeBookmark({required this.schemeId, required this.savedAt});

  Map<String, dynamic> toJson() => {'schemeId': schemeId, 'savedAt': savedAt.toIso8601String()};

  factory SchemeBookmark.fromJson(Map<String, dynamic> json) => SchemeBookmark(
    schemeId: json['schemeId'],
    savedAt: DateTime.parse(json['savedAt']),
  );
}

class ApplicationRecord {
  final String schemeId;
  final ApplicationStatus status;
  final DateTime? appliedAt;
  final DateTime? deadline;
  final String notes;
  final List<String> documentsSubmitted;

  const ApplicationRecord({
    required this.schemeId,
    this.status = ApplicationStatus.notApplied,
    this.appliedAt,
    this.deadline,
    this.notes = '',
    this.documentsSubmitted = const [],
  });

  ApplicationRecord copyWith({
    ApplicationStatus? status,
    DateTime? appliedAt,
    DateTime? deadline,
    String? notes,
    List<String>? documentsSubmitted,
  }) {
    return ApplicationRecord(
      schemeId: schemeId,
      status: status ?? this.status,
      appliedAt: appliedAt ?? this.appliedAt,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      documentsSubmitted: documentsSubmitted ?? this.documentsSubmitted,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemeId': schemeId,
    'status': status.index,
    'appliedAt': appliedAt?.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'notes': notes,
    'documentsSubmitted': documentsSubmitted,
  };

  factory ApplicationRecord.fromJson(Map<String, dynamic> json) => ApplicationRecord(
    schemeId: json['schemeId'],
    status: ApplicationStatus.values[json['status'] ?? 0],
    appliedAt: json['appliedAt'] != null ? DateTime.parse(json['appliedAt']) : null,
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    notes: json['notes'] ?? '',
    documentsSubmitted: List<String>.from(json['documentsSubmitted'] ?? []),
  );
}

class SchemeService {
  static final SchemeService _instance = SchemeService._();
  factory SchemeService() => _instance;
  SchemeService._();

  List<SchemeBookmark> _bookmarks = [];
  List<ApplicationRecord> _applications = [];
  List<String> _compareIds = [];

  List<SchemeBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<ApplicationRecord> get applications => List.unmodifiable(_applications);
  List<String> get compareIds => List.unmodifiable(_compareIds);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final bmJson = prefs.getString('scheme_bookmarks');
    if (bmJson != null) {
      final list = jsonDecode(bmJson) as List;
      _bookmarks = list.map((e) => SchemeBookmark.fromJson(e)).toList();
    }

    final appJson = prefs.getString('scheme_applications');
    if (appJson != null) {
      final list = jsonDecode(appJson) as List;
      _applications = list.map((e) => ApplicationRecord.fromJson(e)).toList();
    }

    final cmpJson = prefs.getString('scheme_compare');
    if (cmpJson != null) {
      _compareIds = List<String>.from(jsonDecode(cmpJson));
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scheme_bookmarks', jsonEncode(_bookmarks.map((e) => e.toJson()).toList()));
    await prefs.setString('scheme_applications', jsonEncode(_applications.map((e) => e.toJson()).toList()));
    await prefs.setString('scheme_compare', jsonEncode(_compareIds));
  }

  // ─── Bookmarks ──────────────────────────────────────────────────────────

  bool isBookmarked(String schemeId) => _bookmarks.any((b) => b.schemeId == schemeId);

  Future<void> toggleBookmark(String schemeId) async {
    if (isBookmarked(schemeId)) {
      _bookmarks.removeWhere((b) => b.schemeId == schemeId);
    } else {
      _bookmarks.add(SchemeBookmark(schemeId: schemeId, savedAt: DateTime.now()));
    }
    await _save();
  }

  List<GovernmentScheme> get bookmarkedSchemes {
    return _bookmarks
        .map((b) => SchemeDatabase.schemes.firstWhere((s) => s.id == b.schemeId, orElse: () => SchemeDatabase.schemes.first))
        .toList();
  }

  // ─── Applications ───────────────────────────────────────────────────────

  ApplicationRecord? getApplication(String schemeId) {
    try {
      return _applications.firstWhere((a) => a.schemeId == schemeId);
    } catch (_) {
      return null;
    }
  }

  ApplicationStatus getApplicationStatus(String schemeId) {
    return getApplication(schemeId)?.status ?? ApplicationStatus.notApplied;
  }

  Future<void> updateApplication(String schemeId, ApplicationRecord record) async {
    _applications.removeWhere((a) => a.schemeId == schemeId);
    _applications.add(record);
    await _save();
  }

  Future<void> setApplicationStatus(String schemeId, ApplicationStatus status) async {
    final existing = getApplication(schemeId);
    final record = ApplicationRecord(
      schemeId: schemeId,
      status: status,
      appliedAt: status == ApplicationStatus.applied ? DateTime.now() : existing?.appliedAt,
      deadline: existing?.deadline,
      notes: existing?.notes ?? '',
      documentsSubmitted: existing?.documentsSubmitted ?? [],
    );
    await updateApplication(schemeId, record);
  }

  List<GovernmentScheme> get appliedSchemes {
    return _applications
        .where((a) => a.status != ApplicationStatus.notApplied)
        .map((a) => SchemeDatabase.schemes.firstWhere((s) => s.id == a.schemeId, orElse: () => SchemeDatabase.schemes.first))
        .toList();
  }

  int get appliedCount => _applications.where((a) => a.status == ApplicationStatus.applied).length;
  int get pendingCount => _applications.where((a) => a.status == ApplicationStatus.inProgress).length;

  // ─── Compare ────────────────────────────────────────────────────────────

  bool isComparing(String schemeId) => _compareIds.contains(schemeId);

  Future<void> toggleCompare(String schemeId) async {
    if (_compareIds.contains(schemeId)) {
      _compareIds.remove(schemeId);
    } else {
      if (_compareIds.length < 3) {
        _compareIds.add(schemeId);
      }
    }
    await _save();
  }

  void clearCompare() {
    _compareIds.clear();
    _save();
  }

  List<GovernmentScheme> get compareSchemes {
    return _compareIds
        .map((id) => SchemeDatabase.schemes.firstWhere((s) => s.id == id, orElse: () => SchemeDatabase.schemes.first))
        .toList();
  }

  // ─── Analytics ──────────────────────────────────────────────────────────

  Map<SchemeCategory, int> eligibilityByCategory(CitizenProfile profile) {
    final map = <SchemeCategory, int>{};
    for (final cat in SchemeCategory.values) {
      final count = SchemeDatabase.schemes.where((s) =>
        s.category == cat && SchemeMatcher.scoreScheme(s, profile).score > 0.2
      ).length;
      if (count > 0) map[cat] = count;
    }
    return map;
  }

  int totalEligibleSchemes(CitizenProfile profile) {
    return SchemeDatabase.schemes.where((s) =>
      SchemeMatcher.scoreScheme(s, profile).score > 0.2
    ).length;
  }

  int totalStrongMatches(CitizenProfile profile) {
    return SchemeDatabase.schemes.where((s) =>
      SchemeMatcher.scoreScheme(s, profile).score >= 0.6
    ).length;
  }

  Map<String, int> stateSchemeCount() {
    final map = <String, int>{};
    for (final s in SchemeDatabase.schemes) {
      if (s.level == SchemeLevel.state && s.eligibility.eligibleStates.isNotEmpty) {
        for (final state in s.eligibility.eligibleStates) {
          map[state] = (map[state] ?? 0) + 1;
        }
      }
    }
    return map;
  }
}
