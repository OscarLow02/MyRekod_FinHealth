import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/lhdn_constants.dart';

/// Flattened DTO model for the Firestore `business_profiles` collection.
/// Follows the strict schema requirement from the Sprint Brief,
/// plus `entityType` added from the Figma mockup and all LHDN required/optional fields.
class BusinessProfile {
  final String userId;
  final String entityType; // e.g., 'Person' or 'Business'
  final String businessName; // Maps to RegistrationName
  final String tinNumber;
  final String brnNumber; // Holds SSM number for 'Business', MyKad for 'Person'
  
  // Tax & Industry Classifications
  final String sstNumber; // Default to "NA" if not applicable
  final String tourismTaxNumber; // Default to "NA" if not applicable
  final String msicCode;
  final String businessActivityDescription; // Required by LHDN
  
  // Contact Info
  final String phoneNumber;
  final String email;
  final String? imageUrl;
  
  // Address Info
  final String addressLine1;
  final String addressLine2;
  final String addressLine3; // Added to match JSON AddressLine array
  final String city;
  final String stateCode; // Maps to CountrySubentityCode (e.g., "10")
  final String postalCode; // Maps to PostalZone
  
  // Payment Info (Optional but useful for e-Invoice PaymentMeans)
  final String? bankAccountNumber;

  const BusinessProfile({
    required this.userId,
    required this.entityType,
    required this.businessName,
    required this.tinNumber,
    required this.brnNumber,
    this.sstNumber = "NA",
    this.tourismTaxNumber = "NA",
    required this.msicCode,
    required this.businessActivityDescription,
    required this.phoneNumber,
    required this.email,
    this.imageUrl,
    required this.addressLine1,
    this.addressLine2 = "",
    this.addressLine3 = "",
    required this.city,
    required this.stateCode,
    required this.postalCode,
    this.bankAccountNumber,
  });

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'entityType': entityType,
      'businessName': businessName,
      'tinNumber': tinNumber,
      'brnNumber': brnNumber,
      'sstNumber': sstNumber,
      'tourismTaxNumber': tourismTaxNumber,
      'msicCode': msicCode,
      'businessActivityDescription': businessActivityDescription,
      'phoneNumber': phoneNumber,
      'email': email,
      'imageUrl': imageUrl,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'addressLine3': addressLine3,
      'city': city,
      'stateCode': stateCode,
      'postalCode': postalCode,
      'bankAccountNumber': bankAccountNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Constructs a [BusinessProfile] from a Firestore document snapshot.
  factory BusinessProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BusinessProfile(
      userId: data['userId'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      tinNumber: data['tinNumber'] as String? ?? '',
      brnNumber: data['brnNumber'] as String? ?? '',
      sstNumber: data['sstNumber'] as String? ?? 'NA',
      tourismTaxNumber: data['tourismTaxNumber'] as String? ?? 'NA',
      msicCode: data['msicCode'] as String? ?? '',
      businessActivityDescription: data['businessActivityDescription'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      email: data['email'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      addressLine1: data['addressLine1'] as String? ?? '',
      addressLine2: data['addressLine2'] as String? ?? '',
      addressLine3: data['addressLine3'] as String? ?? '',
      city: data['city'] as String? ?? '',
      stateCode: LhdnConstants.mapLegacyCode(data['stateCode'] as String? ?? ''),
      postalCode: data['postalCode'] as String? ?? '',
      bankAccountNumber: data['bankAccountNumber'] as String?,
    );
  }
  BusinessProfile copyWith({
    String? userId,
    String? entityType,
    String? businessName,
    String? tinNumber,
    String? brnNumber,
    String? sstNumber,
    String? tourismTaxNumber,
    String? msicCode,
    String? businessActivityDescription,
    String? phoneNumber,
    String? email,
    String? imageUrl,
    String? addressLine1,
    String? addressLine2,
    String? addressLine3,
    String? city,
    String? stateCode,
    String? postalCode,
    String? bankAccountNumber,
  }) {
    return BusinessProfile(
      userId: userId ?? this.userId,
      entityType: entityType ?? this.entityType,
      businessName: businessName ?? this.businessName,
      tinNumber: tinNumber ?? this.tinNumber,
      brnNumber: brnNumber ?? this.brnNumber,
      sstNumber: sstNumber ?? this.sstNumber,
      tourismTaxNumber: tourismTaxNumber ?? this.tourismTaxNumber,
      msicCode: msicCode ?? this.msicCode,
      businessActivityDescription: businessActivityDescription ?? this.businessActivityDescription,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      addressLine3: addressLine3 ?? this.addressLine3,
      city: city ?? this.city,
      stateCode: stateCode ?? this.stateCode,
      postalCode: postalCode ?? this.postalCode,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }
}
