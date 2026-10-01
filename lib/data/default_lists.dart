import '../models/packing_item.dart';
import '../models/packing_list.dart';

class DefaultLists {
  static const version = 2;

  static List<PackingList> build() {
    return [
      _list(
        id: 'preset-playa',
        name: 'Playa',
        iconKey: 'beach',
        items: const [
          'Traje de baño',
          'Toalla de playa',
          'Bloqueador solar factor 50',
          'Lentes de sol con filtro UV',
          'Quitasol',
          'Chalas',
          'Jockey pal sol',
          'Cooler con hielo',
          'Botella de agua',
          'Muda de ropa de cambio',
          'Crema para después del sol',
          'Sillas de playa',
          'Funda impermeable para el celular',
          'Bolsas para la ropa mojada',
          'Bolsas de basura',
        ],
      ),
      _list(
        id: 'preset-camping',
        name: 'Camping',
        iconKey: 'camping',
        items: const [
          'Carpa completa',
          'Saco de dormir',
          'Colchoneta',
          'Cocinilla a gas',
          'Balones de gas de repuesto',
          'Encendedor',
          'Set de ollas y cubiertos de camping',
          'Linterna',
          'Pilas de repuesto',
          'Botiquín de primeros auxilios',
          'Lámpara para colgar en la carpa',
          'Cortapluma',
          'Bidón de agua potable',
          'Confort',
          'Toallitas húmedas',
          'Bolsas de basura gruesas',
          'Cuerda',
          'Repelente para los zancudos',
        ],
      ),
      _list(
        id: 'preset-bosque',
        name: 'Bosque',
        iconKey: 'forest',
        items: const [
          'Zapatos de trekking',
          'Cortaviento',
          'Polar abrigado',
          'Pantalón de trekking',
          'Mochila cómoda',
          'Repelente para bichos',
          'Botella con agua',
          'Bloqueador solar',
          'Lentes con filtro UV',
          'Pito de emergencia',
          'Batería portátil',
          'Mapa de la ruta',
          'Botiquín',
          'Manta térmica de emergencia',
          'Bolsas para la basura',
        ],
      ),
    ];
  }

  static PackingList _list({
    required String id,
    required String name,
    required String iconKey,
    required List<String> items,
  }) {
    return PackingList(
      id: id,
      name: name,
      iconKey: iconKey,
      isPreset: true,
      items: [
        for (var i = 0; i < items.length; i++)
          PackingItem(id: '$id-$i', name: items[i]),
      ],
    );
  }
}
