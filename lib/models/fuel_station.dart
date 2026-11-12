class ChileFuel {
  const ChileFuel(this.label, this.codes);

  final String label;
  final List<String> codes;

  static const options = [
    ChileFuel('Bencina 93 Octanos', ['93', 'A93']),
    ChileFuel('Bencina 95 Octanos', ['95', 'A95']),
    ChileFuel('Bencina 97 Octanos', ['97', 'A97']),
    ChileFuel('Diésel', ['DI', 'ADI']),
  ];

  static ChileFuel byLabel(String label) {
    for (final fuel in options) {
      if (fuel.label == label) return fuel;
    }
    return options[1];
  }
}

class FuelPricePoint {
  const FuelPricePoint({
    required this.code,
    required this.pesosPerLiter,
    required this.updatedAt,
    required this.service,
  });

  final String code;
  final int pesosPerLiter;
  final String updatedAt;
  final String service;

  Map<String, dynamic> toJson() => {
        'code': code,
        'price': pesosPerLiter,
        'at': updatedAt,
        'service': service,
      };

  factory FuelPricePoint.fromJson(Map<String, dynamic> json) {
    return FuelPricePoint(
      code: json['code'] as String? ?? '',
      pesosPerLiter: (json['price'] as num?)?.round() ?? 0,
      updatedAt: json['at'] as String? ?? '',
      service: json['service'] as String? ?? '',
    );
  }
}

class StationQuote {
  const StationQuote({
    required this.pesosPerLiter,
    required this.updatedAt,
    required this.service,
  });

  final int pesosPerLiter;
  final String updatedAt;
  final String service;
}

class FuelStation {
  const FuelStation({
    required this.id,
    required this.brand,
    required this.address,
    required this.region,
    required this.commune,
    required this.prices,
  });

  final int id;
  final String brand;
  final String address;
  final String region;
  final String commune;
  final List<FuelPricePoint> prices;

  String get title => brand.trim().isEmpty ? 'Estación de servicio' : brand.trim();

  StationQuote? quoteFor(ChileFuel fuel) {
    StationQuote? best;
    for (final price in prices) {
      if (!fuel.codes.contains(price.code) || price.pesosPerLiter <= 0) continue;
      if (best == null || price.pesosPerLiter < best.pesosPerLiter) {
        best = StationQuote(
          pesosPerLiter: price.pesosPerLiter,
          updatedAt: price.updatedAt,
          service: price.service,
        );
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'address': address,
        'region': region,
        'commune': commune,
        'prices': [for (final price in prices) price.toJson()],
      };

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    final raw = json['prices'];
    return FuelStation(
      id: (json['id'] as num?)?.round() ?? 0,
      brand: json['brand'] as String? ?? '',
      address: json['address'] as String? ?? '',
      region: json['region'] as String? ?? '',
      commune: json['commune'] as String? ?? '',
      prices: raw is List
          ? [
              for (final item in raw)
                if (item is Map) FuelPricePoint.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class FuelCatalog {
  const FuelCatalog({required this.fetchedAt, required this.stations});

  final DateTime fetchedAt;
  final List<FuelStation> stations;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'stations': [for (final station in stations) station.toJson()],
      };

  factory FuelCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['stations'];
    return FuelCatalog(
      fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      stations: raw is List
          ? [
              for (final item in raw)
                if (item is Map) FuelStation.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class SelectedFuelPrice {
  const SelectedFuelPrice({
    required this.fuelType,
    required this.pesosPerLiter,
    required this.stationName,
    required this.address,
  });

  final String fuelType;
  final int pesosPerLiter;
  final String stationName;
  final String address;
}
