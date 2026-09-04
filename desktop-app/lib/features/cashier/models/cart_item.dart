class CartItem {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final double unitPrice;
  final double costPrice;
  final double taxRate;
  double quantity;
  double discountPercent;

  CartItem({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    required this.unitPrice,
    this.costPrice = 0.0,
    this.taxRate = 16.0,
    this.quantity = 1.0,
    this.discountPercent = 0.0,
  });

  double get grossTotal => unitPrice * quantity;
  double get discountAmount => grossTotal * (discountPercent / 100.0);
  double get netTotal => grossTotal - discountAmount;
  double get taxAmount => netTotal * (taxRate / (100.0 + taxRate)); // VAT included

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'taxRate': taxRate,
      'quantity': quantity,
      'discountPercent': discountPercent,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      barcode: map['barcode']?.toString() ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['taxRate'] as num?)?.toDouble() ?? 16.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
