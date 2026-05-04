import 'package:intl/intl.dart';
import '../models/business_profile.dart';
import '../models/sale_record.dart';
import '../models/customer.dart';
import '../core/lhdn_constants.dart';

/// Builds a complete LHDN UBL 2.1 compliant JSON payload
/// for e-Invoice submission.
///
/// Reference: LHDN e-Invoice SDK v1.0
/// Total fields covered: ~55 (Document, Supplier, Buyer, Line, Tax, Monetary)
///
/// Architecture: The app stores clean Dart models internally and
/// translates to LHDN's nested `_` format ONLY at serialization time.
class LhdnPayloadBuilder {
  /// The UBL 2.1 e-Invoice type code for a standard invoice.
  static const String _invoiceTypeCode = '01';

  /// The currency code for Malaysian Ringgit.
  static const String _currencyCode = 'MYR';

  // ══════════════════════════════════════════════════════════════════════════
  //  PUBLIC: Build Complete Payload
  // ══════════════════════════════════════════════════════════════════════════

  /// Builds the complete e-Invoice JSON payload from a [SaleRecord]
  /// and the seller's [BusinessProfile].
  ///
  /// This is the primary entry point. The returned map can be
  /// JSON-encoded and sent to the LHDN API (or mock service).
  static Map<String, dynamic> buildInvoicePayload({
    required SaleRecord record,
    required BusinessProfile sellerProfile,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');
    final saleDateStr = dateFormat.format(record.saleDate);
    final saleTimeStr = '${timeFormat.format(record.saleDate)}Z';

    return {
      // ── Document-Level Fields (Fields 1–20) ──────────────────────
      "_D": "urn:oasis:names:specification:ubl:schema:xsd:Invoice-2",
      "_A": "urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2",
      "_B": "urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2",
      "Invoice": [
        {
          // Field 1: e-Invoice Version
          "ID": [{"_": record.invoiceNumber}],
          // Field 2: Issue Date
          "IssueDate": [{"_": saleDateStr}],
          // Field 3: Issue Time
          "IssueTime": [{"_": saleTimeStr}],
          // Field 4: Invoice Type Code
          "InvoiceTypeCode": [
            {"_": _invoiceTypeCode, "listVersionID": "1.0"}
          ],
          // Field 5: Document Currency Code
          "DocumentCurrencyCode": [{"_": _currencyCode}],
          // Field 6: Invoice Period (frequency of billing)
          "InvoicePeriod": [
            {
              "StartDate": [{"_": saleDateStr}],
              "EndDate": [{"_": saleDateStr}],
              "Description": [{"_": "Monthly"}]
            }
          ],

          // ── Parties ──────────────────────────────────────────────────
          // Field 7–20 (Supplier)
          "AccountingSupplierParty": [buildSupplierParty(sellerProfile)],
          // Field 21–34 (Buyer)
          "AccountingCustomerParty": [_buildBuyerParty(record)],

          // ── Payment ──────────────────────────────────────────────────
          // Field 35: Payment Mode
          "PaymentMeans": [
            {
              "PaymentMeansCode": [{"_": record.paymentMode}],
              // Payment account (if available)
              if (sellerProfile.bankAccountNumber != null &&
                  sellerProfile.bankAccountNumber!.trim().isNotEmpty)
                "PayeeFinancialAccount": [
                  {
                    "ID": [{"_": sellerProfile.bankAccountNumber!.trim()}]
                  }
                ]
            }
          ],

          // ── Tax Total ────────────────────────────────────────────────
          // Fields 36–40
          "TaxTotal": [_buildTaxTotal(record)],

          // ── Legal Monetary Total ──────────────────────────────────────
          // Fields 41–47
          "LegalMonetaryTotal": [_buildMonetaryTotal(record)],

          // ── Invoice Lines ────────────────────────────────────────────
          // Fields 48–55
          "InvoiceLine": [_buildInvoiceLine(record)],
        }
      ]
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SUPPLIER PARTY (Fields 7–20)
  // ══════════════════════════════════════════════════════════════════════════

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

    return {
      "Party": {
        "IndustryClassificationCode": [
          {"_": profile.msicCode.trim(), "name": profile.businessActivityDescription.trim()}
        ],
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
          "CityName": [{"_": profile.city.trim()}],
          "PostalZone": [{"_": profile.postalCode.trim()}],
          "CountrySubentityCode": [{"_": LhdnConstants.getStateCode(profile.stateCode)}],
          "AddressLine": [
            {"Line": [{"_": profile.addressLine1.trim()}]},
            if (profile.addressLine2.trim().isNotEmpty)
              {"Line": [{"_": profile.addressLine2.trim()}]},
            if (profile.addressLine3.trim().isNotEmpty)
              {"Line": [{"_": profile.addressLine3.trim()}]},
          ],
          "Country": [
            {
              "IdentificationCode": [
                {"_": "MYS", "listID": "ISO3166-1", "listAgencyID": "6"}
              ]
            }
          ]
        },
        "PartyLegalEntity": [
          {"RegistrationName": [{"_": profile.businessName.trim()}]}
        ],
        "Contact": [
          {
            "Telephone": [{"_": rawPhone}],
            if (email.isNotEmpty)
              "ElectronicMail": [{"_": email}]
          }
        ]
      }
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PAYMENT MEANS (Legacy helper — kept for backward compatibility)
  // ══════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════════
  //  BUYER PARTY (Fields 21–34)
  // ══════════════════════════════════════════════════════════════════════════

  /// Builds the buyer party block from the embedded customer snapshot
  /// in the [SaleRecord].
  ///
  /// For B2C walk-in customers, uses LHDN generic buyer format:
  /// - TIN: EI00000000020
  /// - BRN: NA
  /// - Name: "General Public"
  static Map<String, dynamic> _buildBuyerParty(SaleRecord record) {
    // For B2C walk-in, use LHDN default generic buyer
    final bool isWalkIn = record.customerId == 'walk-in' ||
        record.customerType == CustomerType.b2c;

    final tin = isWalkIn ? 'EI00000000020' : record.customerTin;
    final idNumber = isWalkIn ? 'NA' : record.customerIdNumber;
    final idScheme = isWalkIn ? 'BRN' : record.customerIdScheme;
    final name = isWalkIn ? 'General Public' : record.customerName;

    return {
      "Party": {
        "PartyIdentification": [
          {
            "ID": {"schemeID": "TIN", "_": tin}
          },
          {
            "ID": {"schemeID": idScheme, "_": idNumber}
          },
        ],
        "PostalAddress": {
          "CityName": [{"_": isWalkIn ? "NA" : "NA"}],
          "PostalZone": [{"_": isWalkIn ? "00000" : "00000"}],
          "CountrySubentityCode": [{"_": "17"}],
          "AddressLine": [
            {"Line": [{"_": isWalkIn ? "NA" : "NA"}]},
          ],
          "Country": [
            {
              "IdentificationCode": [
                {"_": "MYS", "listID": "ISO3166-1", "listAgencyID": "6"}
              ]
            }
          ]
        },
        "PartyLegalEntity": [
          {"RegistrationName": [{"_": name}]}
        ],
        "Contact": [
          {
            "Telephone": [{"_": isWalkIn ? "NA" : "NA"}],
            "ElectronicMail": [{"_": isWalkIn ? "NA" : "NA"}]
          }
        ]
      }
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TAX TOTAL (Fields 36–40)
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _buildTaxTotal(SaleRecord record) {
    return {
      "TaxAmount": [
        {"_": _fmt(record.taxAmount), "currencyID": _currencyCode}
      ],
      "TaxSubtotal": [
        {
          "TaxableAmount": [
            {"_": _fmt(record.subtotal - record.discountAmount), "currencyID": _currencyCode}
          ],
          "TaxAmount": [
            {"_": _fmt(record.taxAmount), "currencyID": _currencyCode}
          ],
          "TaxCategory": [
            {
              "ID": [{"_": record.taxType}],
              "Percent": [{"_": record.taxRate}],
              "TaxScheme": [
                {
                  "ID": [
                    {"_": "OTH", "schemeID": "UN/ECE 5153", "schemeAgencyID": "6"}
                  ]
                }
              ]
            }
          ]
        }
      ]
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEGAL MONETARY TOTAL (Fields 41–47)
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _buildMonetaryTotal(SaleRecord record) {
    final netAmount = record.subtotal - record.discountAmount;
    final taxExclusiveAmount = netAmount;
    final taxInclusiveAmount = netAmount + record.taxAmount;

    return {
      // Sum of line amounts (before discount/tax)
      "LineExtensionAmount": [
        {"_": _fmt(record.subtotal), "currencyID": _currencyCode}
      ],
      // Total excluding tax
      "TaxExclusiveAmount": [
        {"_": _fmt(taxExclusiveAmount), "currencyID": _currencyCode}
      ],
      // Total including tax
      "TaxInclusiveAmount": [
        {"_": _fmt(taxInclusiveAmount), "currencyID": _currencyCode}
      ],
      // Allowance (discount) total
      "AllowanceTotalAmount": [
        {"_": _fmt(record.discountAmount), "currencyID": _currencyCode}
      ],
      // Payable rounding
      "PayableRoundingAmount": [
        {"_": _fmt(record.roundingAmount), "currencyID": _currencyCode}
      ],
      // Final payable
      "PayableAmount": [
        {"_": _fmt(record.totalPayable), "currencyID": _currencyCode}
      ],
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INVOICE LINE (Fields 48–55)
  // ══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _buildInvoiceLine(SaleRecord record) {
    final lineExtension = record.subtotal; // qty × unitPrice

    final line = <String, dynamic>{
      "ID": [{"_": "1"}],
      "InvoicedQuantity": [
        {"_": record.quantity, "unitCode": record.measurementUnit}
      ],
      "LineExtensionAmount": [
        {"_": _fmt(lineExtension), "currencyID": _currencyCode}
      ],
      // Discount (Allowance/Charge)
      if (record.discountAmount > 0)
        "AllowanceCharge": [
          {
            "ChargeIndicator": [{"_": false}],
            "MultiplierFactorNumeric": [{"_": 0}],
            "Amount": [
              {"_": _fmt(record.discountAmount), "currencyID": _currencyCode}
            ],
            "AllowanceChargeReason": [
              {"_": record.discountDescription.isNotEmpty ? record.discountDescription : "Discount"}
            ],
          }
        ],
      "TaxTotal": [
        {
          "TaxAmount": [
            {"_": _fmt(record.taxAmount), "currencyID": _currencyCode}
          ],
          "TaxSubtotal": [
            {
              "TaxableAmount": [
                {"_": _fmt(lineExtension - record.discountAmount), "currencyID": _currencyCode}
              ],
              "TaxAmount": [
                {"_": _fmt(record.taxAmount), "currencyID": _currencyCode}
              ],
              "Percent": [{"_": record.taxRate}],
              "TaxCategory": [
                {
                  "ID": [{"_": record.taxType}],
                  "TaxScheme": [
                    {
                      "ID": [
                        {"_": "OTH", "schemeID": "UN/ECE 5153", "schemeAgencyID": "6"}
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ],
      "Item": [
        {
          "CommodityClassification": [
            {
              "ItemClassificationCode": [
                {
                  "_": record.classificationCode,
                  "listID": "CLASS"
                }
              ]
            }
          ],
          "Description": [{"_": record.itemName}],
        }
      ],
      "Price": [
        {
          "PriceAmount": [
            {"_": _fmt(record.unitPrice), "currencyID": _currencyCode}
          ]
        }
      ],
      "ItemPriceExtension": [
        {
          "Amount": [
            {"_": _fmt(lineExtension), "currencyID": _currencyCode}
          ]
        }
      ],
    };

    return line;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITY
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a double to 2 decimal places as a string for JSON output.
  static String _fmt(double value) => value.toStringAsFixed(2);
}
