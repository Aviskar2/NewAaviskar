# Gemini AI Fraud Detection & API Configuration Guide

This document explains how **Google Gemini AI** is integrated into the ScanSure application for real-time visual invoice & legal document fraud detection, where the API keys are stored, how the fallback system works, and how recent performance and encoding issues were resolved.

---

## 1. Where to Place API Keys

### Primary Configuration File: `lib/config/api_config.dart`
The application centrally manages all cloud intelligence and fraud detection API keys inside `ApiConfig`.

- **Gemini API Key (Primary)**:
  ```dart
  // lib/config/api_config.dart
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  ```
  This key connects directly to Google Generative Language endpoints:
  - **Base URL**: `https://generativelanguage.googleapis.com/v1beta`
  - **Model fallback chain**: defined once in `ApiConfig.geminiCandidateModels` (`lib/config/api_config.dart`) and shared by every Gemini call site (`GeminiFraudService`, `OfferLetterAnalyzerService`) — currently `gemini-3.8-flash` → `gemini-3.6-flash` → `gemini-flash-latest` (a rolling alias that always resolves to Google's current default Flash model).
  - Previously each service hardcoded its own model list independently; two of the three lists referenced models Google has since deprecated/shut down (`gemini-1.5-flash`, `gemini-2.0-flash`, `gemini-2.5-flash`). Always update `ApiConfig.geminiCandidateModels` — never add a new hardcoded list in a service file.

- **OpenRouter API Key (Secondary Fallback)**:
  ```dart
  // lib/config/api_config.dart
  static const String openRouterApiKey = 'sk-or-v1-...';
  ```

### Runtime Key Override (Settings Screen)
Users can also input or override custom API keys at runtime without modifying code:
- Stored locally via `SharedPreferences` in `AppSettings` (`lib/config/app_settings.dart`).
- Runtime precedence: If a user enters a key in **Settings → AI Features**, `AppSettings.geminiApiKey` automatically takes priority over the compile-time default.

---

## 2. Technical Fixes Applied

### Fix 1: Gemini Request Crash (Encoding Error)
- **Symptom**: `Gemini HTTP request error: Invalid argument (string): Contains invalid characters.`
- **Root Cause**: Dart's `HttpClient` defaulted to `latin1` encoding when writing string payloads. Characters such as non-breaking spaces (`\u00A0`), rupee signs (`₹`), and Hindi/regional OCR text failed Latin-1 conversion.
- **Resolution**:
  1. Set explicit content type header:
     ```dart
     request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
     request.encoding = utf8;
     ```
  2. Direct UTF-8 byte stream output:
     ```dart
     final jsonStr = jsonEncode(body).replaceAll('\u00A0', ' ');
     final utf8Bytes = utf8.encode(jsonStr);
     request.contentLength = utf8Bytes.length;
     request.add(utf8Bytes);
     ```
  3. Sanitized all prompt and OCR strings with `.replaceAll('\u00A0', ' ')`.

### Fix 2: OpenRouter Fallback Rate-Limiting (HTTP 429)
- **Symptom**: Rapid HTTP 429 ("Too Many Requests") errors when cycling through fallback models.
- **Root Cause**: When a model failed, the fallback loop instantly fired requests to subsequent free-tier models, triggering rate-limit thresholds.
- **Resolution**:
  - Implemented exponential backoff delays between model attempts (`lib/services/llm_bill_service.dart` and `lib/services/legal/local_legal_llm_service.dart`):
    ```dart
    int attempt = 0;
    for (final model in candidates) {
      if (attempt > 0) {
        final backoffMs = (400 * (1 << (attempt - 1))).clamp(400, 1500);
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
      attempt++;
      // Call model...
    }
    ```
  - Added explicit UTF-8 encoding headers (`Content-Type: application/json; charset=utf-8`) to OpenRouter calls.

### Fix 3: UI Frame Skips (Skipped 82 frames)
- **Symptom**: UI froze for ~1.5 seconds during document analysis.
- **Root Cause**: PDF text extraction (`PdfTextExtractor(pdfDocument)`) and Word DOCX XML decompression ran synchronously on Flutter's main UI thread.
- **Resolution**:
  - Offloaded heavy CPU work into background isolates using Dart's `Isolate.run()` in `lib/screens/legal_analyzer/legal_analyzer_entry_screen.dart`:
    ```dart
    // Extracts PDF text on a background worker thread
    final pageTexts = await Isolate.run(() => _extractPdfPagesSync(bytes));

    // Decompresses DOCX archive on a background worker thread
    final text = await Isolate.run(() => _extractDocxTextSync(bytes));
    ```
  - Result: Smooth 60 FPS UI transitions with zero main thread blocking.

---

## 3. How Fraud Detection Operates

The application runs a multi-layered verification pipeline:

1. **Deterministic Parser**: Extracts raw text, line items, and basic totals.
2. **Gemini AI Multimodal Visual & Text Audit**:
   - **Service Charge Violations**: Flags forced or automatic restaurant/hotel service charges under CCPA July 2022 Guidelines (unfair trade practice).
   - **GST Anti-Profiteering & Fraud**: Flags non-standard GST slabs (e.g. 18.03%), unauthorized GST collection, and double taxation.
   - **Arithmetic Manipulation**: Identifies math mismatches where subtotal + taxes ≠ grand total.
   - **Handwritten Parchi/Slip Audit**: Reads handwritten items, quantities, and flags altered digits.
   - **Legal Document Void Clauses**: Identifies Section 27 void non-competes, illegal arbitration clauses, and excessive security deposits (>2 months under Model Tenancy Act).
3. **Statutory Law Matching**: Cross-references findings with the Central Consumer Protection Authority (CCPA), Central Board of Indirect Taxes and Customs (CBIC), and India Code.
4. **Consumer Recourse Guidance**: Provides direct filing advice for the National Consumer Helpline (1915) and INGRAM portal.

---

## 4. Verification Commands

Run unit tests:
```bash
flutter test test/gemini_fraud_detector_test.dart
```

Run full suite:
```bash
flutter test test/bill_analyzer_test.dart test/legal_analyzer_test.dart
```

Run static analysis:
```bash
flutter analyze
```
