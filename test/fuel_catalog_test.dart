import 'package:flutter_test/flutter_test.dart';
import 'package:viajelisto/logic/cheapest_fuel.dart';
import 'package:viajelisto/models/fuel_station.dart';
import 'package:viajelisto/services/cne_fuel_api.dart';

void main() {
  test('lee el precio real que manda Bencina en Línea', () {
    const stations = '''
{"data":[{"id":29,"marca":5,"direccion":"VIVAR 402","region":"Tarapacá","comuna":"Iquique","combustibles":[
{"nombre_corto":"93","precio":"1645.000","precio_fecha":"2026-11-05 16:22:37","tipo_atencion_nombre":"AutoServicio"},
{"nombre_corto":"A93","precio":"1637.000","precio_fecha":"2026-11-05 16:22:37","tipo_atencion_nombre":"Asistido"}
]}]}
''';
    const brands = '[{"id":5,"nombre":"COPEC"}]';
    final catalog = parseCneCatalog(stations, brands, DateTime.utc(2026, 11, 11, 5));
    final quote = catalog.stations.single.quoteFor(ChileFuel.byLabel('Bencina 93 Octanos'));

    expect(catalog.stations.single.brand, 'COPEC');
    expect(catalog.stations.single.address, 'VIVAR 402');
    expect(quote?.pesosPerLiter, 1637);
    expect(quote?.service, 'Asistido');
  });

  test('un precio imposible no se marca como el más económico', () {
    expect(priceCountsAsCheapest(100000, [1500, 1520, 1490, 100000]), isFalse);
    expect(priceCountsAsCheapest(1490, [1500, 1520, 1490, 100000]), isTrue);
  });
}
