import '../models/business_profile.dart';
import '../core/lhdn_constants.dart';

class LhdnPayloadBuilder {
  /// Builds the 'AccountingSupplierParty' object according to strict LHDN UBL 2.1 specs.
  static Map<String, dynamic> buildSupplierParty(BusinessProfile profile) {
    // Determine dynamically the scheme ID for BRN
    String brnScheme = 'BRN'; // Default for business
    if (profile.entityType == 'Person') {
      final numericOnly = profile.brnNumber.replaceAll('-', '').trim();
      if (numericOnly.length == 12 && int.tryParse(numericOnly) != null) {
        brnScheme = 'NRIC';
      } else {
        brnScheme = 'PASSPORT';
      }
    }

    // Phone sanitization (+60 prefix enforce if starting with 0)
    String rawPhone = profile.phoneNumber.replaceAll(RegExp(r'\s|-'), '');
    if (rawPhone.startsWith('0')) {
      rawPhone = '+60${rawPhone.substring(1)}';
    } else if (!rawPhone.startsWith('+60') && rawPhone.startsWith('60')) {
      rawPhone = '+$rawPhone';
    }

    final email = profile.email.trim();
    final bankAccount = profile.bankAccountNumber?.trim() ?? '';

    return {
      "Party": {
        "PartyIdentification": [
          {
            "ID": {
              "schemeID": "TIN",
              "_": profile.tinNumber.trim()
            }
          },
          {
            "ID": {
              "schemeID": brnScheme,
              "_": profile.brnNumber.trim()
            }
          },
          {
            "ID": {
              "schemeID": "SST",
              "_": (profile.sstNumber.trim().isNotEmpty && profile.sstNumber.trim() != 'NA') ? profile.sstNumber.trim() : "NA"
            }
          },
          {
            "ID": {
              "schemeID": "TTX",
              "_": (profile.tourismTaxNumber.trim().isNotEmpty && profile.tourismTaxNumber.trim() != 'NA') ? profile.tourismTaxNumber.trim() : "NA"
            }
          }
        ],
        "PostalAddress": {
          "CityName": { "_": profile.city.trim() },
          "PostalZone": { "_": profile.postalCode.trim() },
          "CountrySubentityCode": { "_": LhdnConstants.getStateCode(profile.stateCode) },
          "AddressLine": [
            { "Line": { "_": profile.addressLine1.trim() } },
            if (profile.addressLine2.trim().isNotEmpty)
              { "Line": { "_": profile.addressLine2.trim() } },
            if (profile.addressLine3.trim().isNotEmpty)
              { "Line": { "_": profile.addressLine3.trim() } },
          ],
          "Country": {
            "IdentificationCode": {
              "listID": "ISO3166-1",
              "listAgencyID": "6",
              "_": "MYS"
            }
          }
        },
        "PartyLegalEntity": {
          "RegistrationName": { "_": profile.businessName.trim() }
        },
        "Contact": {
          "Telephone": [{"_": rawPhone}],
          if (email.isNotEmpty)
            "ElectronicMail": [{"_": email}]
        }
      }
    };
  }

  /// Builds the 'PaymentMeans' array conditionally
  static List<Map<String, dynamic>>? buildPaymentMeans(BusinessProfile profile) {
    if (profile.bankAccountNumber == null || profile.bankAccountNumber!.trim().isEmpty) {
      return null; // Must be omitted completely
    }
    
    return [
      {
        "PayeeFinancialAccount": {
          "ID": { "_": profile.bankAccountNumber!.trim() }
        }
      }
    ];
  }
}
