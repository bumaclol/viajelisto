class PackingItem {
  PackingItem({
    required this.id,
    required this.name,
    this.packed = false,
    this.quantity = 1,
  });

  final String id;
  String name;
  bool packed;
  int quantity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'packed': packed,
        'quantity': quantity,
      };

  factory PackingItem.fromJson(Map<String, dynamic> json) {
    final rawQuantity = (json['quantity'] as num?)?.toInt() ?? 1;
    return PackingItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      packed: json['packed'] as bool? ?? false,
      quantity: rawQuantity < 1 ? 1 : rawQuantity,
    );
  }
}
