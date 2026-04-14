import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for the global tax configuration stored per user.
/// Stored at: `business_profiles/{uid}/settings/tax_config`
class TaxConfig {
  final String defaultTaxType; // LHDN tax type code, e.g., '06' = Not Applicable
  final double? taxRate;
  final String? taxExemptionDetails;

  const TaxConfig({
    this.defaultTaxType = '06',
    this.taxRate,
    this.taxExemptionDetails,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'defaultTaxType': defaultTaxType,
      'taxRate': taxRate,
      'taxExemptionDetails': taxExemptionDetails ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TaxConfig.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TaxConfig(
      defaultTaxType: data['defaultTaxType'] as String? ?? '06',
      taxRate: (data['taxRate'] as num?)?.toDouble(),
      taxExemptionDetails: data['taxExemptionDetails'] as String?,
    );
  }

  /// Default tax config (Not Applicable, no rate).
  static const TaxConfig empty = TaxConfig();
}
