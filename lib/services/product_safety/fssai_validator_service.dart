import '../../models/product_safety_model.dart';

/// 14-Digit FSSAI License & Registration Validator.
/// Decodes the official 14-digit Indian Food Safety structure:
/// - Digit 1: License Type (1 = License, 2 = Registration)
/// - Digits 2-3: State Jurisdiction Code (01-37)
/// - Digits 4-5: Year of Enrollment (e.g. 23 = 2023)
/// - Digits 6-8: Quantity / Enrolling Authority
/// - Digits 9-14: Manufacturer Serial Number
class FssaiValidatorService {
  static const Map<String, String> _stateMap = {
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
    '26': 'Dadra & Nagar Haveli and Daman & Diu',
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
    '00': 'Central Licensing Authority (HQ)',
  };

  /// Extracts and validates any FSSAI license in text.
  FssaiVerification? validateFromText(String text) {
    final clean = text.toUpperCase();

    // Look for explicit FSSAI identifiers or 14-digit sequences near FSSAI/Lic
    final fssaiPatterns = [
      RegExp(r'FSSAI[:\s\.\-A-Z]*(\d{14})'),
      RegExp(r'LIC(?:ENSE)?\.?\s*(?:NO\.?|NUMBER)?[:\s\.\-]*(\d{14})'),
      RegExp(r'\b(1\d{13}|2\d{13})\b'),
    ];

    for (final pattern in fssaiPatterns) {
      final match = pattern.firstMatch(clean);
      if (match != null) {
        final number = match.group(1);
        if (number != null && number.length == 14) {
          return validateNumber(number);
        }
      }
    }

    return null;
  }

  /// Validates a specific 14-digit string.
  FssaiVerification validateNumber(String fssaiNumber) {
    final cleaned = fssaiNumber.replaceAll(RegExp(r'[^\d]'), '').trim();

    if (cleaned.length != 14) {
      return FssaiVerification(
        rawLicenseNumber: fssaiNumber,
        isValid: false,
        licenseType: FssaiLicenseType.invalid,
        statusMessage: 'Invalid length: FSSAI License must be exactly 14 digits.',
      );
    }

    final digit1 = cleaned.substring(0, 1);
    final stateCode = cleaned.substring(1, 3);
    final yearCode = cleaned.substring(3, 5);
    final authorityCode = cleaned.substring(5, 8);
    final serialNo = cleaned.substring(8, 14);

    FssaiLicenseType type;
    if (digit1 == '1') {
      type = (stateCode == '00')
          ? FssaiLicenseType.centralLicense
          : FssaiLicenseType.stateLicense;
    } else if (digit1 == '2') {
      type = FssaiLicenseType.basicRegistration;
    } else {
      return FssaiVerification(
        rawLicenseNumber: cleaned,
        isValid: false,
        licenseType: FssaiLicenseType.invalid,
        statusMessage: 'Invalid first digit: Must start with 1 (License) or 2 (Registration).',
      );
    }

    final stateName = _stateMap[stateCode];
    if (stateName == null) {
      return FssaiVerification(
        rawLicenseNumber: cleaned,
        isValid: false,
        licenseType: FssaiLicenseType.invalid,
        statusMessage: 'Invalid state jurisdiction code: "$stateCode" does not map to any Indian state/UT.',
      );
    }

    final yearInt = int.tryParse(yearCode) ?? 0;
    final yearDisplay = yearInt < 50 ? '20$yearCode' : '19$yearCode';

    return FssaiVerification(
      rawLicenseNumber: cleaned,
      isValid: true,
      licenseType: type,
      stateCode: stateCode,
      stateName: stateName,
      registrationYear: yearDisplay,
      enrollingAuthority: authorityCode,
      manufacturerSerialNumber: serialNo,
      statusMessage: 'Valid ${type.displayName} registered in $stateName (Enrolled: $yearDisplay).',
    );
  }
}
