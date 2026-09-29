import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_matcher.dart';
import '../../services/scheme_database.dart';
import '../../services/scheme_service.dart';
import '../../utils/url_launcher_util.dart';
import 'scheme_detail_screen.dart';
import 'profile_setup_screen.dart';
import 'scheme_compare_screen.dart';
import 'scheme_tracker_screen.dart';
import 'scheme_analytics_screen.dart';

/// Redesigned Government Schemes & Rights Screen
/// Implementing the modern Android Minimal Design System from Stitch MCP (Screen ec5f12c875f14910b49fe9e0298f7143).
class GovernmentSchemesEntryScreen extends StatefulWidget {
  const GovernmentSchemesEntryScreen({Key? key}) : super(key: key);

  @override
  State<GovernmentSchemesEntryScreen> createState() =>
      _GovernmentSchemesEntryScreenState();
}

class _GovernmentSchemesEntryScreenState
    extends State<GovernmentSchemesEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Citizen Profile and Service
  CitizenProfile _profile = const CitizenProfile();
  final SchemeService _service = SchemeService();
  List<SchemeMatchResult> _matchedSchemes = [];

  // Search & Filter State
  String _searchQuery = '';
  String _selectedScope = 'All'; // 'All', 'Central', 'State'
  SchemeCategory? _selectedCategory;

  // Inline Eligibility & Benefit Matcher State
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
  bool _filtersAppliedFeedback = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.load().then((_) {
      if (mounted) setState(() {});
    });
    _loadSavedProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
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

          _recomputeMatches();
        });
      } catch (_) {
        _recomputeMatches();
      }
    } else {
      _recomputeMatches();
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
    // If user has a permanent profile and hasn't changed filterState or flags, use it
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
      isFarmer: _filterFarmer,
      isSCST: _filterSCST,
      isDisabled: _filterPwD,
      isWoman: _filterWomen || gender == 'Female',
      isWidow: _filterWidow,
      isMinority: _filterMinority,
      isStudent: _filterStudent,
      isSeniorCitizen: age >= 60,
    );
  }

  void _recomputeMatches() {
    final effectiveProfile = _buildEffectiveMatcherProfile();
    setState(() {
      _matchedSchemes = SchemeMatcher.matchAll(effectiveProfile);
    });
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
      _recomputeMatches();
    });
  }

  void _onApplyMatcherClicked() {
    HapticFeedback.mediumImpact();
    _recomputeMatches();
    setState(() {
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

  void _updateProfileFromSetup(CitizenProfile newProfile) {
    setState(() {
      _profile = newProfile;
      if (newProfile.state.isNotEmpty) _filterState = newProfile.state;
      if (newProfile.occupation != null) {
        _filterOccupation = _mapProfileOccupationToFilter(newProfile.occupation!);
      }
      _filterBPL = newProfile.isBPL;
      _filterFarmer = newProfile.isFarmer;
      _filterSCST = newProfile.isSCST;
      _filterPwD = newProfile.isDisabled;
      _filterMinority = newProfile.isMinority;
      _filterStudent = newProfile.isStudent;
      _filterWomen = newProfile.isWoman;
      _recomputeMatches();
    });
  }

  List<SchemeMatchResult> get _filteredSchemes {
    var list = _matchedSchemes;

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
    var list = _matchedSchemes;
    if (_selectedScope == 'Central') {
      list = list.where((r) => r.scheme.level == SchemeLevel.central).toList();
    } else if (_selectedScope == 'State') {
      list = list.where((r) => r.scheme.level != SchemeLevel.central).toList();
    }
    if (category == null) return list.length;
    return list.where((r) => r.scheme.category == category).length;
  }

  // Helper getters for card highlights
  String _getKeyBenefit(GovernmentScheme scheme) {
    if (scheme.benefits.isNotEmpty) {
      final b = scheme.benefits.first;
      if (b.contains('₹')) {
        final match = RegExp(
          r'₹[\d,]+(?:\s*(?:lakh|crore|per year|/\s*year|/\s*month|/\s*family))?',
          caseSensitive: false,
        ).firstMatch(b);
        if (match != null) return match.group(0)!;
      }
      return b.length > 24 ? '${b.substring(0, 22)}...' : b;
    }
    return 'Financial Support';
  }

  String _getTargetGroup(GovernmentScheme scheme) {
    if (scheme.eligibility.description != null &&
        scheme.eligibility.description!.isNotEmpty) {
      final desc = scheme.eligibility.description!;
      return desc.length > 22 ? '${desc.substring(0, 20)}...' : desc;
    }
    if (scheme.eligibility.occupations.isNotEmpty) {
      return scheme.eligibility.occupations.first;
    }
    if (scheme.eligibility.isFarmerRequired) return 'Farmers';
    if (scheme.eligibility.isStudentRequired) return 'Students';
    if (scheme.eligibility.isBPLRequired) return 'BPL / Antyodaya';
    if (scheme.eligibility.isSCSTRequired) return 'SC / ST Families';
    if (scheme.eligibility.gender == EligibilityGender.female) {
      return 'Women / Girls';
    }
    return 'All Citizens';
  }

  String _getDeliveryMode(GovernmentScheme scheme) {
    final text =
        '${scheme.name} ${scheme.description} ${scheme.plainLanguageSummary}'
            .toLowerCase();
    if (text.contains('cashless')) return 'Cashless';
    if (text.contains('dbt') ||
        text.contains('bank transfer') ||
        text.contains('direct income')) {
      return 'Direct DBT';
    }
    if (text.contains('subsidy')) return 'Subsidy';
    if (text.contains('loan') || text.contains('credit')) return 'Credit / Loan';
    if (text.contains('pension')) return 'Monthly Pension';
    if (text.contains('insurance')) return 'Insurance Cover';
    if (text.contains('scholarship')) return 'Scholarship';
    if (text.contains('pucca house') || text.contains('housing')) return 'Grant';
    return 'Direct DBT';
  }

  String _getCategoryTag(GovernmentScheme scheme) {
    switch (scheme.category) {
      case SchemeCategory.health:
        return 'Health Coverage';
      case SchemeCategory.agriculture:
        return 'Direct Income';
      case SchemeCategory.housing:
        return 'Pucca Housing';
      case SchemeCategory.education:
        return 'Education';
      case SchemeCategory.finance:
        return 'Finance';
      case SchemeCategory.pension:
        return 'Pension';
      case SchemeCategory.insurance:
        return 'Insurance';
      case SchemeCategory.womenChild:
        return 'Women Welfare';
      default:
        return scheme.category.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1628) : const Color(0xFFFAFAFA),
      endDrawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(isDark),

            // Tab Bar Switcher (Discover vs My Profile)
            _buildTabSelector(isDark),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoverTab(isDark),
                  _buildProfileTab(),
                ],
              ),
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

          // Profile Readiness Indicator
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _tabController.animateTo(1);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _profile.hasProfile
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _profile.hasProfile
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _profile.hasProfile
                        ? Icons.check_circle_rounded
                        : Icons.person_add_rounded,
                    size: 13,
                    color: _profile.hasProfile
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _profile.hasProfile
                        ? _profile.name.split(' ').first
                        : 'Set Profile',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _profile.hasProfile
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Open Drawer Button
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                Icons.menu_rounded,
                size: 22,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB SELECTOR ───────────────────────────────────────────────────────
  Widget _buildTabSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF0066CC),
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white70 : const Color(0xFF475569),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Discover Schemes'),
          Tab(text: 'My Profile'),
        ],
      ),
    );
  }

  // ─── DISCOVER SCHEMES TAB ───────────────────────────────────────────────
  Widget _buildDiscoverTab(bool isDark) {
    final filtered = _filteredSchemes;

    return RefreshIndicator(
      onRefresh: () async {
        await _service.load();
        _recomputeMatches();
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Search Box
          _buildSearchBox(isDark),
          const SizedBox(height: 12),

          // 2. Quick Action Utilities Strip (Fixed replacement for overlapping Tools button)
          _buildQuickToolsStrip(isDark),
          const SizedBox(height: 14),

          // 3. Compact Inline Eligibility & Benefit Matcher
          _buildCompactEligibilityFilter(isDark),
          const SizedBox(height: 16),

          // 4. Source & Category Filters
          _buildSourceAndCategoryFilters(isDark),
          const SizedBox(height: 12),

          // 5. Schemes List
          if (filtered.isEmpty)
            _buildEmptyState(isDark)
          else
            ...filtered.map((r) => _buildSchemeCard(r, isDark)),
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
        onChanged: (v) => setState(() => _searchQuery = v),
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
                  onPressed: () => setState(() => _searchQuery = ''),
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

  // ─── 2. QUICK ACTION UTILITIES STRIP ────────────────────────────────────
  Widget _buildQuickToolsStrip(bool isDark) {
    final bookmarksCount = _service.bookmarks.length;
    final pendingCount = _service.pendingCount;
    final compareCount = _service.compareIds.length;

    return Row(
      children: [
        // Saved Schemes
        Expanded(
          child: _buildQuickToolTile(
            isDark: isDark,
            icon: Icons.bookmark_rounded,
            iconBg: isDark ? const Color(0xFF3B2B15) : const Color(0xFFFFFBEB),
            iconColor: const Color(0xFFD97706),
            title: 'Saved',
            subtitle: '$bookmarksCount scheme${bookmarksCount == 1 ? '' : 's'}',
            subtitleColor: const Color(0xFF64748B),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchemeTrackerScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ),
        const SizedBox(width: 8),

        // Tracker
        Expanded(
          child: _buildQuickToolTile(
            isDark: isDark,
            icon: Icons.track_changes_rounded,
            iconBg: isDark ? const Color(0xFF0F2C54) : const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF0066CC),
            title: 'Tracker',
            subtitle: '$pendingCount pending',
            subtitleColor: const Color(0xFFD97706),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchemeTrackerScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ),
        const SizedBox(width: 8),

        // Compare
        Expanded(
          child: _buildQuickToolTile(
            isDark: isDark,
            icon: Icons.compare_arrows_rounded,
            iconBg: isDark ? const Color(0xFF2E1C4E) : const Color(0xFFFAF5FF),
            iconColor: const Color(0xFF7C3AED),
            title: 'Compare',
            subtitle: '$compareCount/3 added',
            subtitleColor: const Color(0xFF64748B),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SchemeCompareScreen()),
              ).then((_) => setState(() {}));
            },
          ),
        ),
        const SizedBox(width: 8),

        // Insights
        Expanded(
          child: _buildQuickToolTile(
            isDark: isDark,
            icon: Icons.bar_chart_rounded,
            iconBg: isDark ? const Color(0xFF0E382A) : const Color(0xFFECFDF5),
            iconColor: const Color(0xFF059669),
            title: 'Insights',
            subtitle: _profile.hasProfile ? 'Personal' : 'High fit',
            subtitleColor: const Color(0xFF059669),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SchemeAnalyticsScreen(profile: _profile),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickToolTile({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. COMPACT INLINE ELIGIBILITY & BENEFIT MATCHER ────────────────────
  Widget _buildCompactEligibilityFilter(bool isDark) {
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
                            _recomputeMatches();
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
                            if (val == 'Farmer / Agri Worker') {
                              _filterFarmer = true;
                            }
                            if (val == 'Student / Youth') {
                              _filterStudent = true;
                            }
                            _recomputeMatches();
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
                            if (val == '< ₹1.5 Lakh (BPL)') {
                              _filterBPL = true;
                            }
                            _recomputeMatches();
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
                            if (val == 'Female (All ages)') {
                              _filterWomen = true;
                            }
                            _recomputeMatches();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Social Category & Vulnerabilities Chips
          Text(
            'SOCIAL CATEGORY & VULNERABILITIES',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
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
                    _recomputeMatches();
                  });
                },
              ),
              _buildFilterToggleChip(
                isDark: isDark,
                label: 'Small / Marginal Farmer (<2 Ha)',
                isSelected: _filterFarmer,
                onTap: () {
                  setState(() {
                    _filterFarmer = !_filterFarmer;
                    _recomputeMatches();
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
                    _recomputeMatches();
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
                    _recomputeMatches();
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
                    _recomputeMatches();
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
                    _recomputeMatches();
                  });
                },
              ),
            ],
          ),

          // Expandable More Filters Toggle
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() {
                _isMoreFiltersExpanded = !_isMoreFiltersExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                              : Icons.add_rounded,
                          size: 14,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'More Filters (Minority, Student, Unorganized)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
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

          if (_isMoreFiltersExpanded) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Minority Community',
                  isSelected: _filterMinority,
                  onTap: () {
                    setState(() {
                      _filterMinority = !_filterMinority;
                      _recomputeMatches();
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
                      _recomputeMatches();
                    });
                  },
                ),
                _buildFilterToggleChip(
                  isDark: isDark,
                  label: 'Daily Wage / Shramik',
                  isSelected:
                      _filterOccupation == 'Daily Wage / Unorganized',
                  onTap: () {
                    setState(() {
                      _filterOccupation =
                          (_filterOccupation == 'Daily Wage / Unorganized')
                              ? 'All Occupations'
                              : 'Daily Wage / Unorganized';
                      _recomputeMatches();
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
                          ? 'Filters Applied (${_filteredSchemes.length} Matches)'
                          : 'Show ${_filteredSchemes.length} Matching Schemes',
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
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Based on official Ministry criteria • No sign-up required',
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
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
                onTap: () => setState(() => _selectedCategory = null),
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
                    onTap: () => setState(() => _selectedCategory = cat),
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
        setState(() => _selectedScope = scopeValue);
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
    final isComparing = _service.isComparing(scheme.id);

    final keyBenefit = _getKeyBenefit(scheme);
    final targetGroup = _getTargetGroup(scheme);
    final deliveryMode = _getDeliveryMode(scheme);
    final categoryTag = _getCategoryTag(scheme);

    final isCentral = scheme.level == SchemeLevel.central;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132238) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SchemeDetailScreen(
                  scheme: scheme,
                  profile: _profile,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Badges + Bookmark Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Level Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCentral
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCentral ? 'CENTRAL SCHEME' : 'STATE SCHEME',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isCentral
                                    ? const Color(0xFF1D4ED8)
                                    : const Color(0xFF7E22CE),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),

                          // Category / Benefit Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryTag,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),

                          // Match percent badge if scored
                          if (result.score > 0.4)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${result.matchPercent.round()}% Match',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Bookmark Button
                    InkWell(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await _service.toggleBookmark(scheme.id);
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: isBookmarked
                              ? const Color(0xFFD97706)
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Scheme Name
                Text(
                  scheme.shortName.isNotEmpty
                      ? '${scheme.name} (${scheme.shortName})'
                      : scheme.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Plain Language Summary
                Text(
                  scheme.plainLanguageSummary,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Key Highlights Row (3 Structured Columns)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Highlight 1: Key Benefit
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KEY BENEFIT',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              keyBenefit,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0066CC),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                      ),

                      // Highlight 2: Target Group
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET GROUP',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              targetGroup,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                      ),

                      // Highlight 3: Mode / Delivery
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF94A3B8),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              deliveryMode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Bottom Action Buttons & Ministry
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.ministry,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Compare icon toggle button
                        InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await _service.toggleCompare(scheme.id);
                            setState(() {});
                            if (_service.compareIds.length == 3 &&
                                _service.isComparing(scheme.id)) {
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SchemeCompareScreen(),
                                  ),
                                ).then((_) => setState(() {}));
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isComparing
                                  ? const Color(0xFFFAF5FF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isComparing
                                    ? const Color(0xFF7C3AED)
                                    : (isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Icon(
                              isComparing
                                  ? Icons.compare_arrows_rounded
                                  : Icons.compare_arrows_outlined,
                              size: 16,
                              color: isComparing
                                  ? const Color(0xFF7C3AED)
                                  : (isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        const Spacer(),

                        // Check Rules (View Details)
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SchemeDetailScreen(
                                  scheme: scheme,
                                  profile: _profile,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Check Rules',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Apply Online
                        ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final url = scheme.effectiveApplyUrl;
                            if (url.isNotEmpty) {
                              await UrlLauncherUtil.openUrl(context, url);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SchemeDetailScreen(
                                    scheme: scheme,
                                    profile: _profile,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066CC),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            minimumSize: Size.zero,
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Online',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  // ─── PROFILE TAB ────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return ProfileSetupScreen(
      initialProfile: _profile,
      onProfileSaved: _updateProfileFromSetup,
    );
  }

  // ─── DRAWER ─────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F1E36) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066CC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Government Schemes',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildDrawerTile(
              icon: Icons.search_rounded,
              title: 'Discover Schemes',
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              },
            ),
            _buildDrawerTile(
              icon: Icons.person_rounded,
              title: 'My Profile',
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              },
            ),
            const Divider(),
            _buildDrawerTile(
              icon: Icons.bookmark_rounded,
              title: 'Saved Schemes',
              badge: '${_service.bookmarks.length}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SchemeTrackerScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            _buildDrawerTile(
              icon: Icons.track_changes_rounded,
              title: 'Application Tracker',
              badge: '${_service.pendingCount}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SchemeTrackerScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            _buildDrawerTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Compare Schemes',
              badge: '${_service.compareIds.length}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SchemeCompareScreen()),
                ).then((_) => setState(() {}));
              },
            ),
            _buildDrawerTile(
              icon: Icons.analytics_rounded,
              title: 'Analytics & Insights',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SchemeAnalyticsScreen(profile: _profile),
                  ),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${SchemeDatabase.schemes.length} schemes across India',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0066CC),
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: Color(0xFF94A3B8)),
        ],
      ),
      onTap: onTap,
    );
  }
}
