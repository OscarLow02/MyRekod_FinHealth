import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseRecord {
  final String id;
  final DateTime date;
  final double amount;
  final String vendor;
  final String category;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.vendor,
    required this.category,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'vendor': vendor,
      'category': category,
      'imagePath': imagePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExpenseRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return ExpenseRecord(
      id: documentId,
      date: (map['date'] as Timestamp).toDate(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      vendor: map['vendor'] ?? '',
      category: map['category'] ?? '',
      imagePath: map['imagePath'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  ExpenseRecord copyWith({
    String? id,
    DateTime? date,
    double? amount,
    String? vendor,
    String? category,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      vendor: vendor ?? this.vendor,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
