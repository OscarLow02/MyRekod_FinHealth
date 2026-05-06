import 'sale_item.dart';

/// Represents a single line item in a sale transaction.
class SaleLineItem {
  final SaleItem item;
  double quantity;
  double? customPrice;

  SaleLineItem({
    required this.item,
    this.quantity = 1.0,
    this.customPrice,
  });

  /// The price used for calculation (custom override or catalog price).
  double get unitPrice => customPrice ?? item.unitPrice;

  /// The subtotal for this specific line (unitPrice * quantity).
  double get subtotal => unitPrice * quantity;

  /// Creates a copy with updated fields.
  SaleLineItem copyWith({
    SaleItem? item,
    double? quantity,
    double? customPrice,
  }) {
    return SaleLineItem(
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}
