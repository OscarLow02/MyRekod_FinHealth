class LhdnConstants {
  
  // ==========================================
  // 1. THE "IMPORT ALL" LISTS
  // ==========================================

  /// LHDN State Codes [6]
  static const Map<String, String> stateCodes = {
    '01': 'Johor',
    '02': 'Kedah',
    '03': 'Kelantan',
    '04': 'Melaka',
    '05': 'Negeri Sembilan',
    '06': 'Pahang',
    '07': 'Pulau Pinang',
    '08': 'Perak',
    '09': 'Perlis',
    '10': 'Selangor',
    '11': 'Terengganu',
    '12': 'Sabah',
    '13': 'Sarawak',
    '14': 'Wilayah Persekutuan Kuala Lumpur',
    '15': 'Wilayah Persekutuan Labuan',
    '16': 'Wilayah Persekutuan Putrajaya',
    '17': 'Not Applicable',
  };

  /// Reverse lookup to get the 2-digit code from the state name selected in UI.
  static String getStateCode(String stateName) {
    final search = stateName.toLowerCase().trim();
    for (var entry in stateCodes.entries) {
      if (entry.value.toLowerCase() == search) {
        return entry.key;
      }
    }
    return '17'; // Fallback to Not Applicable
  }

  /// Maps legacy 3-letter codes (used in early onboarding) to official LHDN 2-digit codes.
  static String mapLegacyCode(String code) {
    final legacyMap = {
      'JHR': '01', 'KDH': '02', 'KTN': '03', 'MLK': '04',
      'NSN': '05', 'PHG': '06', 'PNG': '07', 'PRK': '08',
      'PLS': '09', 'SGR': '10', 'TRG': '11', 'SBH': '12',
      'SWK': '13', 'KUL': '14', 'LBN': '15', 'PJY': '16',
    };
    return legacyMap[code.toUpperCase()] ?? code;
  }

  /// LHDN Payment Modes [7]
  static const Map<String, String> paymentModes = {
    '01': 'Cash',
    '02': 'Cheque',
    '03': 'Bank Transfer',
    '04': 'Credit Card',
    '05': 'Debit Card',
    '06': 'e-Wallet / Digital Wallet',
    '07': 'Digital Bank',
    '08': 'Others',
  };

  /// LHDN Tax Types [8]
  /// PM Note: Default to '06' in the UI for your non-SST registered hawkers.
  static const Map<String, String> taxTypes = {
    '01': 'Sales Tax',
    '02': 'Service Tax',
    '03': 'Tourism Tax',
    '04': 'High-Value Goods Tax',
    '05': 'Sales Tax on Low Value Goods',
    '06': 'Not Applicable',
    'E': 'Tax exemption (where applicable)',
  };

  // ==========================================
  // 2. THE "CURATE & FILTER" LISTS
  // ==========================================

  /// LHDN Unit of Measurement (Curated Top 5) [3, 9, 19-115]
  /// PM Note: Default to 'C62' in the UI.
  static const Map<String, String> unitOfMeasurement = {
    'C62': 'Piece / Unit / Each', // Default
    'KGM': 'Kilogram',
    'GRM': 'Gram',
    'LTR': 'Litre',
    'HUR': 'Hour', // For freelance/gig services
  };

  /// LHDN Classification Codes (Curated) [3, 10-12, 116, 117]
  /// PM Note: Default to '022' for standard daily sales.
  static const Map<String, String> classificationCodes = {
    '022': 'Others (Standard Sales)', // Default
    '004': 'Consolidated e-Invoice',
    '008': 'e-Commerce - e-Invoice to buyer / purchaser',
    '009': 'e-Commerce - Self-billed e-Invoice to seller, logistics, etc.',
    '036': 'Self-billed - Others', 
  };

  /// LHDN MSIC Codes (Curated Top 10 for Micro-SMEs) [3, 13-18, 118-356]
  /// PM Note: Keeps the UI clean. '00000' is the official LHDN fallback.
  static const Map<String, String> msicCodes = {
    '00000': 'NOT APPLICABLE', // Default/Fallback [13]
    '47111': 'Retail sale in non-specialised stores (General Retail)',
    '56101': 'Restaurants',
    '56107': 'Food/Beverage in market stalls/hawkers (Pasar Malam)',
    '56106': 'Food stalls/hawkers',
    '47810': 'Retail sale of food/beverages via stalls or markets',
    '47820': 'Retail sale of textiles/clothing via stalls or markets',
    '49224': 'E-hailing / Taxi operation (Grab, AirAsia Ride)',
    '49230': 'Freight transport by road (Lalamove, Delivery Runners)',
    '47912': 'Retail sale over the Internet (E-commerce)',
    '62010': 'Computer programming (IT Services)',
    '96020': 'Hairdressing and beauty treatment (Barbers/Salons)',
    '95292': 'Repair and alteration of clothing (Tailors)',
    '74200': 'Photographic activities (Freelance Photographers)',
    '96091': 'Other personal service activities n.e.c.',
  };
}
