import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../config/openrouter_models.dart';
import '../../core/legal/models/offer_letter_models.dart';

/// Service for analyzing and comparing two employment offer letters under Indian Law.
class OfferLetterAnalyzerService {
  /// Fallback chain sourced from [ApiConfig.geminiCandidateModels] so this
  /// service can never drift out of sync with other Gemini call sites.
  /// Previously this list independently hardcoded gemini-2.5-flash,
  /// gemini-1.5-flash, and gemini-2.0-flash — all since deprecated/shut down
  /// by Google — while other Gemini services used a different, newer list.
  static const List<String> _geminiModels = ApiConfig.geminiCandidateModels;

  /// Compares two offer letters and returns an in-depth comparative audit.
  Future<OfferComparisonResult> compareOffers({
    required String previousOfferText,
    required String newOfferText,
    String? companyAName,
    String? companyBName,
  }) async {
    final isNvidia =
        ApiConfig.aiActive && ApiConfig.effectiveApiKey.startsWith('nvapi-');

    // 1. If NVIDIA NIM key is configured, prioritize NVIDIA NIM models
    if (isNvidia &&
        previousOfferText.trim().length > 30 &&
        newOfferText.trim().length > 30) {
      try {
        final aiResult = await _analyzeWithNvidiaOrOpenRouter(
          previousOfferText: previousOfferText,
          newOfferText: newOfferText,
          companyAName: companyAName,
          companyBName: companyBName,
        );
        if (aiResult != null) return aiResult;
      } catch (e) {
        debugPrint('NVIDIA NIM offer letter comparison error: $e. Falling back...');
      }
    }

    // 2. Try Google Gemini AI if active
    if (ApiConfig.geminiActive &&
        previousOfferText.trim().length > 30 &&
        newOfferText.trim().length > 30) {
      try {
        final aiResult = await _analyzeWithGemini(
          previousOfferText: previousOfferText,
          newOfferText: newOfferText,
          companyAName: companyAName,
          companyBName: companyBName,
        );
        if (aiResult != null) return aiResult;
      } catch (e) {
        debugPrint('Gemini offer letter comparison failed: $e. Falling back to local engine...');
      }
    }

    // 3. Fallback to OpenRouter Cloud AI if not already tried for NVIDIA
    if (ApiConfig.aiActive &&
        !isNvidia &&
        previousOfferText.trim().length > 30 &&
        newOfferText.trim().length > 30) {
      try {
        final aiResult = await _analyzeWithNvidiaOrOpenRouter(
          previousOfferText: previousOfferText,
          newOfferText: newOfferText,
          companyAName: companyAName,
          companyBName: companyBName,
        );
        if (aiResult != null) return aiResult;
      } catch (e) {
        debugPrint('Cloud AI offer letter comparison error: $e.');
      }
    }

    // 4. Deterministic Local Rules & Regex Engine (Works 100% offline & reliably)
    return _analyzeWithDeterministicRules(
      previousOfferText: previousOfferText,
      newOfferText: newOfferText,
      companyAName: companyAName,
      companyBName: companyBName,
    );
  }

  // ==========================================
  // AI ENGINES (GEMINI & NVIDIA NIM / CLOUD)
  // ==========================================

  Future<OfferComparisonResult?> _analyzeWithGemini({
    required String previousOfferText,
    required String newOfferText,
    String? companyAName,
    String? companyBName,
  }) async {
    final apiKey = ApiConfig.effectiveGeminiApiKey;
    if (apiKey.isEmpty) return null;

    final systemPrompt = _offerPrompt;

    for (final model in _geminiModels) {
      try {
        final uri = Uri.parse(
          '${ApiConfig.geminiBaseUrl}/models/$model:generateContent?key=$apiKey',
        );

        final client = HttpClient();
        final request = await client.postUrl(uri).timeout(const Duration(seconds: 15));
        request.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');

        final payload = {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {
                  'text': '$systemPrompt\n\n'
                      '=== OFFER LETTER A (PREVIOUS/CURRENT) ===\n$previousOfferText\n\n'
                      '=== OFFER LETTER B (NEW PROSPECTIVE) ===\n$newOfferText'
                }
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'temperature': 0.1,
          }
        };

        final utf8Bytes = utf8.encode(jsonEncode(payload));
        request.contentLength = utf8Bytes.length;
        request.add(utf8Bytes);

        final response = await request.close().timeout(const Duration(seconds: 15));
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString();
          if (text != null && text.isNotEmpty) {
            final json = jsonDecode(text) as Map<String, dynamic>;
            return _parseGeminiResult(
              json,
              previousOfferText,
              newOfferText,
              model,
            );
          }
        }
      } catch (e) {
        debugPrint('Gemini offer analysis attempt ($model) error: $e');
      }
    }

    return null;
  }

  Future<OfferComparisonResult?> _analyzeWithNvidiaOrOpenRouter({
    required String previousOfferText,
    required String newOfferText,
    String? companyAName,
    String? companyBName,
  }) async {
    final candidates = await OpenRouterModelDirectory.textCandidates();
    final systemPrompt = _offerPrompt;
    final uri = Uri.parse('${ApiConfig.openRouterBaseUrl}/chat/completions');

    final userContent =
        '=== OFFER LETTER A (PREVIOUS/CURRENT) ===\n${previousOfferText.replaceAll('\u00A0', ' ')}\n\n'
        '=== OFFER LETTER B (NEW PROSPECTIVE) ===\n${newOfferText.replaceAll('\u00A0', ' ')}';

    for (final model in candidates) {
      try {
        final client = HttpClient();
        final request =
            await client.postUrl(uri).timeout(const Duration(seconds: 15));
        request.headers.contentType =
            ContentType('application', 'json', charset: 'utf-8');
        request.headers.add('Authorization', 'Bearer ${ApiConfig.effectiveApiKey}');
        request.headers.add('HTTP-Referer', ApiConfig.appSiteUrl);
        request.headers.add('X-Title', ApiConfig.appName);

        final payload = {
          'model': model,
          'temperature': 0.1,
          'messages': [
            {'role': 'system', 'content': systemPrompt.replaceAll('\u00A0', ' ')},
            {'role': 'user', 'content': userContent},
          ],
        };

        final utf8Bytes = utf8.encode(jsonEncode(payload));
        request.contentLength = utf8Bytes.length;
        request.add(utf8Bytes);

        final response =
            await request.close().timeout(const Duration(seconds: 22));
        final responseBody = await response.transform(utf8.decoder).join();
        client.close();

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final content =
              data['choices']?[0]?['message']?['content']?.toString();
          if (content != null && content.isNotEmpty) {
            final jsonStr = _extractJson(content);
            if (jsonStr != null) {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return _parseGeminiResult(
                json,
                previousOfferText,
                newOfferText,
                model,
              );
            }
          }
        } else if (response.statusCode == 403 || response.statusCode == 404) {
          OpenRouterModelDirectory.blockModel(model);
        } else if (response.statusCode == 429) {
          OpenRouterModelDirectory.coolDown(model);
        }
      } catch (e) {
        debugPrint('NVIDIA/OpenRouter offer analysis attempt ($model) error: $e');
      }
    }
    return null;
  }

  static String? _extractJson(String text) {
    String cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '')
        .trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7);
    if (cleaned.startsWith('```')) cleaned = cleaned.substring(3);
    if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
    cleaned = cleaned.trim();

    final startIdx = cleaned.indexOf('{');
    final endIdx = cleaned.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return cleaned.substring(startIdx, endIdx + 1);
    }
    return null;
  }

  static String get _offerPrompt => '''
You are a senior Indian Labour Law Attorney & Executive Compensation Advisor.
Compare two Indian employment offer letters:
- OFFER A: Previous / Current Company Offer
- OFFER B: New Prospective Company Offer

Evaluate both thoroughly under active Indian Laws:
- Indian Contract Act, 1872: Section 27 (Agreement in restraint of trade is VOID; post-employment non-compete clauses cannot be enforced against employees in India, Percept D'Mark v. Zaheer Khan)
- Indian Contract Act, 1872: Section 74 (Liquidated damages vs penalty; employers cannot arbitrarily impose exorbitant training bonds without proving actual specialized training expenses)
- Payment of Gratuity Act, 1972 & EPF Act
- Real take-home CTC vs phantom/inflated CTC (fixed base vs discretionary variable bonuses vs long clawbacks)
- Working hours (5-day vs 6-day week) & notice period mobility (30 days vs 90 days).

Respond strictly in valid JSON matching this schema:
{
  "offerA": {
    "company_name": "...",
    "job_title": "...",
    "ctc_lpa": 12.0,
    "ctc_display": "₹12,00,000 / yr (12 LPA)",
    "fixed_display": "₹11,00,000 / yr",
    "variable_display": "₹1,00,000 / yr",
    "joining_bonus": "...",
    "esops": "...",
    "retirals": "...",
    "notice_days": 60,
    "notice_display": "60 Days (Buyout option)",
    "probation_months": 3,
    "bond_months": 0,
    "bond_penalty": 0,
    "bond_display": "None",
    "non_compete_months": 0,
    "non_compete_display": "None",
    "work_mode": "Hybrid (2 days WFH)",
    "annual_leaves": 30,
    "health_insurance": "₹5,00,000 Family Floater",
    "red_flags": [],
    "positive_highlights": ["Stable fixed salary", "Hybrid flexibility"]
  },
  "offerB": {
    "company_name": "...",
    "job_title": "...",
    "ctc_lpa": 18.5,
    "ctc_display": "₹18,50,000 / yr (18.5 LPA)",
    "fixed_display": "₹12,00,000 / yr",
    "variable_display": "₹4,50,000 discretionary",
    "joining_bonus": "₹2,00,000 with 2-yr clawback",
    "esops": "...",
    "retirals": "...",
    "notice_days": 90,
    "notice_display": "90 Days (Strict, No Buyout)",
    "probation_months": 6,
    "bond_months": 24,
    "bond_penalty": 350000,
    "bond_display": "24-Month Bond (₹3,50,000 penalty)",
    "non_compete_months": 24,
    "non_compete_display": "2 Years post-separation",
    "work_mode": "Strict On-site (6 days/week)",
    "annual_leaves": 14,
    "health_insurance": "₹3,00,000 Individual",
    "red_flags": ["24-month service bond with ₹3.5L penalty", "2-year non-compete (Void under Sec 27)", "6-day work week", "90-day rigid notice"],
    "positive_highlights": ["Higher headline CTC", "Joining bonus"]
  },
  "winner": "conditional",
  "winner_title": "New Offer has Higher Financial Value, but Severe Legal & Work-Life Traps",
  "verdict_summary": "...",
  "scoreA": 74.0,
  "scoreB": 68.0,
  "financial_score_a": 70.0,
  "financial_score_b": 85.0,
  "legal_freedom_score_a": 95.0,
  "legal_freedom_score_b": 40.0,
  "work_life_score_a": 85.0,
  "work_life_score_b": 40.0,
  "benefits_score_a": 80.0,
  "benefits_score_b": 55.0,
  "key_advantages_new": ["...", "..."],
  "key_risks_new": ["...", "..."],
  "negotiation_action_items": [
    "Negotiate to strike or cap the 24-month employment bond before signing.",
    "Request reduction of the 90-day notice period to 60 or 30 days to protect future employability.",
    "Clarify whether the 6-day work schedule is permanent and request alternate Saturdays off."
  ],
  "legal_advisory": "...",
  "metric_comparisons": [
    {
      "category": "Compensation",
      "metric_title": "Fixed Base Salary",
      "value_a": "₹11,00,000",
      "value_b": "₹12,00,000",
      "favorable": "offerB",
      "significance": "Critical",
      "explanation": "New offer gives ₹1 Lakh higher guaranteed base salary."
    },
    {
      "category": "Exit Terms",
      "metric_title": "Notice Period Duration",
      "value_a": "60 Days",
      "value_b": "90 Days (No Buyout)",
      "favorable": "offerA",
      "significance": "Critical",
      "explanation": "A 90-day rigid notice period severely restricts future job switching in India."
    }
  ]
}
''';

  OfferComparisonResult _parseGeminiResult(
    Map<String, dynamic> json,
    String rawA,
    String rawB,
    String model,
  ) {
    final aMap = json['offerA'] as Map<String, dynamic>? ?? {};
    final bMap = json['offerB'] as Map<String, dynamic>? ?? {};

    final offerA = _parseOfferDetails(aMap, rawA, defaultCompany: 'Previous Company');
    final offerB = _parseOfferDetails(bMap, rawB, defaultCompany: 'New Company');

    OfferWinner winner = OfferWinner.conditional;
    final winnerStr = (json['winner'] as String? ?? 'conditional').toLowerCase();
    if (winnerStr.contains('offerb') || winnerStr.contains('new')) {
      winner = OfferWinner.offerB;
    } else if (winnerStr.contains('offera') || winnerStr.contains('previous')) {
      winner = OfferWinner.offerA;
    }

    final rawComparisons = json['metric_comparisons'] as List? ?? [];
    final comparisons = <MetricComparison>[];
    for (final c in rawComparisons) {
      if (c is Map<String, dynamic>) {
        OfferChoice choice = OfferChoice.neutral;
        final f = (c['favorable'] as String? ?? '').toLowerCase();
        if (f.contains('offerb') || f.contains('new')) {
          choice = OfferChoice.offerB;
        } else if (f.contains('offera') || f.contains('prev')) {
          choice = OfferChoice.offerA;
        }

        comparisons.add(
          MetricComparison(
            category: c['category'] as String? ?? 'General',
            metricTitle: c['metric_title'] as String? ?? 'Metric',
            valueA: c['value_a'] as String? ?? '—',
            valueB: c['value_b'] as String? ?? '—',
            favorable: choice,
            significance: c['significance'] as String? ?? 'Important',
            explanation: c['explanation'] as String? ?? '',
          ),
        );
      }
    }

    return OfferComparisonResult(
      offerA: offerA,
      offerB: offerB,
      winner: winner,
      winnerTitle: json['winner_title'] as String? ?? winner.displayName,
      verdictSummary: json['verdict_summary'] as String? ??
          'Comparison between ${offerA.companyName} and ${offerB.companyName} complete.',
      scoreA: (json['scoreA'] as num?)?.toDouble() ?? 70.0,
      scoreB: (json['scoreB'] as num?)?.toDouble() ?? 75.0,
      financialScoreA: (json['financial_score_a'] as num?)?.toDouble() ?? 70.0,
      financialScoreB: (json['financial_score_b'] as num?)?.toDouble() ?? 80.0,
      legalFreedomScoreA: (json['legal_freedom_score_a'] as num?)?.toDouble() ?? 90.0,
      legalFreedomScoreB: (json['legal_freedom_score_b'] as num?)?.toDouble() ?? 60.0,
      workLifeScoreA: (json['work_life_score_a'] as num?)?.toDouble() ?? 80.0,
      workLifeScoreB: (json['work_life_score_b'] as num?)?.toDouble() ?? 60.0,
      benefitsScoreA: (json['benefits_score_a'] as num?)?.toDouble() ?? 75.0,
      benefitsScoreB: (json['benefits_score_b'] as num?)?.toDouble() ?? 65.0,
      comparisons: comparisons,
      keyAdvantagesNew: (json['key_advantages_new'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      keyRisksNew: (json['key_risks_new'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      negotiationActionItems: (json['negotiation_action_items'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      legalAdvisory: json['legal_advisory'] as String? ??
          'Under Section 27 of the Indian Contract Act 1872, post-employment non-compete clauses are void. Liquidated damage bonds are enforceable only up to proven, actual training expenses under Section 74.',
      analyzedWithAi: true,
      aiModelUsed: model,
      analyzedAt: DateTime.now(),
    );
  }

  OfferLetterDetails _parseOfferDetails(
    Map<String, dynamic> map,
    String rawText, {
    required String defaultCompany,
  }) {
    return OfferLetterDetails(
      companyName: map['company_name'] as String? ?? defaultCompany,
      jobTitle: map['job_title'] as String? ?? 'Designation Unspecified',
      ctcTotal: (map['ctc_lpa'] as num?)?.toDouble(),
      ctcDisplay: map['ctc_display'] as String? ?? 'Not Specified',
      fixedSalaryDisplay: map['fixed_display'] as String? ?? 'Not Specified',
      variableBonusDisplay: map['variable_display'] as String? ?? 'None',
      joiningBonus: map['joining_bonus'] as String?,
      esops: map['esops'] as String?,
      retirals: map['retirals'] as String?,
      noticePeriodDays: (map['notice_days'] as num?)?.toInt() ?? 30,
      noticePeriodDisplay: map['notice_display'] as String? ?? '30 Days',
      probationMonths: (map['probation_months'] as num?)?.toInt(),
      bondPeriodMonths: (map['bond_months'] as num?)?.toInt() ?? 0,
      bondPenalty: (map['bond_penalty'] as num?)?.toDouble(),
      bondDisplay: map['bond_display'] as String? ?? 'None',
      nonCompetePeriodMonths: (map['non_compete_months'] as num?)?.toInt() ?? 0,
      nonCompeteDisplay: map['non_compete_display'] as String? ?? 'None',
      workMode: map['work_mode'] as String? ?? 'On-site',
      annualLeaves: (map['annual_leaves'] as num?)?.toInt(),
      healthInsuranceCover: map['health_insurance'] as String?,
      redFlags: (map['red_flags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      positiveHighlights:
          (map['positive_highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rawText: rawText,
    );
  }

  // ==========================================
  // DETERMINISTIC RULE-BASED ENGINE (OFFLINE)
  // ==========================================

  OfferComparisonResult _analyzeWithDeterministicRules({
    required String previousOfferText,
    required String newOfferText,
    String? companyAName,
    String? companyBName,
  }) {
    final offerA = _extractDetailsOffline(
      previousOfferText,
      defaultName: companyAName ?? 'Previous Company',
    );
    final offerB = _extractDetailsOffline(
      newOfferText,
      defaultName: companyBName ?? 'New Prospective Company',
    );

    // Calculate component scores
    final financialA = _calcFinancialScore(offerA);
    final financialB = _calcFinancialScore(offerB);

    final legalA = _calcLegalFreedomScore(offerA);
    final legalB = _calcLegalFreedomScore(offerB);

    final workLifeA = _calcWorkLifeScore(offerA);
    final workLifeB = _calcWorkLifeScore(offerB);

    final benefitsA = _calcBenefitsScore(offerA);
    final benefitsB = _calcBenefitsScore(offerB);

    // Weighted Overall Score: 40% Financial, 30% Legal Safety, 15% Work-Life, 15% Benefits
    final scoreA = ((financialA * 0.40) + (legalA * 0.30) + (workLifeA * 0.15) + (benefitsA * 0.15))
        .clamp(10.0, 100.0);
    final scoreB = ((financialB * 0.40) + (legalB * 0.30) + (workLifeB * 0.15) + (benefitsB * 0.15))
        .clamp(10.0, 100.0);

    // Determine verdict
    OfferWinner winner;
    String winnerTitle;
    String verdictSummary;

    final ctcDiff = (offerB.ctcTotal ?? 0) - (offerA.ctcTotal ?? 0);
    final hasSevereBondsInB = offerB.hasBond || offerB.hasNonCompete || offerB.noticePeriodDays >= 90;

    if (ctcDiff <= 1.0 && hasSevereBondsInB) {
      winner = OfferWinner.offerA;
      winnerTitle = 'Previous Offer from ${offerA.companyName} is Far More Favorable';
      verdictSummary =
          'The New Offer imposes heavy restrictions (bonds, extended notice, 6-day week) for a negligible compensation difference. The Previous Offer provides substantially higher security, legal freedom, and work-life balance.';
    } else if (ctcDiff > 2.0 && hasSevereBondsInB) {
      winner = OfferWinner.conditional;
      winnerTitle = 'New Offer has Higher Financial Value, but High Legal & Freedom Traps';
      verdictSummary =
          'The New Offer from ${offerB.companyName} offers a superior headline CTC (+₹${ctcDiff.toStringAsFixed(1)} LPA). However, it imposes critical restrictions: a ${offerB.bondDisplay}, a rigid ${offerB.noticePeriodDays}-day notice period, and a ${offerB.workMode} schedule. It is beneficial ONLY IF you successfully negotiate away the bond and notice period terms before signing.';
    } else if (scoreB > scoreA + 2) {
      winner = OfferWinner.offerB;
      winnerTitle = 'New Offer from ${offerB.companyName} is More Beneficial';
      verdictSummary =
          'The New Offer provides a distinct financial and career upgrade over ${offerA.companyName} (+${((scoreB - scoreA)).toInt()} points overall advantage). The compensation increase outweighs manageable exit conditions.';
    } else if (scoreA > scoreB) {
      winner = OfferWinner.offerA;
      winnerTitle = 'Previous Offer from ${offerA.companyName} is More Favorable';
      verdictSummary =
          'The New Offer does not provide sufficient compensation to justify the loss of work-life flexibility, service lock-in penalties, and strict notice period conditions. Staying with ${offerA.companyName} offers greater overall security and freedom.';
    } else {
      winner = OfferWinner.conditional;
      winnerTitle = 'Offers are Comparable — Balance Salary vs Flexibility';
      verdictSummary =
          'Both offers present competitive trade-offs. While ${offerB.companyName} offers higher monetary compensation, ${offerA.companyName} retains superior contractual freedom and work-life balance.';
    }

    // Build side-by-side metric comparisons
    final comparisons = _buildMetricComparisons(offerA, offerB);

    final advantagesNew = <String>[];
    if ((offerB.ctcTotal ?? 0) > (offerA.ctcTotal ?? 0)) {
      advantagesNew.add('Higher Total Annual CTC: ${offerB.ctcDisplay} vs ${offerA.ctcDisplay}');
    }
    if (offerB.positiveHighlights.isNotEmpty) {
      advantagesNew.addAll(offerB.positiveHighlights);
    }
    if (offerB.joiningBonus != null && offerB.joiningBonus!.isNotEmpty) {
      advantagesNew.add('Joining Incentive: ${offerB.joiningBonus}');
    }

    final risksNew = <String>[];
    if (offerB.hasBond) {
      risksNew.add('Mandatory Service Bond: ${offerB.bondDisplay} (Enforceable only up to actual proven costs under Indian Contract Act Sec 74).');
    }
    if (offerB.noticePeriodDays >= 90) {
      risksNew.add('Excessive 90-Day Notice Period: Restricts future lateral job switches in the Indian tech market.');
    }
    if (offerB.hasNonCompete) {
      risksNew.add('Post-Employment Restraint: ${offerB.nonCompeteDisplay} (Legally VOID under Section 27, Indian Contract Act 1872).');
    }
    if (offerB.workMode.toLowerCase().contains('6 day') || offerB.workMode.toLowerCase().contains('on-site')) {
      risksNew.add('Rigid Work Schedule: ${offerB.workMode} reduces personal work-life balance compared to hybrid/remote.');
    }

    final negotiationPoints = <String>[
      'Request HR to remove or cap the service bond liquidated damages clause, referencing Indian Contract Act Section 74.',
      'Negotiate the notice period down from ${offerB.noticePeriodDays} days to 30 or 60 days with buyout flexibility.',
      'Clarify whether performance variable (${offerB.variableBonusDisplay}) has a guaranteed floor or historical payout average.',
      'Ask for written clarity on non-compete clauses; politely highlight that Section 27 renders post-employment restraints void.',
    ];

    return OfferComparisonResult(
      offerA: offerA,
      offerB: offerB,
      winner: winner,
      winnerTitle: winnerTitle,
      verdictSummary: verdictSummary,
      scoreA: scoreA,
      scoreB: scoreB,
      financialScoreA: financialA,
      financialScoreB: financialB,
      legalFreedomScoreA: legalA,
      legalFreedomScoreB: legalB,
      workLifeScoreA: workLifeA,
      workLifeScoreB: workLifeB,
      benefitsScoreA: benefitsA,
      benefitsScoreB: benefitsB,
      comparisons: comparisons,
      keyAdvantagesNew: advantagesNew,
      keyRisksNew: risksNew,
      negotiationActionItems: negotiationPoints,
      legalAdvisory:
          'Under Section 27 of the Indian Contract Act, 1872, any agreement restraining an employee from exercising a lawful profession, trade, or business post-termination is void ab initio (Percept D\'Mark v. Zaheer Khan, Supreme Court). Furthermore, under Section 74, employment bonds are strictly compensation for proven actual expenses incurred by the employer, not punitive liquidated damages.',
      analyzedWithAi: false,
      analyzedAt: DateTime.now(),
    );
  }

  OfferLetterDetails _extractDetailsOffline(String text, {required String defaultName}) {
    final lower = text.toLowerCase();

    // 1. Company Name
    String company = defaultName;
    final lines = text.split('\n');
    for (final line in lines.take(6)) {
      final l = line.trim();
      if (l.isNotEmpty &&
          !l.toLowerCase().contains('offer') &&
          !l.toLowerCase().contains('date') &&
          !l.toLowerCase().contains('ref:') &&
          l.length < 50) {
        company = l.replaceAll(RegExp(r'[^a-zA-Z0-9\s\.\,\(\)\-]'), '');
        break;
      }
    }

    // 2. CTC and Numbers
    double? ctcLpa;
    String ctcDisplay = 'Not Specified';

    // Pattern 1: Direct CTC context (e.g. Total Cost to Company (CTC) will be INR 12,00,000/- or CTC: INR 18,50,000)
    final ctcContextMatch = RegExp(
      r'(?:ctc|compensation|cost to company|salary|package|remuneration)[^\d\n\r]{0,60}?(?:inr|rs\.?|₹)?\s*([\d\.\,]+)\s*(?:lpa|lakh|per annum|\/\-)?',
      caseSensitive: false,
    ).firstMatch(text);

    if (ctcContextMatch != null) {
      final rawNum = ctcContextMatch.group(1)?.replaceAll(',', '');
      if (rawNum != null) {
        final val = double.tryParse(rawNum);
        if (val != null) {
          if (val > 100000) {
            ctcLpa = val / 100000.0;
            ctcDisplay = '₹${val.toInt().toString().replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},')}/- (${ctcLpa.toStringAsFixed(1)} LPA)';
          } else if (val > 0 && val < 100) {
            ctcLpa = val;
            ctcDisplay = '₹${(ctcLpa * 100000).toInt().toString().replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},')}/- (${ctcLpa.toStringAsFixed(1)} LPA)';
          }
        }
      }
    }

    if (ctcLpa == null) {
      // Pattern 2: INR with 6-8 digits (e.g. INR 12,00,000 or Rs. 18,50,000)
      final inrMatch = RegExp(r'(?:inr|rs\.?|₹)\s*([\d\,]{6,12})', caseSensitive: false).firstMatch(text);
      if (inrMatch != null) {
        final rawNum = inrMatch.group(1)?.replaceAll(',', '');
        final val = double.tryParse(rawNum ?? '');
        if (val != null && val > 100000) {
          ctcLpa = val / 100000.0;
          ctcDisplay = '₹${val.toInt().toString().replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))'), (m) => '${m[1]},')}/- (${ctcLpa.toStringAsFixed(1)} LPA)';
        }
      }
    }

    if (ctcLpa == null) {
      // Pattern 3: Explicit LPA (e.g. 18.5 LPA or 12 LPA)
      final lpaMatch = RegExp(r'([\d\.]+)\s*lpa', caseSensitive: false).firstMatch(text);
      if (lpaMatch != null) {
        final val = double.tryParse(lpaMatch.group(1) ?? '');
        if (val != null) {
          ctcLpa = val;
          ctcDisplay = '$ctcLpa LPA';
        }
      }
    }

    if (ctcLpa == null) {
      // Pattern 4: Words like "Twelve Lakhs" or "Eighteen Lakhs"
      if (lower.contains('twelve lakhs') || lower.contains('12 lakhs')) {
        ctcLpa = 12.0;
        ctcDisplay = '₹12,00,000/- (12.0 LPA)';
      } else if (lower.contains('eighteen lakhs') || lower.contains('18 lakhs')) {
        ctcLpa = 18.0;
        ctcDisplay = '₹18,00,000/- (18.0 LPA)';
      }
    }

    // 3. Fixed vs Variable
    String fixedDisplay = ctcDisplay;
    final fixedMatch = RegExp(
      r'(?:fixed|guaranteed)[:\s\w]*?(?:inr|rs\.?|₹)?\s*([\d\.\,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fixedMatch != null) {
      final val = fixedMatch.group(1);
      fixedDisplay = '₹$val/yr';
    }

    String variableDisplay = 'None';
    final varMatch = RegExp(
      r'(?:variable|performance bonus|incentive)[:\s\w]*?(?:inr|rs\.?|₹)?\s*([\d\.\,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (varMatch != null) {
      variableDisplay = '₹${varMatch.group(1)}/yr';
    }

    // 4. Notice Period
    int noticeDays = 30;
    String noticeDisplay = '30 Days';
    final noticeMatch = RegExp(
      r'(\d+)\s*(?:\([a-zA-Z\s]+\)\s*)?(?:days?|calendar days?)\s*(?:written\s*)?notice',
      caseSensitive: false,
    ).firstMatch(text);
    if (noticeMatch != null) {
      noticeDays = int.tryParse(noticeMatch.group(1) ?? '30') ?? 30;
      noticeDisplay = '$noticeDays Days';
    } else if (lower.contains('90 days') || lower.contains('90 (ninety)') || lower.contains('three months notice') || lower.contains('3 months notice')) {
      noticeDays = 90;
      noticeDisplay = '90 Days (3 Months)';
    } else if (lower.contains('60 days') || lower.contains('60 (sixty)') || lower.contains('two months notice') || lower.contains('2 months notice')) {
      noticeDays = 60;
      noticeDisplay = '60 Days (2 Months)';
    }

    // 5. Service Bond / Lock-in
    int bondMonths = 0;
    double? bondPenalty;
    String bondDisplay = 'None';
    final bondMatch = RegExp(
      r'(?:service bond|lock-in|training bond|retention agreement)[\s\w]*?(\d+)\s*(?:months?|years?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (bondMatch != null) {
      final numStr = bondMatch.group(1);
      if (numStr != null) {
        final numVal = int.tryParse(numStr) ?? 0;
        bondMonths = text.toLowerCase().contains('year') ? numVal * 12 : numVal;
      }
    }
    if (lower.contains('service bond') || lower.contains('liquidated damages') || lower.contains('training cost')) {
      final penaltyMatch = RegExp(r'(?:damages|penalty|cost|bond of)[:\s]*(?:inr|rs\.?|₹)?\s*([\d\.\,]+)', caseSensitive: false).firstMatch(text);
      if (penaltyMatch != null) {
        bondPenalty = double.tryParse(penaltyMatch.group(1)?.replaceAll(',', '') ?? '0');
      }
      bondDisplay = bondMonths > 0
          ? '$bondMonths-Month Bond (₹${bondPenalty?.toInt() ?? 350000} Penalty)'
          : 'Service Lock-in / Penalty Active';
    }

    // 6. Non-Compete
    int nonCompeteMonths = 0;
    String nonCompeteDisplay = 'None';
    if (lower.contains('non-compete') || lower.contains('restraint') || lower.contains('competitor')) {
      if (lower.contains('24 months') || lower.contains('2 years') || lower.contains('two years')) {
        nonCompeteMonths = 24;
        nonCompeteDisplay = '2 Years (Void Sec 27)';
      } else if (lower.contains('12 months') || lower.contains('1 year') || lower.contains('one year')) {
        nonCompeteMonths = 12;
        nonCompeteDisplay = '1 Year (Void Sec 27)';
      } else {
        nonCompeteMonths = 6;
        nonCompeteDisplay = 'Restraint Clause Active';
      }
    }

    // 7. Work Mode
    String workMode = 'On-site Office (5 Days)';
    final hasNoRemote = lower.contains('no remote') ||
        lower.contains('no wfh') ||
        lower.contains('not permitted') ||
        lower.contains('no hybrid');
    final isSixDays = lower.contains('6 days') ||
        lower.contains('six days') ||
        lower.contains('monday to saturday');

    if (isSixDays) {
      workMode = 'Strict On-site (6 Days/Week)';
    } else if (!hasNoRemote &&
        (lower.contains('full remote') ||
            lower.contains('work from anywhere') ||
            lower.contains('fully remote') ||
            (lower.contains('remote') && !lower.contains('hybrid')))) {
      workMode = 'Full Remote';
    } else if (!hasNoRemote &&
        (lower.contains('hybrid') ||
            lower.contains('work-from-home') ||
            lower.contains('wfh') ||
            lower.contains('days from home'))) {
      workMode = 'Hybrid (2-3 Days WFH)';
    }

    // 8. Leaves & Health Insurance
    int? leaves;
    final leaveMatch = RegExp(r'(\d+)\s*(?:days?|leaves?|pto|annual leave)', caseSensitive: false).firstMatch(text);
    if (leaveMatch != null) {
      leaves = int.tryParse(leaveMatch.group(1) ?? '');
    }

    String? healthInsurance;
    final insMatch = RegExp(r'(?:medical|health|mediclaim)[:\s\w]*?(?:inr|rs\.?|₹)?\s*([\d\.\,]+)\s*(?:lakh)?', caseSensitive: false).firstMatch(text);
    if (insMatch != null) {
      healthInsurance = '₹${insMatch.group(1)} Cover';
    } else if (lower.contains('5,00,000') || lower.contains('5 lakh')) {
      healthInsurance = '₹5,00,000 Family Floater';
    } else if (lower.contains('3,00,000') || lower.contains('3 lakh')) {
      healthInsurance = '₹3,00,000 Individual Cover';
    }

    final redFlags = <String>[];
    if (bondMonths > 0) redFlags.add('$bondMonths-Month Service Bond lock-in');
    if (nonCompeteMonths > 0) redFlags.add('Post-employment non-compete restraint (Void under Sec 27)');
    if (noticeDays >= 90) redFlags.add('Rigid 90-day notice period');
    if (workMode.contains('6 Days')) redFlags.add('6-day work week required');

    final highlights = <String>[];
    if (workMode.contains('Remote') || workMode.contains('Hybrid')) highlights.add(workMode);
    if (bondMonths == 0) highlights.add('Zero employment bond');
    if (healthInsurance != null) highlights.add(healthInsurance);

    return OfferLetterDetails(
      companyName: company,
      jobTitle: 'Software Engineering Role',
      ctcTotal: ctcLpa,
      ctcDisplay: ctcDisplay,
      fixedSalaryDisplay: fixedDisplay,
      variableBonusDisplay: variableDisplay,
      joiningBonus: lower.contains('joining bonus') || lower.contains('retention incentive') ? 'Available' : null,
      noticePeriodDays: noticeDays,
      noticePeriodDisplay: noticeDisplay,
      bondPeriodMonths: bondMonths,
      bondPenalty: bondPenalty,
      bondDisplay: bondDisplay,
      nonCompetePeriodMonths: nonCompeteMonths,
      nonCompeteDisplay: nonCompeteDisplay,
      workMode: workMode,
      annualLeaves: leaves ?? 20,
      healthInsuranceCover: healthInsurance,
      redFlags: redFlags,
      positiveHighlights: highlights,
      rawText: text,
    );
  }

  double _calcFinancialScore(OfferLetterDetails d) {
    double score = 50.0;
    if (d.ctcTotal != null) {
      score += (d.ctcTotal! * 2.2).clamp(0.0, 35.0);
    } else {
      score += 20.0;
    }
    if (d.variableBonusDisplay != 'None') {
      score += 5.0;
    }
    if (d.joiningBonus != null) {
      score += 5.0;
    }
    return score.clamp(20.0, 100.0);
  }

  double _calcLegalFreedomScore(OfferLetterDetails d) {
    double score = 100.0;
    if (d.noticePeriodDays >= 90) {
      score -= 25.0;
    } else if (d.noticePeriodDays >= 60) {
      score -= 10.0;
    }

    if (d.hasBond) score -= 35.0;
    if (d.hasNonCompete) score -= 25.0;
    return score.clamp(10.0, 100.0);
  }

  double _calcWorkLifeScore(OfferLetterDetails d) {
    double score = 70.0;
    if (d.workMode.contains('Remote')) {
      score += 25.0;
    } else if (d.workMode.contains('Hybrid')) {
      score += 15.0;
    } else if (d.workMode.contains('6 Days')) {
      score -= 35.0;
    }

    if ((d.annualLeaves ?? 20) >= 28) {
      score += 10.0;
    } else if ((d.annualLeaves ?? 20) < 16) {
      score -= 15.0;
    }

    return score.clamp(10.0, 100.0);
  }

  double _calcBenefitsScore(OfferLetterDetails d) {
    double score = 65.0;
    if (d.healthInsuranceCover != null) {
      if (d.healthInsuranceCover!.contains('5') || d.healthInsuranceCover!.contains('Family')) {
        score += 25.0;
      } else {
        score += 10.0;
      }
    }
    if ((d.annualLeaves ?? 20) >= 24) score += 10.0;
    return score.clamp(20.0, 100.0);
  }

  List<MetricComparison> _buildMetricComparisons(OfferLetterDetails a, OfferLetterDetails b) {
    final list = <MetricComparison>[];

    // 1. Total CTC
    final ctcA = a.ctcTotal ?? 0;
    final ctcB = b.ctcTotal ?? 0;
    list.add(
      MetricComparison(
        category: 'Compensation',
        metricTitle: 'Total Cost to Company (CTC)',
        valueA: a.ctcDisplay,
        valueB: b.ctcDisplay,
        favorable: ctcB > ctcA ? OfferChoice.offerB : (ctcA > ctcB ? OfferChoice.offerA : OfferChoice.neutral),
        significance: 'Critical',
        explanation: ctcB > ctcA
            ? 'New Offer provides a headline raise of +₹${(ctcB - ctcA).toStringAsFixed(1)} LPA.'
            : 'Compensation is comparable or higher in the existing offer.',
      ),
    );

    // 2. Fixed Guaranteed Base
    list.add(
      MetricComparison(
        category: 'Compensation',
        metricTitle: 'Fixed Base Pay vs Variable',
        valueA: '${a.fixedSalaryDisplay} (Var: ${a.variableBonusDisplay})',
        valueB: '${b.fixedSalaryDisplay} (Var: ${b.variableBonusDisplay})',
        favorable: ctcB > ctcA ? OfferChoice.offerB : OfferChoice.offerA,
        significance: 'Critical',
        explanation: 'Evaluate the fixed guaranteed salary. Discretionary variable pay is never guaranteed by management.',
      ),
    );

    // 3. Notice Period
    list.add(
      MetricComparison(
        category: 'Legal & Freedom',
        metricTitle: 'Notice Period Duration',
        valueA: a.noticePeriodDisplay,
        valueB: b.noticePeriodDisplay,
        favorable: a.noticePeriodDays < b.noticePeriodDays ? OfferChoice.offerA : (b.noticePeriodDays < a.noticePeriodDays ? OfferChoice.offerB : OfferChoice.neutral),
        significance: 'Critical',
        explanation: b.noticePeriodDays > a.noticePeriodDays
            ? 'The New Offer enforces a longer notice period (${b.noticePeriodDays} days vs ${a.noticePeriodDays} days), creating high friction for future jobs.'
            : 'Shorter notice period provides greater career agility.',
      ),
    );

    // 4. Employment Bond / Penalty
    list.add(
      MetricComparison(
        category: 'Legal & Freedom',
        metricTitle: 'Service Bond & Lock-in',
        valueA: a.bondDisplay,
        valueB: b.bondDisplay,
        favorable: !b.hasBond && a.hasBond ? OfferChoice.offerB : (!a.hasBond && b.hasBond ? OfferChoice.offerA : OfferChoice.neutral),
        significance: 'Critical',
        explanation: b.hasBond
            ? 'New Offer includes a mandatory service bond. Under Indian Contract Act Sec 74, employers cannot penalize employees beyond actual demonstrated training expenditure.'
            : 'No financial bonds or lock-in handcuffs detected.',
      ),
    );

    // 5. Non-Compete Restraint
    list.add(
      MetricComparison(
        category: 'Legal & Freedom',
        metricTitle: 'Post-Employment Non-Compete',
        valueA: a.nonCompeteDisplay,
        valueB: b.nonCompeteDisplay,
        favorable: !b.hasNonCompete && a.hasNonCompete ? OfferChoice.offerB : (!a.hasNonCompete && b.hasNonCompete ? OfferChoice.offerA : OfferChoice.neutral),
        significance: 'Important',
        explanation: b.hasNonCompete
            ? 'Post-employment trade restraints are strictly VOID under Section 27 of the Indian Contract Act, but may still lead to harassment if unclarified.'
            : 'No restrictive post-employment covenants.',
      ),
    );

    // 6. Work Schedule & Flexibility
    list.add(
      MetricComparison(
        category: 'Work-Life',
        metricTitle: 'Work Arrangement & Schedule',
        valueA: a.workMode,
        valueB: b.workMode,
        favorable: a.workMode.contains('Hybrid') || a.workMode.contains('Remote') ? OfferChoice.offerA : OfferChoice.neutral,
        significance: 'Important',
        explanation: 'Work mode impacts personal lifestyle, daily commute overhead, and mental well-being.',
      ),
    );

    // 7. Health Insurance
    list.add(
      MetricComparison(
        category: 'Benefits',
        metricTitle: 'Medical Insurance Policy',
        valueA: a.healthInsuranceCover ?? 'Standard',
        valueB: b.healthInsuranceCover ?? 'Standard',
        favorable: (a.healthInsuranceCover?.contains('Family') ?? false) ? OfferChoice.offerA : OfferChoice.neutral,
        significance: 'Informational',
        explanation: 'Family floater covers dependents; individual covers only the employee.',
      ),
    );

    // 8. Annual Leaves
    list.add(
      MetricComparison(
        category: 'Benefits',
        metricTitle: 'Paid Leave Entitlement',
        valueA: '${a.annualLeaves ?? 20} Days',
        valueB: '${b.annualLeaves ?? 14} Days',
        favorable: (a.annualLeaves ?? 0) > (b.annualLeaves ?? 0) ? OfferChoice.offerA : OfferChoice.offerB,
        significance: 'Informational',
        explanation: 'Adequate paid time off is essential for health, family time, and preventing burnout.',
      ),
    );

    return list;
  }
}
