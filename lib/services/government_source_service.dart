/// Government source service.
/// Provides cached government rules with source metadata.
/// Attempts live GSTIN format/checksum validation offline.
/// Attempts best-effort HTTP verification online — clearly marks LIVE vs CACHED.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';

class GovernmentSourceService {
  static final DateTime _cacheDate = DateTime(2024, 8, 1);

  // ─── Cached Government Sources ────────────────────────────────────────────

  GovernmentSource get arithmeticSource => GovernmentSource(
        title: 'GST Arithmetic Verification',
        description: 'Bills must accurately reflect taxable value, GST amounts, and grand total.',
        url: 'https://www.gst.gov.in/',
        organization: 'GST Council / CBIC',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  GovernmentSource get cgstSource => GovernmentSource(
        title: 'CGST Act, 2017 — Tax Calculation Rules',
        description:
            'Under GST, for intra-state supplies CGST + SGST are each half the applicable GST rate.',
        url: 'https://cbic-gst.gov.in/gst-goods-services-rates.html',
        organization: 'CBIC — Central Board of Indirect Taxes and Customs',
        effectiveDate: '1 July 2017',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  GovernmentSource get sgstSource => GovernmentSource(
        title: 'SGST — State Goods and Services Tax',
        description:
            'SGST is collected by the state government; for intra-state supplies, SGST equals CGST.',
        url: 'https://cbic-gst.gov.in/gst-goods-services-rates.html',
        organization: 'CBIC',
        effectiveDate: '1 July 2017',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  GovernmentSource get igstSource => GovernmentSource(
        title: 'IGST — Integrated Goods and Services Tax',
        description:
            'IGST applies for inter-state supplies. IGST = CGST + SGST combined rate.',
        url: 'https://cbic-gst.gov.in/gst-goods-services-rates.html',
        organization: 'CBIC',
        effectiveDate: '1 July 2017',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  GovernmentSource get gstinSource => GovernmentSource(
        title: 'GST Taxpayer Search',
        description:
            'The GST portal provides taxpayer information for registered businesses.',
        url: 'https://www.gst.gov.in/searchtaxpayer',
        organization: 'GST Portal — Government of India',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  GovernmentSource get ccpaServiceChargeSource => GovernmentSource(
        title: 'CCPA Guidelines — Service Charge in Hotels/Restaurants',
        description:
            'CCPA issued guidelines that service charge should not be collected '
            'mandatorily, and consumers are not obligated to pay it if added automatically.',
        url: 'https://consumeraffairs.gov.in/sites/default/files/file-uploads/latestnews/Guidelines%20on%20Service%20Charge%20-%20CCPA%202022.pdf',
        organization: 'Central Consumer Protection Authority (CCPA)',
        effectiveDate: '4 July 2022',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
        confidence: 0.95,
      );

  GovernmentSource get consumerProtectionSource => GovernmentSource(
        title: 'Consumer Protection Act, 2019',
        description: 'Protects consumers from unfair trade practices and misleading representations.',
        url: 'https://consumeraffairs.gov.in/consumer-protection-act-2019',
        organization: 'Ministry of Consumer Affairs, Food and Public Distribution',
        effectiveDate: '20 July 2020',
        lastVerified: _cacheDate,
        status: SourceVerificationStatus.cached,
      );

  List<GovernmentSource> get allSources => [
        cgstSource,
        sgstSource,
        igstSource,
        gstinSource,
        ccpaServiceChargeSource,
        consumerProtectionSource,
      ];

  // ─── GSTIN Validation ─────────────────────────────────────────────────────

  /// Validate GSTIN offline (format + MOD-37 checksum) and attempt online lookup.
  Future<GstinVerification> verifyGstin(String gstin, {String? sellerName}) async {
    final cleaned = gstin.trim().toUpperCase();

    // 1. Format check
    final formatRegex = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}$');
    if (!formatRegex.hasMatch(cleaned)) {
      return GstinVerification(
        gstin: cleaned,
        status: GstinStatus.formatError,
        errorMessage: 'GSTIN format is invalid. Expected: 15 characters (2-digit state + 10-char PAN + 1 + Z + 1).',
      );
    }

    // 2. Checksum verification (MOD-37)
    final checksumValid = _verifyGstinChecksum(cleaned);
    if (!checksumValid) {
      return GstinVerification(
        gstin: cleaned,
        status: GstinStatus.invalid,
        errorMessage: 'GSTIN checksum is invalid. This GSTIN may be fabricated.',
      );
    }

    // 3. State code check
    final stateCode = cleaned.substring(0, 2);
    final stateName = _stateCodeMap[stateCode];

    // 4. Attempt live online verification (best-effort, graceful failure)
    try {
      final liveResult = await _attemptLiveVerification(cleaned, sellerName);
      if (liveResult != null) return liveResult;
    } catch (e) {
      debugPrint('Live GSTIN verification failed: $e');
    }

    // 5. Return offline result
    return GstinVerification(
      gstin: cleaned,
      status: GstinStatus.valid,
      stateCode: stateName != null ? '$stateCode ($stateName)' : stateCode,
      isLiveVerified: false,
      nameMatchesSeller: false,
      errorMessage: 'Offline format check passed. Live verification unavailable — '
          'please verify on https://www.gst.gov.in/searchtaxpayer',
    );
  }

  /// MOD-37 checksum validation for GSTIN.
  bool _verifyGstinChecksum(String gstin) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const factor = 2;
    int sum = 0;
    int fac = factor;
    for (int i = gstin.length - 2; i >= 0; i--) {
      int codePoint = chars.indexOf(gstin[i]);
      if (codePoint == -1) return false;
      int digit = fac * codePoint;
      fac = (fac == 2) ? 1 : 2;
      digit = (digit ~/ 36) + (digit % 36);
      sum += digit;
    }
    int remainder = (36 - (sum % 36)) % 36;
    final expected = chars[remainder];
    return gstin[gstin.length - 1] == expected;
  }

  /// Best-effort online lookup — returns null if not available.
  Future<GstinVerification?> _attemptLiveVerification(
      String gstin, String? sellerName) async {
    // The official GST taxpayer lookup requires authentication tokens.
    // We attempt a known public search endpoint — this may not always work.
    // If it fails, we return null (caller uses offline result).
    try {
      final url = Uri.parse(
        'https://taxpayersearch.gst.gov.in/taxpayersearch/getTaxpayerData?gstin=$gstin',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['taxpayerInfo'] != null) {
          final info = data['taxpayerInfo'];
          final legalName = info['lgnm']?.toString();
          final tradeName = info['tradeName']?.toString();
          final status = info['sts']?.toString();
          final regDate = info['rgdt']?.toString();

          final nameMatch = sellerName != null &&
              legalName != null &&
              _namesMatch(sellerName, legalName);

          return GstinVerification(
            gstin: gstin,
            status: GstinStatus.valid,
            legalName: legalName,
            tradeName: tradeName,
            registrationStatus: status,
            registrationDate: regDate,
            isLiveVerified: true,
            nameMatchesSeller: nameMatch,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  bool _namesMatch(String a, String b) {
    String clean(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    return clean(a).contains(clean(b).substring(0, (clean(b).length * 0.6).round())) ||
        clean(b).contains(clean(a).substring(0, (clean(a).length * 0.6).round()));
  }

  // ─── State code map ───────────────────────────────────────────────────────

  static const Map<String, String> _stateCodeMap = {
    '01': 'Jammu & Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '26': 'Dadra & Nagar Haveli',
    '27': 'Maharashtra',
    '28': 'Andhra Pradesh (Old)',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman & Nicobar',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
    '97': 'Other Territory',
    '99': 'Centre Jurisdiction',
  };
}
