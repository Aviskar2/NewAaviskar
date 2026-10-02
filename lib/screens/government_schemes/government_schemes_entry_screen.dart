import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_matcher.dart';
import '../../services/scheme_database.dart';
import '../../services/scheme_service.dart';
import 'scheme_detail_screen.dart';
import 'scheme_tracker_screen.dart';

/// Redesigned Government Schemes & Rights Screen
/// Implementing the modern Android Minimal Design System from Stitch MCP (Screen ec5f12c875f14910b49fe9e0298f7143).
class GovernmentSchemesEntryScreen extends StatefulWidget {
  const GovernmentSchemesEntryScreen({super.key});

  @override
  State<GovernmentSchemesEntryScreen> createState() =>
      _GovernmentSchemesEntryScreenState();
}

class _GovernmentSchemesEntryScreenState
    extends State<GovernmentSchemesEntryScreen> {
  // Citizen Profile and Service
  CitizenProfile _profile = const CitizenProfile();
  final SchemeService _service = SchemeService();
  List<SchemeMatchResult> _appliedSchemes = [];

  // Progressive Loading State
  int _displayedBatchCount = 10;
  bool _isLoadingMore = false;

  // Search & Filter State
  String _searchQuery = '';
  String _selectedScope = 'All'; // 'All', 'Central', 'State'
  SchemeCategory? _selectedCategory;

  // Inline Eligibility & Benefit Matcher State (Selection State)
  String _filterState = 'All States';
  String _filterOccupation = 'All Occupations';
  String _filterIncome = 'Any Income';
  String _filterAgeGender = 'Any';

  // Vulnerability & Special Category Flags
  bool _filterBPL = false;
  bool _filterFarmer = false;
  bool _filterSCST = false;
  bool _filterOBC = false;
  bool _filterPwD = false;
  bool _filterWomen = false;
  bool _filterWidow = false;
  bool _filterMinority = false;
  bool _filterStudent = false;

  bool _isMoreFiltersExpanded = false;
  bool _isMatcherExpanded = false;
  bool _filtersAppliedFeedback = false;

  final ScrollController _scrollController = ScrollController();

  int get _activeMoreFiltersCount {
    int count = 0;
    if (_filterBPL) count++;
    if (_filterFarmer) count++;
    if (_filterSCST) count++;
    if (_filterOBC) count++;
    if (_filterPwD) count++;
    if (_filterWomen || _filterWidow) count++;
    if (_filterMinority) count++;
    if (_filterStudent) count++;
    if (_filterOccupation == 'Daily Wage / Unorganized') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _appliedSchemes = _computeMatchingSchemes();
    _service.load().then((_) {
      if (mounted) setState(() {});
    });
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMoreSchemes();
    }
  }

  void _loadMoreSchemes() {
    final total = _filteredSchemes.length;
    if (_isLoadingMore || _displayedBatchCount >= total) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _displayedBatchCount = (_displayedBatchCount + 10).clamp(0, total);
        _isLoadingMore = false;
      });
    });
  }

  void _resetPagination() {
    _displayedBatchCount = 10;
    _isLoadingMore = false;
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('citizen_profile');
    if (jsonStr != null && mounted) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final profile = CitizenProfile(
          name: data['name'] ?? '',
          age: data['age'] ?? 0,
          gender:
              (data['gender'] == 'Female' || data['gender'] == 'Transgender')
                  ? data['gender']
                  : 'Male',
          annualIncome: (data['annualIncome'] ?? 0).toDouble(),
          state: data['state'] ?? '',
          occupation: data['occupation'],
          isBPL: data['isBPL'] ?? false,
          isSCST: data['isSCST'] ?? false,
          isStudent: data['isStudent'] ?? false,
          isFarmer: data['isFarmer'] ?? false,
          isDisabled: data['isDisabled'] ?? false,
          isSeniorCitizen: data['isSeniorCitizen'] ?? false,
          isWidow: data['isWidow'] ?? false,
          isMinority: data['isMinority'] ?? false,
          isWoman: (data['gender'] ?? '') == 'Female',
        );

        setState(() {
          _profile = profile;
          // Pre-populate matcher filters from saved profile if available
          if (profile.state.isNotEmpty) {
            _filterState = profile.state;
          }
          if (profile.occupation != null && profile.occupation!.isNotEmpty) {
            _filterOccupation = _mapProfileOccupationToFilter(profile.occupation!);
          }
          if (profile.annualIncome > 0) {
            _filterIncome = _mapIncomeToFilter(profile.annualIncome);
          }
          if (profile.gender == 'Female') {
            _filterAgeGender = 'Female (All ages)';
            _filterWomen = true;
          }
          _filterBPL = profile.isBPL;
          _filterFarmer = profile.isFarmer;
          _filterSCST = profile.isSCST;
          _filterPwD = profile.isDisabled;
          _filterMinority = profile.isMinority;
          _filterStudent = profile.isStudent;

          _appliedSchemes = _computeMatchingSchemes();
          _resetPagination();
        });
      } catch (_) {
        setState(() {
          _appliedSchemes = _computeMatchingSchemes();
          _resetPagination();
        });
      }
    } else {
      setState(() {
        _appliedSchemes = _computeMatchingSchemes();
        _resetPagination();
      });
    }
  }

  String _mapProfileOccupationToFilter(String occ) {
    final o = occ.toLowerCase();
    if (o.contains('farm') || o.contains('agri')) return 'Farmer / Agri Worker';
    if (o.contains('student') || o.contains('youth')) return 'Student / Youth';
    if (o.contains('business') || o.contains('msme')) return 'Small Business / MSME';
    if (o.contains('daily') || o.contains('wage') || o.contains('labor')) {
      return 'Daily Wage / Unorganized';
    }
    if (o.contains('salaried') || o.contains('pension')) return 'Salaried / Pensioner';
    return 'All Occupations';
  }

  String _mapIncomeToFilter(double inc) {
    if (inc <= 150000) return '< ₹1.5 Lakh (BPL)';
    if (inc <= 300000) return '₹1.5L – ₹3.0 Lakh';
    if (inc <= 800000) return '₹3.0L – ₹8.0 Lakh';
    return '> ₹8.0 Lakh';
  }

  CitizenProfile _buildEffectiveMatcherProfile() {
    int age = _profile.age > 0 ? _profile.age : 35;
    String gender = _profile.gender;

    if (_filterAgeGender == 'Male (All ages)') {
      gender = 'Male';
    } else if (_filterAgeGender == 'Female (All ages)') {
      gender = 'Female';
    } else if (_filterAgeGender == 'Senior Citizen (60+)') {
      age = 65;
    } else if (_filterAgeGender == 'Youth (18–35 yrs)') {
      age = 24;
    } else if (_filterAgeGender == 'Child (<18 yrs)') {
      age = 12;
    }

    double income = _profile.annualIncome;
    if (_filterIncome == '< ₹1.5 Lakh (BPL)') {
      income = 100000;
    } else if (_filterIncome == '₹1.5L – ₹3.0 Lakh') {
      income = 250000;
    } else if (_filterIncome == '₹3.0L – ₹8.0 Lakh') {
      income = 500000;
    } else if (_filterIncome == '> ₹8.0 Lakh') {
      income = 1000000;
    }

    final state = (_filterState == 'All States') ? '' : _filterState;
    final occupation =
        (_filterOccupation == 'All Occupations') ? null : _filterOccupation;

    return CitizenProfile(
      name: _profile.name.isNotEmpty ? _profile.name : 'Citizen',
      age: age,
      gender: gender,
      annualIncome: income,
      state: state,
      occupation: occupation,
      isBPL: _filterBPL,
      isFarmer: _filterFarmer || _filterOccupation == 'Farmer / Agri Worker',
      isSCST: _filterSCST,
      isDisabled: _filterPwD,
      isWoman: _filterWomen || gender == 'Female',
      isWidow: _filterWidow,
      isMinority: _filterMinority,
      isStudent: _filterStudent || _filterOccupation == 'Student / Youth',
      isSeniorCitizen: age >= 60,
    );
  }

  /// Evaluates whether a [scheme] satisfies all currently selected criteria.
  bool _isSchemeEligible(GovernmentScheme scheme) {
    final elig = scheme.eligibility;

    // 1. STATE / UT FILTER
    if (_filterState != 'All States') {
      if (elig.eligibleStates.isNotEmpty) {
        if (!elig.eligibleStates.contains(_filterState)) {
          return false;
        }
      } else if (scheme.level == SchemeLevel.state) {
        if (scheme.stateCode != null && scheme.stateCode != 'IN') {
          return false;
        }
      }
    }

    // 2. AGE & GENDER FILTER
    if (_filterAgeGender == 'Male (All ages)') {
      if (elig.gender == EligibilityGender.female) return false;
      if (elig.isWidowRequired) return false;
    } else if (_filterAgeGender == 'Female (All ages)') {
      if (elig.gender == EligibilityGender.male) return false;
    } else if (_filterAgeGender == 'Senior Citizen (60+)') {
      if (elig.maxAge != null && elig.maxAge! < 60) return false;
      if (elig.minAge != null && elig.minAge! > 60) return false;
    } else if (_filterAgeGender == 'Youth (18–35 yrs)') {
      if (elig.minAge != null && elig.minAge! > 35) return false;
      if (elig.maxAge != null && elig.maxAge! < 18) return false;
    } else if (_filterAgeGender == 'Child (<18 yrs)') {
      if (elig.minAge != null && elig.minAge! >= 18) return false;
    }

    // 3. OCCUPATION FILTER
    if (_filterOccupation == 'Student / Youth') {
      if (elig.isFarmerRequired && !elig.isStudentRequired) return false;
      final bool matchesStudent = elig.isStudentRequired ||
          scheme.category == SchemeCategory.education ||
          elig.occupations.any((o) {
            final lower = o.toLowerCase();
            return lower.contains('student') || lower.contains('youth');
          }) ||
          (elig.occupationRequired != null &&
              elig.occupationRequired!.toLowerCase().contains('student'));
      if (!matchesStudent) return false;
    } else if (_filterOccupation == 'Farmer / Agri Worker') {
      if (elig.isStudentRequired && !elig.isFarmerRequired) return false;
      final bool matchesFarmer = elig.isFarmerRequired ||
          scheme.category == SchemeCategory.agriculture ||
          elig.occupations.any((o) {
            final lower = o.toLowerCase();
            return lower.contains('farm') || lower.contains('agri');
          }) ||
          (elig.occupationRequired != null &&
              elig.occupationRequired!.toLowerCase().contains('farm'));
      if (!matchesFarmer) return false;
    } else if (_filterOccupation == 'Small Business / MSME') {
      if (elig.isFarmerRequired || elig.isStudentRequired) return false;
      final bool matchesBusiness = scheme.category == SchemeCategory.finance ||
          scheme.category == SchemeCategory.employment ||
          elig.occupations.any((o) {
            final lower = o.toLowerCase();
            return lower.contains('business') ||
                lower.contains('msme') ||
                lower.contains('artisan') ||
                lower.contains('vendor') ||
                lower.contains('entrepreneur');
          }) ||
          (elig.occupationRequired != null &&
              (elig.occupationRequired!.toLowerCase().contains('artisan') ||
                  elig.occupationRequired!.toLowerCase().contains('business'))) ||
          scheme.id.contains('mudra') ||
          scheme.id.contains('pmegp') ||
          scheme.id.contains('svanidhi') ||
          scheme.id.contains('vishwakarma');
      if (!matchesBusiness) return false;
    } else if (_filterOccupation == 'Daily Wage / Unorganized') {
      if (elig.isFarmerRequired || elig.isStudentRequired) return false;
      final bool matchesWorker = elig.occupations.any((o) {
            final lower = o.toLowerCase();
            return lower.contains('wage') ||
                lower.contains('unorganized') ||
                lower.contains('worker') ||
                lower.contains('labor');
          }) ||
          (elig.occupationRequired != null &&
              (elig.occupationRequired!.toLowerCase().contains('worker') ||
                  elig.occupationRequired!.toLowerCase().contains('artisan') ||
                  elig.occupationRequired!.toLowerCase().contains('fisherman'))) ||
          scheme.id.contains('e_shram') ||
          scheme.id.contains('nrega') ||
          scheme.id.contains('pm_kmy') ||
          scheme.id.contains('pmsym');
      if (!matchesWorker) return false;
    } else if (_filterOccupation == 'Salaried / Pensioner') {
      if (elig.isFarmerRequired || elig.isStudentRequired) return false;
      final bool matchesPension = scheme.category == SchemeCategory.pension ||
          scheme.id.contains('apy') ||
          scheme.id.contains('epfo') ||
          scheme.id.contains('nps');
      if (!matchesPension) return false;
    }

    // 4. ANNUAL INCOME FILTER
    if (_filterIncome == '< ₹1.5 Lakh (BPL)') {
      if (elig.maxAnnualIncome != null && elig.maxAnnualIncome! < 50000) {
        return false;
      }
    } else if (_filterIncome == '₹1.5L – ₹3.0 Lakh') {
      if (elig.isBPLRequired) return false;
      if (elig.maxAnnualIncome != null && elig.maxAnnualIncome! < 150000) {
        return false;
      }
    } else if (_filterIncome == '₹3.0L – ₹8.0 Lakh') {
      if (elig.isBPLRequired) return false;
      if (elig.maxAnnualIncome != null && elig.maxAnnualIncome! < 300000) {
        return false;
      }
    } else if (_filterIncome == '> ₹8.0 Lakh') {
      if (elig.isBPLRequired) return false;
      if (elig.maxAnnualIncome != null && elig.maxAnnualIncome! < 800000) {
        return false;
      }
    }

    // 5. RESTRICTIVE ELIGIBILITY CONSTRAINTS (SC/ST, PwD, Widow, Minority)
    if (elig.isSCSTRequired && !_filterSCST) return false;
    if (elig.isDisabledRequired && !_filterPwD) return false;
    if (elig.isMinorityRequired && !_filterMinority) return false;
    if (elig.isWidowRequired && !_filterWidow) return false;

    // 6. EXPLICIT MORE FILTERS TOGGLES
    if (_filterBPL &&
        !(elig.isBPLRequired ||
            elig.categories.contains('BPL') ||
            (elig.maxAnnualIncome != null && elig.maxAnnualIncome! <= 200000))) {
      return false;
    }
    if (_filterFarmer &&
        !(elig.isFarmerRequired || scheme.category == SchemeCategory.agriculture)) {
      return false;
    }
    if (_filterSCST &&
        !(elig.isSCSTRequired ||
            elig.categories.any((c) =>
                c.toUpperCase().contains('SC') ||
                c.toUpperCase().contains('ST')))) {
      return false;
    }
    if (_filterOBC &&
        !elig.categories.any((c) => c.toUpperCase().contains('OBC'))) {
      return false;
    }
    if (_filterPwD && !elig.isDisabledRequired) {
      return false;
    }
    if ((_filterWomen || _filterWidow) &&
        !(elig.gender == EligibilityGender.female || elig.isWidowRequired)) {
      return false;
    }
    if (_filterMinority && !elig.isMinorityRequired) {
      return false;
    }
    if (_filterStudent &&
        !(elig.isStudentRequired || scheme.category == SchemeCategory.education)) {
      return false;
    }

    return true;
  }

  /// Runs complete filtering operation against the full [SchemeDatabase.schemes] dataset.
  List<SchemeMatchResult> _computeMatchingSchemes() {
    final results = <SchemeMatchResult>[];
    final effectiveProfile = _buildEffectiveMatcherProfile();

    for (final scheme in SchemeDatabase.schemes) {
      if (_isSchemeEligible(scheme)) {
        final scoreResult = SchemeMatcher.scoreScheme(scheme, effectiveProfile);
        results.add(SchemeMatchResult(
          scheme: scheme,
          score: scoreResult.score > 0 ? scoreResult.score : 0.85,
          reasons: scoreResult.reasons.isNotEmpty
              ? scoreResult.reasons
              : ['Meets all selected filter criteria'],
        ));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Fast count calculation against the full scheme dataset for button display.
  int _computeMatchingSchemesCount() {
    int count = 0;
    for (final scheme in SchemeDatabase.schemes) {
      if (_isSchemeEligible(scheme)) {
        count++;
      }
    }
    return count;
  }

  void _resetAllFilters() {
    HapticFeedback.lightImpact();
    setState(() {
      _searchQuery = '';
      _selectedScope = 'All';
      _selectedCategory = null;
      _filterState = 'All States';
      _filterOccupation = 'All Occupations';
      _filterIncome = 'Any Income';
      _filterAgeGender = 'Any';
      _filterBPL = false;
      _filterFarmer = false;
      _filterSCST = false;
      _filterOBC = false;
      _filterPwD = false;
      _filterWomen = false;
      _filterWidow = false;
      _filterMinority = false;
      _filterStudent = false;
      _appliedSchemes = _computeMatchingSchemes();
      _resetPagination();
    });
  }

  void _onApplyMatcherClicked() {
    HapticFeedback.mediumImpact();
    setState(() {
      _appliedSchemes = _computeMatchingSchemes();
      _resetPagination();
      _filtersAppliedFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _filtersAppliedFeedback = false;
        });
      }
    });
  }


  List<SchemeMatchResult> get _filteredSchemes {
    var list = _appliedSchemes;

    // Scope filter (All, Central, State)
    if (_selectedScope == 'Central') {
      list = list.where((r) => r.scheme.level == SchemeLevel.central).toList();
    } else if (_selectedScope == 'State') {
      list = list.where((r) => r.scheme.level != SchemeLevel.central).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      list = list.where((r) => r.scheme.category == _selectedCategory).toList();
    }

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((r) {
        final s = r.scheme;
        return s.name.toLowerCase().contains(q) ||
            s.shortName.toLowerCase().contains(q) ||
            s.ministry.toLowerCase().contains(q) ||
            s.plainLanguageSummary.toLowerCase().contains(q) ||
            s.benefits.any((b) => b.toLowerCase().contains(q));
      }).toList();
    }

    return list;
  }

  // Count helper for category chips
  int _countForCategory(SchemeCategory? category) {
    var list = _appliedSchemes;
    if (_selectedScope == 'Central') {
      list = list.where((r) => r.scheme.level == SchemeLevel.central).toList();
    } else if (_selectedScope == 'State') {
      list = list.where((r) => r.scheme.level != SchemeLevel.central).toList();
    }
    if (category == null) return list.length;
    return list.where((r) => r.scheme.category == category).length;
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(isDark),

            // Discover Schemes Body
            Expanded(
              child: _buildDiscoverTab(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP APP BAR ────────────────────────────────────────────────────────
  Widget _buildTopAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E36) : const Color(0xFFFAFAFA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Gov Pillar Icon Badge
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Color(0xFF0066CC),
              size: 18,
            ),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              'Government Schemes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Saved schemes
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchemeTrackerScreen()),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_rounded,
                    size: 13,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Saved schemes',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFBFDBFE)
                          : const Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── DISCOVER SCHEMES TAB ───────────────────────────────────────────────
  Widget _buildDiscoverTab(bool isDark) {
    final filtered = _filteredSchemes;
    final displayedSchemes = filtered.take(_displayedBatchCount).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _service.load();
        setState(() {
          _appliedSchemes = _computeMatchingSchemes();
        });
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Search Box
          _buildSearchBox(isDark),
          const SizedBox(height: 12),

          // Optional eligibility matching stays available without crowding the list.
          _buildCompactEligibilityFilter(isDark),
          const SizedBox(height: 12),

          // 4. Source & Category Filters
          _buildSourceAndCategoryFilters(isDark),
          const SizedBox(height: 12),

          // 5. Schemes List (Progressive Loading in Batches of 5)
          if (filtered.isEmpty)
            _buildEmptyState(isDark)
          else ...[
            ...displayedSchemes.map((r) => _buildSchemeCard(r, isDark)),

            // Progressive Loading Indicator or Status
            if (_isLoadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0066CC)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading more schemes...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (displayedSchemes.length < filtered.length)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Center(
                  child: InkWell(
                    onTap: _loadMoreSchemes,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
                        'Showing ${displayedSchemes.length} of ${filtered.length} schemes • Scroll or tap for more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (filtered.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Center(
                  child: Text(
                    'All ${filtered.length} matching schemes loaded',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ─── 1. SEARCH BOX ──────────────────────────────────────────────────────
  Widget _buildSearchBox(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() {
          _searchQuery = v;
          _resetPagination();
        }),
        style: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search 147+ schemes (e.g. Kisan, Health, Pension)...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () => setState(() {
                    _searchQuery = '';
                    _resetPagination();
                  }),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      ),
    );
  }

  // ─── 3. COMPACT INLINE ELIGIBILITY & BENEFIT MATCHER ────────────────────
  Widget _buildCompactEligibilityFilter(bool isDark) {
    if (!_isMatcherExpanded) {
      return InkWell(
        onTap: () => setState(() => _isMatcherExpanded = true),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132238) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0066CC)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _activeMoreFiltersCount > 0
                      ? 'Personalize results · $_activeMoreFiltersCount filters active'
                      : 'Personalize results',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded,
                  size: 20, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066CC).withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title + Reset All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF0066CC),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Eligibility & Benefit Matcher',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _resetAllFilters,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Reset All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0066CC),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Collapse filters',
                onPressed: () => setState(() => _isMatcherExpanded = false),
                icon: const Icon(Icons.expand_less_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Parameters Row 1: State / UT & Occupation
          Row(
            children: [
              // State Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATE / UT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdownField(
                      isDark: isDark,
                      value: _filterState,
                      items: [
                        'All States',
                        ...SchemeDatabase.indianStates,
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filterState = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Occupation Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OCCUPATION',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdownField(
                      isDark: isDark,
                      value: _filterOccupation,
                      items: const [
                        'All Occupations',
                        'Farmer / Agri Worker',
                        'Student / Youth',
                        'Small Business / MSME',
                        'Daily Wage / Unorganized',
                        'Salaried / Pensioner',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filterOccupation = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Additional Key Filters Row 2: Annual Income & Age/Gender
          Row(
            children: [
              // Annual Income
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANNUAL INCOME',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdownField(
                      isDark: isDark,
                      value: _filterIncome,
                      items: const [
                        'Any Income',
                        '< ₹1.5 Lakh (BPL)',
                        '₹1.5L – ₹3.0 Lakh',
                        '₹3.0L – ₹8.0 Lakh',
                        '> ₹8.0 Lakh',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filterIncome = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Age & Gender
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGE & GENDER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDropdownField(
                      isDark: isDark,
                      value: _filterAgeGender,
                      items: const [
                        'Any',
                        'Male (All ages)',
                        'Female (All ages)',
                        'Senior Citizen (60+)',
                        'Youth (18–35 yrs)',
                        'Child (<18 yrs)',
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filterAgeGender = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Expandable More Filters Toggle (Contains Social Category & Vulnerabilities)
          InkWell(
            onTap: () {
              setState(() {
                _isMoreFiltersExpanded = !_isMoreFiltersExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          _isMoreFiltersExpanded
                              ? Icons.remove_rounded
                              : Icons.tune_rounded,
                          size: 15,
                          color: const Color(0xFF0066CC),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'More Filters (Social Category & Vulnerabilities)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF334155),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_activeMoreFiltersCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_activeMoreFiltersCount active',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0066CC),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _isMoreFiltersExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),

          // Expanded More Filters: All Social Categories & Vulnerabilities Chips
          if (_isMoreFiltersExpanded) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'BPL / Antyodaya',
                  isSelected: _filterBPL,
                  onTap: () {
                    setState(() {
                      _filterBPL = !_filterBPL;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Small / Marginal Farmer (≤2 Ha)',
                  isSelected: _filterFarmer,
                  onTap: () {
                    setState(() {
                      _filterFarmer = !_filterFarmer;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'SC / ST',
                  isSelected: _filterSCST,
                  onTap: () {
                    setState(() {
                      _filterSCST = !_filterSCST;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'OBC',
                  isSelected: _filterOBC,
                  onTap: () {
                    setState(() {
                      _filterOBC = !_filterOBC;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Person with Disability (PwD)',
                  isSelected: _filterPwD,
                  onTap: () {
                    setState(() {
                      _filterPwD = !_filterPwD;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Women / Widow',
                  isSelected: _filterWomen || _filterWidow,
                  onTap: () {
                    setState(() {
                      _filterWomen = !_filterWomen;
                      _filterWidow = !_filterWidow;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Minority Community',
                  isSelected: _filterMinority,
                  onTap: () {
                    setState(() {
                      _filterMinority = !_filterMinority;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Student / Enrolled',
                  isSelected: _filterStudent,
                  onTap: () {
                    setState(() {
                      _filterStudent = !_filterStudent;
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Daily Wage / Unorganized',
                  isSelected:
                      _filterOccupation == 'Daily Wage / Unorganized',
                  onTap: () {
                    setState(() {
                      _filterOccupation =
                          (_filterOccupation == 'Daily Wage / Unorganized')
                              ? 'All Occupations'
                              : 'Daily Wage / Unorganized';
                    });
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Primary Match Action Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _onApplyMatcherClicked,
              style: ElevatedButton.styleFrom(
                backgroundColor: _filtersAppliedFeedback
                    ? const Color(0xFF059669)
                    : const Color(0xFF0066CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _filtersAppliedFeedback
                        ? Icons.check_circle_rounded
                        : Icons.filter_alt_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _filtersAppliedFeedback
                          ? 'Filters Applied (${_appliedSchemes.length} Matches)'
                          : 'Show ${_computeMatchingSchemesCount()} Matching Schemes',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required bool isDark,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = items.contains(value) ? value : items.first;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          onChanged: onChanged,
          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(
                e,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterToggleChip({
    required bool isDark,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0066CC)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: Color(0xFF0066CC),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0052A3))
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 4. SOURCE AND CATEGORY FILTERS ─────────────────────────────────────
  Widget _buildSourceAndCategoryFilters(bool isDark) {
    final allSchemesCount = SchemeDatabase.schemes.length;
    final centralCount = SchemeDatabase.schemes
        .where((s) => s.level == SchemeLevel.central)
        .length;
    final stateCount = SchemeDatabase.schemes
        .where((s) => s.level != SchemeLevel.central)
        .length;

    final categories = SchemeCategory.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scope Pills Row
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildScopePill('All', 'All ($allSchemesCount)', isDark),
                    _buildScopePill('Central', 'Central ($centralCount)', isDark),
                    _buildScopePill('State', 'State ($stateCount)', isDark),
                  ],
                ),
              ),
            ),
            Text(
              '${_filteredSchemes.length} schemes found',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Horizontal Category Chips
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All" Category Chip
              _buildCategoryChip(
                isDark: isDark,
                emoji: '',
                label: 'All',
                count: _countForCategory(null),
                isSelected: _selectedCategory == null,
                onTap: () => setState(() {
                  _selectedCategory = null;
                  _resetPagination();
                }),
              ),
              const SizedBox(width: 6),

              // Individual Categories
              ...categories.map((cat) {
                final count = _countForCategory(cat);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildCategoryChip(
                    isDark: isDark,
                    emoji: cat.emoji,
                    label: cat.label,
                    count: count,
                    isSelected: _selectedCategory == cat,
                    onTap: () => setState(() {
                      _selectedCategory = cat;
                      _resetPagination();
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScopePill(String scopeValue, String label, bool isDark) {
    final isSelected = _selectedScope == scopeValue;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedScope = scopeValue;
          _resetPagination();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F1E36) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF0066CC)
                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required bool isDark,
    required String emoji,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0066CC)
              : (isDark ? const Color(0xFF132238) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0066CC)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 5. SCHEME CARD (HIGH-VALUE SCHEMES LIST) ───────────────────────────
  Widget _buildSchemeCard(SchemeMatchResult result, bool isDark) {
    final scheme = result.scheme;
    final isBookmarked = _service.isBookmarked(scheme.id);
    final isCentral = scheme.level == SchemeLevel.central;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF475569);

    void openDetails() {
      HapticFeedback.lightImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SchemeDetailScreen(scheme: scheme, profile: _profile),
        ),
      ).then((_) {
        if (mounted) setState(() {});
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: openDetails,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.category.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        scheme.shortName.isNotEmpty
                            ? '${scheme.name} (${scheme.shortName})'
                            : scheme.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                      padding: EdgeInsets.zero,
                      tooltip: isBookmarked ? 'Remove saved scheme' : 'Save scheme',
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _service.toggleBookmark(scheme.id);
                        if (mounted) setState(() {});
                      },
                      icon: Icon(
                        isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        size: 20,
                        color: isBookmarked
                            ? const Color(0xFFD97706)
                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  scheme.plainLanguageSummary,
                  style: TextStyle(fontSize: 12, height: 1.4, color: mutedColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _schemeTag(
                      isCentral ? 'Central' : 'State',
                      isCentral
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF7E22CE),
                      isCentral
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFF3E8FF),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _schemeTag(
                        scheme.category.label,
                        const Color(0xFFB45309),
                        const Color(0xFFFFFBEB),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (result.score > 0.4)
                      Text('${result.matchPercent.round()}% match',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          )),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('View scheme details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0066CC),
                        )),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF0066CC)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _schemeTag(String label, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: foreground)),
    );
  }

  // ─── EMPTY STATE ────────────────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 28,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No schemes match criteria',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try resetting your filters or modifying search keywords.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _resetAllFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Reset All Filters',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
