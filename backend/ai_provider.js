/**
 * Provider Abstraction for Document Risk Analysis (Section 33 & 36 & 46).
 *
 * Keeps the application decoupled from any single AI vendor.
 * Models can be swapped without changing client or scoring logic.
 */

const SYSTEM_PROMPT = `You are an AI document-risk analysis system specializing in Indian contracts, agreements, and legal documents.

Analyze the supplied document using its actual content.

Do not assume fraud merely because a suspicious keyword appears.
Consider the full context of each clause.

Identify potential:
1. Suspicious payment terms
2. Upfront payment requirements
3. Unusual deposits
4. Hidden charges
5. Excessive penalties
6. One-sided obligations
7. Unclear repayment terms
8. Identity / party inconsistencies
9. Contradictory dates
10. Suspicious guarantees
11. Coercive or deceptive wording
12. Potential misrepresentation
13. Unusual authorization clauses
14. Unreasonable liability transfer
15. Potentially unlawful or unenforceable provisions
16. Document inconsistencies
17. Missing important information
18. Signs commonly associated with scams

Every finding must cite an exact document excerpt and clause ID.

Distinguish:
1. legal risk
2. financial risk
3. suspicious wording
4. potential deceptive conduct
5. confirmed factual inconsistency

Do not claim that fraud has occurred solely from the document text.
Do not invent laws, legal sections, case law, facts, or parties.
If evidence is insufficient, explicitly say so.

Return valid raw JSON only conforming strictly to this schema:
{
  "documentType": "loan_agreement|rental_agreement|employment_agreement|service_agreement|sale_agreement|nda|insurance_document|vendor_agreement|unknown",
  "summary": "Concise summary of findings.",
  "findings": [
    {
      "id": "finding_001",
      "clauseId": "clause_001",
      "category": "suspicious_payment_term|upfront_payment|unusual_deposit|hidden_charge|excessive_penalty|one_sided_obligation|unclear_repayment|identity_inconsistency|contradictory_dates|unreasonable_liability_transfer|unenforceable_provision",
      "severity": "high|medium|low",
      "confidence": "high|medium|low",
      "scoreContribution": 28,
      "title": "Short title describing the risk indicator",
      "excerpt": "Exact text quoted directly from the clause",
      "explanation": "Why this text is suspicious or risky in context.",
      "recommendedAction": "Actionable guidance for the user before signing.",
      "legalReferences": [
        {
          "law": "Bharatiya Nyaya Sanhita, 2023",
          "section": "318",
          "relevance": "Potentially relevant to deceptive inducement."
        }
      ]
    }
  ],
  "checks": {
    "partyConsistency": { "status": "pass|warning|fail" },
    "dateConsistency": { "status": "pass|warning|fail" },
    "structure": { "status": "pass|warning|fail" }
  }
}`;

class BaseAIProvider {
  constructor(name) {
    this.name = name;
  }

  async analyze(documentText, clauses, documentType, options = {}) {
    throw new Error('analyze() must be implemented by subclass');
  }
}

class GeminiAIProvider extends BaseAIProvider {
  constructor(apiKey, model = 'gemini-2.5-flash') {
    super(`Gemini (${model})`);
    this.apiKey = apiKey;
    this.model = model;
  }

  async analyze(documentText, clauses, documentType, options = {}) {
    const clausesFormatted = clauses && clauses.length > 0
      ? clauses.map(c => `[${c.id}] ${c.text}`).join('\n\n')
      : documentText;

    const userPrompt = `DOCUMENT TYPE: ${documentType}\nLANGUAGE: ${options.language || 'en'}\nCOUNTRY: ${options.country || 'IN'}\n\nCLAUSES TO ANALYZE:\n${clausesFormatted}`;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          { role: 'user', parts: [{ text: `${SYSTEM_PROMPT}\n\n${userPrompt}` }] }
        ],
        generationConfig: {
          responseMimeType: 'application/json',
          temperature: 0.1
        }
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Gemini API error (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const candidate = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!candidate) throw new Error('Empty response from Gemini API');

    return JSON.parse(candidate);
  }
}

class OpenAIAIProvider extends BaseAIProvider {
  constructor(apiKey, baseUrl = 'https://api.openai.com/v1', model = 'gpt-4o-mini') {
    super(`OpenAI (${model})`);
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.model = model;
  }

  async analyze(documentText, clauses, documentType, options = {}) {
    const clausesFormatted = clauses && clauses.length > 0
      ? clauses.map(c => `[${c.id}] ${c.text}`).join('\n\n')
      : documentText;

    const userPrompt = `DOCUMENT TYPE: ${documentType}\nLANGUAGE: ${options.language || 'en'}\nCOUNTRY: ${options.country || 'IN'}\n\nCLAUSES TO ANALYZE:\n${clausesFormatted}`;

    const response = await fetch(`${this.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        model: this.model,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userPrompt }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.1
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`AI API error (${response.status}): ${errText}`);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) throw new Error('Empty response from AI API');

    return JSON.parse(content);
  }
}

module.exports = {
  BaseAIProvider,
  GeminiAIProvider,
  OpenAIAIProvider,
  SYSTEM_PROMPT
};
