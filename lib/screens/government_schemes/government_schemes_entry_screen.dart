import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/government_scheme_model.dart';
import '../../services/scheme_matcher.dart';
import '../../services/scheme_database.dart';
import '../../services/scheme_service.dart';
import 'scheme_detail_screen.dart';
import 'profile_setup_screen.dart';
import 'scheme_compare_screen.dart';
import 'scheme_tracker_screen.dart';
import 'scheme_analytics_screen.dart';

class GovernmentSchemesEntryScreen extends StatefulWidget {
  const GovernmentSchemesEntryScreen({Key? key}) : super(key: key);

  @override
  State<GovernmentSchemesEntryScreen> createState() => _GovernmentSchemesEntryScreenState();
}

class _GovernmentSchemesEntryScreenState extends State<GovernmentSchemesEntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CitizenProfile _profile = const CitizenProfile();
  List<SchemeMatchResult> _matchedSchemes = [];
  SchemeCategory? _selectedCategory;
  String _selectedLevel = 'All';
  String _searchQuery = '';

  final _service = SchemeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service.load();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('citizen_profile');
    if (json != null && mounted) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final profile = CitizenProfile(
        name: data['name'] ?? '',
        age: data['age'] ?? 0,
        gender: (data['gender'] == 'Female' || data['gender'] == 'Transgender')
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
        _matchedSchemes = SchemeMatcher.matchAll(_profile);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshMatches() {
    setState(() {
      _matchedSchemes = SchemeMatcher.matchAll(_profile);
    });
  }

  void _updateProfile(CitizenProfile newProfile) {
    setState(() {
      _profile = newProfile;
      _refreshMatches();
    });
  }

  List<SchemeMatchResult> get _filteredSchemes {
    var results = _matchedSchemes;

    if (_selectedCategory != null) {
      results = results.where((r) => r.scheme.category == _selectedCategory).toList();
    }

    if (_selectedLevel != 'All') {
      final isCentral = _selectedLevel == 'Central';
      results = results.where((r) =>
        isCentral ? r.scheme.level == SchemeLevel.central : r.scheme.level != SchemeLevel.central
      ).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      results = results.where((r) =>
        r.scheme.name.toLowerCase().contains(q) ||
        r.scheme.shortName.toLowerCase().contains(q) ||
        r.scheme.ministry.toLowerCase().contains(q) ||
        r.scheme.plainLanguageSummary.toLowerCase().contains(q)
      ).toList();
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: _buildFAB(),
      endDrawer: _buildDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A1628), const Color(0xFF0D1F3C)]
                : [const Color(0xFFEEF4FF), const Color(0xFFF0F7FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(6, 12, 14, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.account_balance_rounded,
                                    color: Color(0xFF2563EB), size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Government Schemes',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _profile.hasProfile
                                ? '${_matchedSchemes.where((m) => m.score > 0.3).length} of ${SchemeDatabase.schemes.length} schemes match your profile'
                                : '${SchemeDatabase.schemes.length} central & state schemes — set profile for personalized matches',
                            style: TextStyle(
                                fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildProfileBadge(),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12.5),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 12.5),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: 'Discover Schemes'),
                    Tab(text: 'My Profile'),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSchemesTab(),
                    _buildProfileTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBadge() {
    return GestureDetector(
      onTap: () => _tabController.animateTo(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _profile.hasProfile
              ? const Color(0xFF16A34A).withValues(alpha: 0.12)
              : const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _profile.hasProfile
                ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                : const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _profile.hasProfile ? Icons.person_rounded : Icons.person_add_rounded,
              size: 14,
              color: _profile.hasProfile
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 5),
            Text(
              _profile.hasProfile ? _profile.name.split(' ').first : 'Set Profile',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _profile.hasProfile
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Schemes Tab ────────────────────────────────────────────────────────
  Widget _buildSchemesTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredSchemes;
    final topMatches = _profile.hasProfile
        ? _matchedSchemes.where((m) => m.score >= 0.6).toList()
        : <SchemeMatchResult>[];

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search schemes (e.g. farmer, health, pension...)',
              hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Level Filter (Central / State / All)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _buildLevelChip('All'),
              const SizedBox(width: 8),
              _buildLevelChip('Central'),
              const SizedBox(width: 8),
              _buildLevelChip('State'),
              const Spacer(),
              if (_profile.hasProfile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Text(
                        '${topMatches.length} top matches',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Category Filter Chips
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              _buildCategoryChip('All', null),
              ...SchemeCategory.values.map((c) => _buildCategoryChip(c.emoji, c)),
            ],
          ),
        ),

        // Top Matches Section
        if (topMatches.isNotEmpty && _selectedCategory == null && _selectedLevel == 'All' && _searchQuery.isEmpty)
          _buildTopMatchesSection(topMatches),

        // Results Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Text(
                '${filtered.length} scheme${filtered.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_profile.hasProfile && !_filteredSchemes.any((r) => r.score > 0.3))
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Update Profile', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),

        // Scheme List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildSchemeCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildTopMatchesSection(List<SchemeMatchResult> topMatches) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16A34A).withValues(alpha: 0.08),
            const Color(0xFF2563EB).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Top Matches for You',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              if (_profile.hasProfile)
                Text(
                  _profile.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...topMatches.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(r.scheme.category.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.scheme.shortName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${r.matchPercent.round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildLevelChip(String label) {
    final isSelected = _selectedLevel == label;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String emoji, SchemeCategory? category) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(emoji, style: const TextStyle(fontSize: 16)),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedCategory = category);
        },
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF2563EB).withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No schemes found',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Try adjusting your filters or search',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSchemeCard(SchemeMatchResult result) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = result.scheme;

    final matchColor = result.score >= 0.6
        ? const Color(0xFF16A34A)
        : result.score >= 0.3
            ? const Color(0xFFF59E0B)
            : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SchemeDetailScreen(scheme: scheme, profile: _profile),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(scheme.category.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              scheme.shortName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!scheme.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Inactive',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scheme.ministry,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_profile.hasProfile)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: matchColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${result.matchPercent.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: matchColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              scheme.plainLanguageSummary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMiniTag(scheme.level == SchemeLevel.central ? 'Central' : 'State'),
                const SizedBox(width: 6),
                _buildMiniTag(scheme.category.label),
                const Spacer(),
                // Bookmark button
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await _service.toggleBookmark(scheme.id);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _service.isBookmarked(scheme.id)
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _service.isBookmarked(scheme.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                      color: _service.isBookmarked(scheme.id)
                          ? const Color(0xFFF59E0B)
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Compare button
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await _service.toggleCompare(scheme.id);
                    setState(() {});
                    if (_service.compareIds.length == 3 && _service.isComparing(scheme.id)) {
                      if (mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const SchemeCompareScreen(),
                        )).then((_) => setState(() {}));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _service.isComparing(scheme.id)
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _service.isComparing(scheme.id)
                          ? Icons.compare_arrows_rounded
                          : Icons.compare_arrows_outlined,
                      size: 18,
                      color: _service.isComparing(scheme.id)
                          ? const Color(0xFF7C3AED)
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                if (result.score > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    result.matchLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: matchColor,
                    ),
                  ),
                ],
              ],
            ),
            // Show match reasons for matched schemes
            if (_profile.hasProfile && result.score > 0 && result.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: matchColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.reasons.first,
                  style: TextStyle(
                    fontSize: 11,
                    color: matchColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  // ─── Profile Tab ────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return ProfileSetupScreen(
      initialProfile: _profile,
      onProfileSaved: _updateProfile,
    );
  }

  // ─── FAB ────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compare button
        if (_service.compareIds.isNotEmpty)
          FloatingActionButton.small(
            heroTag: 'compare',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SchemeCompareScreen(),
              )).then((_) => setState(() {}));
            },
            backgroundColor: const Color(0xFF7C3AED),
            child: Badge(
              label: Text('${_service.compareIds.length}',
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
              child: const Icon(Icons.compare_arrows_rounded, color: Colors.white, size: 22),
            ),
          ),
        if (_service.compareIds.isNotEmpty) const SizedBox(height: 10),
        // Main FAB
        FloatingActionButton.extended(
          heroTag: 'main',
          onPressed: _showQuickActions,
          backgroundColor: const Color(0xFF2563EB),
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          label: const Text('Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildActionTile(
              icon: Icons.bookmark_rounded,
              title: 'Saved Schemes',
              subtitle: '${_service.bookmarks.length} schemes saved',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeTrackerScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildActionTile(
              icon: Icons.track_changes_rounded,
              title: 'Application Tracker',
              subtitle: '${_service.appliedCount} applied, ${_service.pendingCount} pending',
              color: const Color(0xFF2563EB),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeTrackerScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildActionTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Compare Schemes',
              subtitle: '${_service.compareIds.length}/3 selected',
              color: const Color(0xFF7C3AED),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeCompareScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildActionTile(
              icon: Icons.analytics_rounded,
              title: 'Analytics & Insights',
              subtitle: 'See your eligibility stats',
              color: const Color(0xFF16A34A),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SchemeAnalyticsScreen(profile: _profile),
                ));
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      onTap: onTap,
    );
  }

  // ─── Drawer ─────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Government Schemes',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
            ),
            const Divider(),
            _buildDrawerItem(
              icon: Icons.home_rounded,
              title: 'Discover Schemes',
              onTap: () { Navigator.pop(context); _tabController.animateTo(0); },
            ),
            _buildDrawerItem(
              icon: Icons.person_rounded,
              title: 'My Profile',
              onTap: () { Navigator.pop(context); _tabController.animateTo(1); },
            ),
            const Divider(),
            _buildDrawerItem(
              icon: Icons.bookmark_rounded,
              title: 'Saved Schemes',
              badge: '${_service.bookmarks.length}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeTrackerScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildDrawerItem(
              icon: Icons.track_changes_rounded,
              title: 'Application Tracker',
              badge: '${_service.appliedCount}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeTrackerScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildDrawerItem(
              icon: Icons.compare_arrows_rounded,
              title: 'Compare Schemes',
              badge: '${_service.compareIds.length}',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SchemeCompareScreen(),
                )).then((_) => setState(() {}));
              },
            ),
            _buildDrawerItem(
              icon: Icons.analytics_rounded,
              title: 'Analytics & Insights',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SchemeAnalyticsScreen(profile: _profile),
                ));
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${SchemeDatabase.schemes.length} schemes across India',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null && badge != '0')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(badge,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
            ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
        ],
      ),
      onTap: onTap,
    );
  }
}
