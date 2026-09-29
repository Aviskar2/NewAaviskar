# Government Schemes & Citizen Rights: Data Fetching, Storage & Matching Architecture

This document provides a comprehensive technical overview of how government scheme data is structured, fetched, stored, matched, and managed within the application.

---

## 1. Architecture Overview & Core Philosophy

The Government Schemes & Citizen Rights module is built around three core principles:

1. **Offline-First & High Reliability**: Citizens (especially in rural, low-connectivity areas) can browse, search, and check eligibility for 147+ Central and State government schemes with zero network latency.
2. **Privacy-Preserving On-Device Matching**: All demographic and socio-economic profile data (income, caste category, disability status, etc.) resides strictly on the user's device and is never transmitted to any third-party server.
3. **Actionable & Transparent**: Every scheme provides verified official portal links, helpline numbers, document requirements, and plain-language summaries so users can directly act on their entitlements.

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                     │
│  - Top Navigation & Profile Readiness                       │
│  - Quick Utilities Strip (Saved, Tracker, Compare, Insights)│
│  - Inline Eligibility & Benefit Matcher                     │
│  - Scope Pills (Central / State / All)                      │
│  - Category Chips (with dynamic count badges)               │
│  - 3-Column Highlight Scheme Cards                          │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼                               ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│      SchemeMatcher Engine    │ │     SchemeService (Store)  │
│  - 2-Tier Eligibility Filter │ │  - SharedPreferences      │
│  - Hard Disqualifications    │ │  - Bookmarks & Compares    │
│  - Weighted Soft Scoring     │ │  - Application Lifecycle   │
└──────────────┬───────────────┘ └─────────────┬──────────────┘
               │                               │
               └───────────────┬───────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  SchemeDatabase (Local Dataset)             │
│  - 147+ Verified Central & State Schemes                    │
│  - Indexed by Category, Level, State, Ministry, Keywords   │
│  - Standardized SchemeEligibility & Highlight Contracts     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Data Models & Schemas

### 2.1 `GovernmentScheme` (`lib/models/government_scheme_model.dart`)
Defines the structure of a government scheme:
* **Identification**: `id` (e.g. `'ayushman_bharat_pmjay'`), `name`, `shortName` (e.g. `'PMJAY'`).
* **Categorization**: `category` (`SchemeCategory` enum: Health, Agriculture, Education, Housing, Finance, etc.), `level` (`SchemeLevel.central` or `SchemeLevel.state`), `stateCode` (e.g. `'UP'`, `'MH'`, `'IN'`).
* **Governance**: `ministry` (e.g. `'Ministry of Health and Family Welfare'`), `helpline` (e.g. `'14555'`).
* **Descriptions**: `description` (official description), `plainLanguageSummary` (simple, jargon-free summary).
* **Eligibility Rules**: Embedded `SchemeEligibility` object.
* **Benefits & Documents**: `benefits` (`List<String>`), `documentsRequired` (`List<String>`).
* **Links**: `applyUrl`, `effectiveApplyUrl` (sanitized, verified portal link), `mySchemeUrl` (direct search on official `myscheme.gov.in`).

### 2.2 `SchemeEligibility`
Rules that define who can benefit from the scheme:
* **Demographics**: `minAge`, `maxAge`, `gender` (`all`, `male`, `female`, `transgender`).
* **Geography**: `eligibleStates` (`List<String>`).
* **Economic**: `maxAnnualIncome` (`double?`), `isBPLRequired` (`bool`).
* **Social & Vulnerability**: `isSCSTRequired`, `isFarmerRequired`, `isStudentRequired`, `isDisabledRequired`, `isWidowRequired`, `isMinorityRequired`.
* **Occupation**: `occupations` (`List<String>`), `occupationRequired` (`String?`).

### 2.3 `CitizenProfile`
Represents the local user's profile used for matching:
* `name`, `age`, `gender`, `annualIncome`, `state`, `district`.
* `occupation` (e.g. `'Farmer / Agri Worker'`, `'Student / Youth'`, etc.).
* Vulnerability flags: `isBPL`, `isSCST`, `isFarmer`, `isStudent`, `isDisabled`, `isSeniorCitizen`, `isWoman`, `isWidow`, `isMinority`.
* Helper `hasProfile`: returns true when name, age, and state are configured.

### 2.4 `SchemeBookmark` & `ApplicationRecord` (`lib/services/scheme_service.dart`)
Tracks citizen interactions:
* `SchemeBookmark`: `schemeId`, `savedAt` timestamp.
* `ApplicationRecord`: `schemeId`, `status` (`notApplied`, `inProgress`, `applied`, `received`, `rejected`), `appliedAt`, `deadline`, `notes`, `documentsSubmitted`.

---

## 3. Storage Architecture

Scheme data and user state are stored locally using two mechanisms:

### 3.1 Static Scheme Catalog (`SchemeDatabase`)
The catalog is stored in-memory within `lib/services/scheme_database.dart` as immutable Dart objects.
* **Benefits**:
  - Instant zero-millisecond retrieval without asynchronous network overhead.
  - 100% offline functionality.
  - Fully typed, preventing runtime parsing exceptions.
* **Data Scale**: 147+ schemes spanning Central Government and Indian States/UTs.

### 3.2 Persistent User State (`SharedPreferences`)
All user data and actions are stored in persistent key-value storage:

| Storage Key | Format | Data Contained |
|---|---|---|
| `citizen_profile` | JSON Object | User's age, gender, state, income, and vulnerability tags |
| `scheme_bookmarks` | JSON Array | Array of `{ schemeId, savedAt }` objects |
| `scheme_applications`| JSON Array | Array of `{ schemeId, status, appliedAt, deadline, notes, documentsSubmitted }` |
| `scheme_compare` | JSON Array | Array of scheme IDs currently selected for side-by-side comparison (max 3) |

Whenever the user saves their profile, bookmarks a scheme, changes an application status, or selects schemes for comparison, `SchemeService` commits the changes to `SharedPreferences`.

---

## 4. Matching & Scoring Engine (`SchemeMatcher`)

The engine computes an eligibility match score from **0.0 (0%)** to **1.0 (100%)** for each scheme against a profile:

### Step 1: Hard Disqualification Checks (Immediate 0% Score)
If a citizen fails any mandatory statutory requirement, the scheme score drops to `0.0` with an explicit rejection reason:
1. **Age Thresholds**: Fails if `profile.age < elig.minAge` or `profile.age > elig.maxAge`.
2. **Gender Exclusivity**: Fails if scheme is restricted to women and user is not female.
3. **State Jurisdiction**: For state-specific schemes, fails if `elig.eligibleStates` does not include `profile.state`.
4. **Mandatory Categories**:
   - BPL required and user is not BPL.
   - Farmer status required and user is not a farmer.
   - SC/ST required and user is not SC/ST.
   - Disability required and user is not disabled.
   - Student status required and user is not a student.
   - Minority status required and user is not in a minority group.

### Step 2: Soft Criteria & Weighted Scoring
If hard checks pass, points are added based on relevance:
* **Base Eligibility**: +0.30 base score.
* **Income Fit**: +0.25 if `profile.annualIncome <= elig.maxAnnualIncome`.
* **Occupation Match**: +0.25 if user's occupation matches scheme's target occupations.
* **Geographical Fit**: +0.15 if the scheme is specifically targeted to the citizen's state.
* **Vulnerability Boost**: +0.10 for matched special category criteria (BPL, PwD, Widow, etc.).

Results are sorted descending by match score so the citizen sees the most relevant and high-value schemes first.

---

## 5. Dynamic Data Fetching & Sync Strategy (Current vs Future)

### Current Implementation
- **Curated Dataset**: Embedded directly in the application bundle.
- **URL Sanitization**: Active URL resolvers (`effectiveApplyUrl`) normalize broken or redirected ministerial URLs (e.g. mapping legacy `pmayg.nic.in` to `pmayg.gov.in`).
- **myScheme Fallback**: Dynamic integration with `https://www.myscheme.gov.in/search?q={query}` ensuring 100% reachable official guidance for any scheme.

### Future Remote Sync Pipeline
For over-the-air updates without releasing a new app version:
1. **Periodic Background Fetch**:
   - A background sync task (e.g. `workmanager` or periodic timer) checks a remote manifest: `GET /api/v1/schemes/version`.
2. **Delta Download**:
   - If version > local version, download updated JSON payload: `GET /api/v1/schemes/delta?since={timestamp}`.
3. **Local Cache Invalidation**:
   - The JSON payload is stored in local SQLite or encrypted Hive/SharedPref storage, merging with `SchemeDatabase.schemes`.
4. **Offline Resilience**:
   - If offline or network fails, app transparently falls back to the embedded static dataset.

---

## 6. UI/UX Integration (Stitch MCP Unified Design)

The redesigned interface (`lib/screens/government_schemes/government_schemes_entry_screen.dart`) binds directly to this data pipeline:

1. **Quick Utilities Strip**:
   - **Saved**: Displays live count from `_service.bookmarks.length`.
   - **Tracker**: Displays live pending count from `_service.pendingCount`.
   - **Compare**: Displays live compare count from `_service.compareIds.length`.
   - **Insights**: Indicates profile readiness and opens `SchemeAnalyticsScreen`.
2. **Compact Eligibility Matcher**:
   - Lets users dynamically tweak State, Occupation, Income, and Vulnerabilities without leaving the page.
   - Automatically runs transient profile through `SchemeMatcher` upon clicking *"Show XX Matching Schemes"*.
3. **Category Chips**:
   - Compute matching scheme counts dynamically per category (`🌾 Agriculture (14)`, `🏥 Health (8)`, etc.).
4. **3-Column Highlight Scheme Cards**:
   - Extracts and displays **Key Benefit**, **Target Group**, and **Delivery Mode** (e.g. *Direct DBT*, *Cashless Card*).
   - "Check Rules" launches `SchemeDetailScreen`.
   - "Apply Online" launches official portal via `UrlLauncherUtil`.
