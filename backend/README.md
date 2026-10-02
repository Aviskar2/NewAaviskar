# ScanSure AI Document Risk Analysis Backend Service

Secure proxy backend implementing the Indian legal document risk analysis pipeline.

## Architectural Security (Sections 33 & 34)
- **Zero Client-Side Keys**: The Flutter mobile app never embeds, sends, or stores raw AI provider API keys.
- **Provider Decoupling**: Uses `BaseAIProvider` abstraction to support Google Gemini, OpenAI, Claude, and OpenRouter without altering mobile UI or scoring logic.
- **Strict Verification**: Enforces controlled Indian statutory cross-referencing (BNS 2023, BSA 2023, Indian Contract Act 1872, RERA, Model Tenancy Act).
- **Evidence-Based Dynamic Scoring**: Automatically computes dynamic risk scores (Section 39) with diminishing returns (0-100), rejecting un-evidenced hallucinated findings.

## Quick Start

```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your GEMINI_API_KEY or OPENROUTER_API_KEY
npm start
```

Runs by default on `http://localhost:3001`.

## Endpoints

### `POST /api/analyze-document`
Request:
```json
{
  "documentText": "Agreement text...",
  "documentType": "loan_agreement",
  "language": "en",
  "country": "IN",
  "clauses": [
    { "id": "clause_001", "text": "..." }
  ]
}
```

Response:
```json
{
  "analysisId": "an_1727712000000",
  "documentType": "loan_agreement",
  "overallRisk": {
    "level": "high",
    "score": 82,
    "confidence": "medium"
  },
  "summary": "Several clauses require review.",
  "findings": [...],
  "checks": {
    "partyConsistency": { "status": "pass" },
    "dateConsistency": { "status": "warning" },
    "structure": { "status": "pass" }
  },
  "model": "Gemini (gemini-2.5-flash)",
  "analyzedAt": "2026-09-30T16:30:00.000Z"
}
```

### `GET /api/health`
Checks backend health and active AI provider.
