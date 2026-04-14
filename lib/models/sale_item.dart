import 'package:cloud_firestore/cloud_firestore.dart';

/// DTO model for a Sale Item in the Item Catalog.
/// Firebase persistence via the `sale_items` subcollection under each user's
/// business profile document: `business_profiles/{uid}/sale_items/{itemId}`.
class SaleItem {
  final String id;
  final String name;
  final double unitPrice;
  final String measurementUnit; // e.g., 'C62' (Unit/Piece)
  final String classificationCode; // LHDN classification, e.g., '022'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SaleItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.measurementUnit = 'C62',
    this.classificationCode = '022',
    this.createdAt,
    this.updatedAt,
  });

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'unitPrice': unitPrice,
      'measurementUnit': measurementUnit,
      'classificationCode': classificationCode,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Constructs a [SaleItem] from a Firestore document snapshot.
  factory SaleItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SaleItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      measurementUnit: data['measurementUnit'] as String? ?? 'C62',
      classificationCode: data['classificationCode'] as String? ?? '022',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Returns a copy of this item with optionally updated fields.
  SaleItem copyWith({
    String? id,
    String? name,
    double? unitPrice,
    String? measurementUnit,
    String? classificationCode,
  }) {
    return SaleItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      classificationCode: classificationCode ?? this.classificationCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
