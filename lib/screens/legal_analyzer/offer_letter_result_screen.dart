import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/legal/models/offer_letter_models.dart';

class OfferLetterResultScreen extends StatefulWidget {
  final OfferComparisonResult result;

  const OfferLetterResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<OfferLetterResultScreen> createState() => _OfferLetterResultScreenState();
}

class _OfferLetterResultScreenState extends State<OfferLetterResultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _buildShareableReport() {
    final r = widget.result;
    final buf = StringBuffer();
    buf.writeln('=== OFFER LETTER COMPARISON REPORT ===');
    buf.writeln('Verdict: ${r.winnerTitle}');
    buf.writeln('Previous Offer (${r.offerA.companyName}): Score ${r.scoreA.toInt()}/100');
    buf.writeln('New Offer (${r.offerB.companyName}): Score ${r.scoreB.toInt()}/100');
    buf.writeln('\n--- EXECUTIVE VERDICT ---');
    buf.writeln(r.verdictSummary);
    buf.writeln('\n--- HEAD-TO-HEAD METRICS ---');
    for (final m in r.comparisons) {
      final adv = m.favorable == OfferChoice.offerB
          ? 'Advantage: ${r.offerB.companyName}'
          : (m.favorable == OfferChoice.offerA
              ? 'Advantage: ${r.offerA.companyName}'
              : 'Neutral');
      buf.writeln('• ${m.metricTitle}:');
      buf.writeln('   ${r.offerA.companyName}: ${m.valueA}');
      buf.writeln('   ${r.offerB.companyName}: ${m.valueB}');
      buf.writeln('   [$adv] ${m.explanation}');
    }

    if (r.keyRisksNew.isNotEmpty) {
      buf.writeln('\n--- CRUCIAL RISKS IN NEW OFFER ---');
      for (final risk in r.keyRisksNew) {
        buf.writeln('⚠️ $risk');
      }
    }

    if (r.negotiationActionItems.isNotEmpty) {
      buf.writeln('\n--- RECOMMENDED HR NEGOTIATION POINTS ---');
      for (final n in r.negotiationActionItems) {
        buf.writeln('✓ $n');
      }
    }

    buf.writeln('\n--- STATUTORY INDIAN LAW NOTE ---');
    buf.writeln(r.legalAdvisory);
    return buf.toString();
  }

  String _buildNegotiationEmailDraft() {
    final r = widget.result;
    return '''Subject: Inquiry Regarding Offer Terms - ${r.offerB.jobTitle} - [Your Name]

Dear Hiring Team at ${r.offerB.companyName},

Thank you very much for extending the offer for the position of ${r.offerB.jobTitle}. I am genuinely excited about the team's mission and the opportunity to contribute.

Upon carefully reviewing the appointment clauses, I would appreciate your kind consideration regarding a few specific contractual terms:

1. Service Lock-in Bond:
I noticed a clause regarding a ${r.offerB.bondDisplay}. As an experienced professional committed to long-term value creation, I prefer an arrangement founded on mutual performance rather than financial liquidated damages. Could we consider waiving or revising this clause?

2. Notice Period Flexibility:
The current offer specifies a ${r.offerB.noticePeriodDisplay}. In line with standard industry practices, could we adjust this to 30 or 60 days, or allow an option for notice buyout?

3. Performance Variable Component:
Could you share additional clarity regarding the quarterly milestones and historical payout ratio for the variable compensation component (${r.offerB.variableBonusDisplay})?

I look forward to discussing these points and finalizing my joining schedule.

Warm regards,
[Your Name]
[Your Phone Number]''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Letter Comparison'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Report',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _buildShareableReport()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Offer comparison report copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVerdictBanner(r, isDark),
                  const SizedBox(height: 16),
                  _buildScoreboardCard(r, theme, isDark),
                  const SizedBox(height: 16),
                  _buildDimensionalScoresCard(r, theme, isDark),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2563EB),
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.compare_arrows_rounded, size: 20), text: 'Side-by-Side'),
                  Tab(icon: Icon(Icons.warning_amber_rounded, size: 20), text: 'Risks & Bonds'),
                  Tab(icon: Icon(Icons.handshake_outlined, size: 20), text: 'Negotiation'),
                ],
              ),
              isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSideBySideTab(r, theme, isDark),
            _buildRisksTab(r, theme, isDark),
            _buildNegotiationTab(r, theme, isDark),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HERO VERDICT & SCOREBOARD
  // ==========================================

  Widget _buildVerdictBanner(OfferComparisonResult r, bool isDark) {
    List<Color> gradientColors;
    IconData icon;
    String badgeText;

    switch (r.winner) {
      case OfferWinner.offerB:
        gradientColors = [const Color(0xFF065F46), const Color(0xFF059669)];
        icon = Icons.verified_rounded;
        badgeText = 'NEW OFFER IS MORE BENEFICIAL';
        break;
      case OfferWinner.offerA:
        gradientColors = [const Color(0xFF1E3A8A), const Color(0xFF2563EB)];
        icon = Icons.shield_rounded;
        badgeText = 'PREVIOUS OFFER IS MORE FAVORABLE';
        break;
      case OfferWinner.conditional:
        gradientColors = [const Color(0xFF9A3412), const Color(0xFFEA580C)];
        icon = Icons.notification_important_rounded;
        badgeText = 'CONDITIONALLY BETTER (NEGOTIATION ADVISED)';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (r.analyzedWithAi)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'AI Verified',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.winnerTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.verdictSummary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboardCard(OfferComparisonResult r, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Offer A
          Expanded(
            child: Column(
              children: [
                Text(
                  r.offerA.companyName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.scoreA.toInt()}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: r.winner == OfferWinner.offerA ? const Color(0xFF2563EB) : Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Score / 100',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  r.offerA.ctcDisplay,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // VS Divider
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (r.scoreDelta >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r.scoreDelta >= 0 ? '+${r.scoreDelta.toInt()} pts' : '${r.scoreDelta.toInt()} pts',
                  style: TextStyle(
                    color: r.scoreDelta >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Offer B
          Expanded(
            child: Column(
              children: [
                Text(
                  r.offerB.companyName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: r.winner == OfferWinner.offerB ? const Color(0xFF059669) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.scoreB.toInt()}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: r.winner == OfferWinner.offerB
                        ? const Color(0xFF059669)
                        : (r.winner == OfferWinner.conditional
                            ? const Color(0xFFEA580C)
                            : Colors.grey.shade700),
                  ),
                ),
                Text(
                  'Score / 100',
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  r.offerB.ctcDisplay,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionalScoresCard(OfferComparisonResult r, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY DIMENSION BREAKDOWN',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          _buildDimensionBar(
            title: '💰 Financial & CTC Value',
            scoreA: r.financialScoreA,
            scoreB: r.financialScoreB,
            nameA: r.offerA.companyName,
            nameB: r.offerB.companyName,
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: 12),
          _buildDimensionBar(
            title: '⚖️ Legal Freedom & Notice Mobility',
            scoreA: r.legalFreedomScoreA,
            scoreB: r.legalFreedomScoreB,
            nameA: r.offerA.companyName,
            nameB: r.offerB.companyName,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          _buildDimensionBar(
            title: '🌴 Work-Life & Schedule Flexibility',
            scoreA: r.workLifeScoreA,
            scoreB: r.workLifeScoreB,
            nameA: r.offerA.companyName,
            nameB: r.offerB.companyName,
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: 12),
          _buildDimensionBar(
            title: '🏥 Insurance & Medical Benefits',
            scoreA: r.benefitsScoreA,
            scoreB: r.benefitsScoreB,
            nameA: r.offerA.companyName,
            nameB: r.offerB.companyName,
            color: const Color(0xFF9333EA),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionBar({
    required String title,
    required double scoreA,
    required double scoreB,
    required String nameA,
    required String nameB,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${scoreA.toInt()} vs ${scoreB.toInt()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: scoreB >= scoreA ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: scoreA / 100.0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade500),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: scoreB / 100.0,
                  minHeight: 6,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: SIDE BY SIDE COMPARISON
  // ==========================================

  Widget _buildSideBySideTab(OfferComparisonResult r, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'SIDE-BY-SIDE CLAUSE COMPARISON',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...r.comparisons.map((c) => _buildComparisonCard(c, r, theme, isDark)),
      ],
    );
  }

  Widget _buildComparisonCard(
    MetricComparison c,
    OfferComparisonResult r,
    ThemeData theme,
    bool isDark,
  ) {
    Color badgeColor;
    String badgeLabel;

    switch (c.favorable) {
      case OfferChoice.offerB:
        badgeColor = const Color(0xFF059669);
        badgeLabel = 'Advantage: ${r.offerB.companyName}';
        break;
      case OfferChoice.offerA:
        badgeColor = const Color(0xFF2563EB);
        badgeLabel = 'Advantage: ${r.offerA.companyName}';
        break;
      case OfferChoice.neutral:
        badgeColor = Colors.grey;
        badgeLabel = 'Comparable / Neutral';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.favorable == OfferChoice.offerB
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : (c.favorable == OfferChoice.offerA
                  ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.metricTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offer A column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: isDark ? 0.08 : 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.offerA.companyName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.valueA,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Offer B column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (c.favorable == OfferChoice.offerB
                            ? const Color(0xFF059669)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.offerB.companyName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.valueB,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (c.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.explanation,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: RISKS & STATUTORY BONDS
  // ==========================================

  Widget _buildRisksTab(OfferComparisonResult r, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Statutory Precedent Alert Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF991B1B).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Color(0xFFDC2626), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Indian Contract Act Statutory Safeguards',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.legalAdvisory,
                style: const TextStyle(fontSize: 11.5, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'CRITICAL RISKS & TRAPS IN NEW OFFER',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        if (r.keyRisksNew.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No aggressive employment bonds or unfair restraint clauses detected in this offer letter.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          ...r.keyRisksNew.map((risk) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_rounded, color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        risk,
                        style: const TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),

        const SizedBox(height: 16),
        Text(
          'KEY ADVANTAGES OF NEW OFFER',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        ...r.keyAdvantagesNew.map((adv) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adv,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ==========================================
  // TAB 3: HR NEGOTIATION PLAYBOOK
  // ==========================================

  Widget _buildNegotiationTab(OfferComparisonResult r, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Intro Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Strategic Counter-Offer Guide',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Top candidates negotiate before signing. Most companies agree to adjust notice periods, remove bonds, or reallocate discretionary variable into guaranteed fixed pay upon request.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'SPECIFIC TALKING POINTS FOR HR',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        ...r.negotiationActionItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),

        const SizedBox(height: 16),

        // Ready Email Draft
        Text(
          'READY EMAIL DRAFT FOR HR',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _buildNegotiationEmailDraft(),
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _buildNegotiationEmailDraft()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Negotiation email draft copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Email to Clipboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
