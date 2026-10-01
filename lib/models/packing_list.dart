import 'packing_item.dart';

class PackingList {
  PackingList({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.isPreset,
    required this.items,
  });

  final String id;
  String name;
  final String iconKey;
  final bool isPreset;
  List<PackingItem> items;

  int get packedCount => items.where((item) => item.packed).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'isPreset': isPreset,
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory PackingList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PackingList(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Lista',
      iconKey: json['iconKey'] as String? ?? 'custom',
      isPreset: json['isPreset'] as bool? ?? false,
      items: rawItems
          .map((item) => PackingItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
