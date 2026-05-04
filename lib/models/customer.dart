import 'package:cloud_firestore/cloud_firestore.dart';

/// Customer entity type for LHDN e-Invoice routing.
/// B2B = Business-to-Business (requires full buyer details).
/// B2C = Business-to-Consumer (walk-in, uses generic buyer block).
enum CustomerType { b2b, b2c }

/// DTO model for the Firestore `customers` subcollection.
///
/// Firestore path: `business_profiles/{uid}/customers/{customerId}`
///
/// Per LHDN UBL 2.1 spec, the buyer party requires:
/// - TIN (mandatory for B2B, generic "EI00000000020" for B2C walk-ins)
/// - BRN / MyKad / Passport (mandatory for B2B)
/// - Name, Address, Contact (mandatory for B2B, generic for B2C)
class Customer {
  final String id;
  final String name;
  final CustomerType customerType;

  // LHDN Identification
  final String tinNumber;
  final String idNumber; // BRN for business, MyKad/Passport for person
  final String idScheme; // 'BRN', 'NRIC', 'PASSPORT', 'ARMY'

  // Contact
  final String phoneNumber;
  final String email;

  // Address (required for B2B, optional for B2C)
  final String addressLine1;
  final String addressLine2;
  final String addressLine3;
  final String city;
  final String stateCode; // LHDN 2-digit code
  final String postalCode;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.customerType,
    this.tinNumber = '',
    this.idNumber = '',
    this.idScheme = 'BRN',
    this.phoneNumber = '',
    this.email = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.addressLine3 = '',
    this.city = '',
    this.stateCode = '17', // Default: Not Applicable
    this.postalCode = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Walk-in B2C customer singleton per LHDN guidelines.
  /// Uses generic TIN "EI00000000020" and "NA" identification.
  static const Customer walkIn = Customer(
    id: 'walk-in',
    name: 'Walk-in Customer',
    customerType: CustomerType.b2c,
    tinNumber: 'EI00000000020',
    idNumber: 'NA',
    idScheme: 'BRN',
    phoneNumber: 'NA',
    email: 'NA',
    addressLine1: 'NA',
    city: 'NA',
    stateCode: '17',
    postalCode: '00000',
  );

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'customerType': customerType.name, // 'b2b' or 'b2c'
      'tinNumber': tinNumber,
      'idNumber': idNumber,
      'idScheme': idScheme,
      'phoneNumber': phoneNumber,
      'email': email,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'addressLine3': addressLine3,
      'city': city,
      'stateCode': stateCode,
      'postalCode': postalCode,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Constructs a [Customer] from a Firestore document snapshot.
  factory Customer.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Customer(
      id: doc.id,
      name: data['name'] as String? ?? '',
      customerType: _parseCustomerType(data['customerType'] as String?),
      tinNumber: data['tinNumber'] as String? ?? '',
      idNumber: data['idNumber'] as String? ?? '',
      idScheme: data['idScheme'] as String? ?? 'BRN',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      email: data['email'] as String? ?? '',
      addressLine1: data['addressLine1'] as String? ?? '',
      addressLine2: data['addressLine2'] as String? ?? '',
      addressLine3: data['addressLine3'] as String? ?? '',
      city: data['city'] as String? ?? '',
      stateCode: data['stateCode'] as String? ?? '17',
      postalCode: data['postalCode'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static CustomerType _parseCustomerType(String? value) {
    if (value == 'b2b') return CustomerType.b2b;
    return CustomerType.b2c;
  }

  /// Returns a copy with optionally updated fields.
  Customer copyWith({
    String? id,
    String? name,
    CustomerType? customerType,
    String? tinNumber,
    String? idNumber,
    String? idScheme,
    String? phoneNumber,
    String? email,
    String? addressLine1,
    String? addressLine2,
    String? addressLine3,
    String? city,
    String? stateCode,
    String? postalCode,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      customerType: customerType ?? this.customerType,
      tinNumber: tinNumber ?? this.tinNumber,
      idNumber: idNumber ?? this.idNumber,
      idScheme: idScheme ?? this.idScheme,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      addressLine3: addressLine3 ?? this.addressLine3,
      city: city ?? this.city,
      stateCode: stateCode ?? this.stateCode,
      postalCode: postalCode ?? this.postalCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Whether this is the generic walk-in customer.
  bool get isWalkIn => id == 'walk-in';
}
