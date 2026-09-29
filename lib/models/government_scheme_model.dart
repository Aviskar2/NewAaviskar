/// Government Scheme & Citizen Rights data models.
library;

enum SchemeCategory {
  health,
  education,
  agriculture,
  housing,
  finance,
  socialWelfare,
  employment,
  womenChild,
  seniorCitizen,
  disability,
  food,
  digital,
  insurance,
  pension,
}

extension SchemeCategoryX on SchemeCategory {
  String get label {
    switch (this) {
      case SchemeCategory.health: return 'Health';
      case SchemeCategory.education: return 'Education';
      case SchemeCategory.agriculture: return 'Agriculture';
      case SchemeCategory.housing: return 'Housing';
      case SchemeCategory.finance: return 'Finance & Loans';
      case SchemeCategory.socialWelfare: return 'Social Welfare';
      case SchemeCategory.employment: return 'Employment';
      case SchemeCategory.womenChild: return 'Women & Child';
      case SchemeCategory.seniorCitizen: return 'Senior Citizens';
      case SchemeCategory.disability: return 'Disability';
      case SchemeCategory.food: return 'Food Security';
      case SchemeCategory.digital: return 'Digital India';
      case SchemeCategory.insurance: return 'Insurance';
      case SchemeCategory.pension: return 'Pension';
    }
  }

  String get emoji {
    switch (this) {
      case SchemeCategory.health: return '\u{1F3E5}';
      case SchemeCategory.education: return '\u{1F393}';
      case SchemeCategory.agriculture: return '\u{1F33E}';
      case SchemeCategory.housing: return '\u{1F3E0}';
      case SchemeCategory.finance: return '\u{1F3E6}';
      case SchemeCategory.socialWelfare: return '\u{1F91D}';
      case SchemeCategory.employment: return '\u{1F4BC}';
      case SchemeCategory.womenChild: return '\u{1F469}\u200D\u{1F467}';
      case SchemeCategory.seniorCitizen: return '\u{1F9D3}';
      case SchemeCategory.disability: return '\u{267F}';
      case SchemeCategory.food: return '\u{1F35A}';
      case SchemeCategory.digital: return '\u{1F4F1}';
      case SchemeCategory.insurance: return '\u{1F6E1}';
      case SchemeCategory.pension: return '\u{1F4B5}';
    }
  }
}

enum SchemeLevel { central, state, both }

enum EligibilityGender { all, male, female, transgender }

class SchemeEligibility {
  final int? minAge;
  final int? maxAge;
  final EligibilityGender gender;
  final double? maxAnnualIncome;
  final List<String> eligibleStates;
  final List<String> categories;
  final bool isBPLRequired;
  final bool isSCSTRequired;
  final String? occupationRequired;
  final List<String> occupations;
  final bool isFarmerRequired;
  final bool isStudentRequired;
  final bool isDisabledRequired;
  final bool isWidowRequired;
  final bool isMinorityRequired;
  final String? description;

  const SchemeEligibility({
    this.minAge,
    this.maxAge,
    this.gender = EligibilityGender.all,
    this.maxAnnualIncome,
    this.eligibleStates = const [],
    this.categories = const [],
    this.isBPLRequired = false,
    this.isSCSTRequired = false,
    this.occupationRequired,
    this.occupations = const [],
    this.isFarmerRequired = false,
    this.isStudentRequired = false,
    this.isDisabledRequired = false,
    this.isWidowRequired = false,
    this.isMinorityRequired = false,
    this.description,
  });
}

class GovernmentScheme {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final String _plainLanguageSummary;
  final SchemeCategory category;
  final SchemeLevel level;
  final String ministry;
  final SchemeEligibility eligibility;
  final String applyUrl;
  final String helpline;
  final List<String> benefits;
  final List<String> documentsRequired;
  final String? stateCode;
  final bool isActive;

  /// Returns clear, professional English description of the scheme.
  String get plainLanguageSummary =>
      description.isNotEmpty ? description : _plainLanguageSummary;

  /// Official myScheme portal search URL (100% active and verified by Govt of India).
  String get mySchemeUrl =>
      'https://www.myscheme.gov.in/search?q=${Uri.encodeComponent(shortName.isNotEmpty ? shortName : name)}';

  /// Returns the verified modern and reachable URL for official application.
  String get effectiveApplyUrl {
    final raw = applyUrl.trim();
    if (raw.contains('pmayg.nic.in')) return 'https://pmayg.gov.in';
    if (raw.contains('nsap.nic.in')) return 'https://nsap.dord.gov.in';
    if (raw.contains('nregasrep.nic.in')) return 'https://nrega.dord.gov.in';
    if (raw.contains('betibachao.nic.in')) {
      return 'https://wcd.gov.in/schemes/beti-bachao-beti-padhao-scheme';
    }
    if (raw.contains('wcd.nic.in/schemes/pradhan-mantri-matru-vandana-yojana')) {
      return 'https://pmmvy.wcd.gov.in';
    }
    if (raw.contains('wcd.nic.in')) return 'https://wcd.gov.in';
    if (raw.contains('yasasvi.nta.nic.in')) return 'https://yet.nta.ac.in';
    if (raw.contains('pmss.colleges.nic.in')) return 'https://www.aicte-india.org';
    if (raw.contains('jeevanjyotibima')) {
      return 'https://financialservices.gov.in/beta/en/pradhan-mantri-jeevan-jyoti-bima-yojana-pmjjby';
    }
    if (raw.contains('shipsurancebima')) {
      return 'https://financialservices.gov.in/beta/en/pradhan-mantri-suraksha-bima-yojana-pmsby';
    }
    return raw;
  }

  const GovernmentScheme({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required String plainLanguageSummary,
    required this.category,
    required this.level,
    required this.ministry,
    required this.eligibility,
    required this.applyUrl,
    this.helpline = '',
    this.benefits = const [],
    this.documentsRequired = const [],
    this.stateCode,
    this.isActive = true,
  }) : _plainLanguageSummary = plainLanguageSummary;
}

class CitizenProfile {
  final String name;
  final int age;
  final String gender;
  final double annualIncome;
  final String state;
  final String? district;
  final bool isBPL;
  final bool isSCST;
  final String? occupation;
  final bool isSeniorCitizen;
  final bool isStudent;
  final bool isFarmer;
  final bool isDisabled;
  final bool isWoman;
  final bool isWidow;
  final bool isMinority;

  const CitizenProfile({
    this.name = '',
    this.age = 0,
    this.gender = 'Male',
    this.annualIncome = 0,
    this.state = '',
    this.district,
    this.isBPL = false,
    this.isSCST = false,
    this.occupation,
    this.isSeniorCitizen = false,
    this.isStudent = false,
    this.isFarmer = false,
    this.isDisabled = false,
    this.isWoman = false,
    this.isWidow = false,
    this.isMinority = false,
  });

  CitizenProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? annualIncome,
    String? state,
    String? district,
    bool? isBPL,
    bool? isSCST,
    String? occupation,
    bool? isSeniorCitizen,
    bool? isStudent,
    bool? isFarmer,
    bool? isDisabled,
    bool? isWoman,
    bool? isWidow,
    bool? isMinority,
  }) {
    return CitizenProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      annualIncome: annualIncome ?? this.annualIncome,
      state: state ?? this.state,
      district: district ?? this.district,
      isBPL: isBPL ?? this.isBPL,
      isSCST: isSCST ?? this.isSCST,
      occupation: occupation ?? this.occupation,
      isSeniorCitizen: isSeniorCitizen ?? this.isSeniorCitizen,
      isStudent: isStudent ?? this.isStudent,
      isFarmer: isFarmer ?? this.isFarmer,
      isDisabled: isDisabled ?? this.isDisabled,
      isWoman: isWoman ?? this.isWoman,
      isWidow: isWidow ?? this.isWidow,
      isMinority: isMinority ?? this.isMinority,
    );
  }

  bool get hasProfile => name.isNotEmpty && age > 0 && state.isNotEmpty;
}
