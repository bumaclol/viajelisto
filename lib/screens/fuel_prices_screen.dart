import 'package:flutter/material.dart';

import '../logic/cheapest_fuel.dart';
import '../models/fuel_station.dart';
import '../services/cne_fuel_api.dart';
import '../services/fuel_catalog_store.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

class FuelPricesScreen extends StatefulWidget {
  const FuelPricesScreen({super.key, this.initialCommune, this.api, this.store});

  final String? initialCommune;
  final CneFuelApi? api;
  final FuelCatalogStore? store;

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen> {
  late final CneFuelApi _api = widget.api ?? CneFuelApi();
  late final FuelCatalogStore _store = widget.store ?? FuelCatalogStore();

  FuelCatalog? _catalog;
  ChileFuel _fuel = ChileFuel.options[1];
  String? _region;
  String? _commune;
  var _loading = true;
  String? _error;
  var _showingCached = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cached = await _store.read();
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _catalog = cached;
        _showingCached = true;
        _applyHint();
      });
      if (!force && _store.isFresh(cached, DateTime.now())) {
        setState(() {
          _loading = false;
          _showingCached = false;
        });
        return;
      }
    }
    try {
      final fresh = await _api.fetch();
      await _store.write(fresh);
      if (!mounted) return;
      setState(() {
        _catalog = fresh;
        _loading = false;
        _showingCached = false;
        _error = null;
        _applyHint();
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is FuelCatalogException
          ? error.message
          : 'Los precios no pudieron actualizarse.';
      setState(() {
        _loading = false;
        _error = message;
        _showingCached = _catalog != null;
      });
    }
  }

  void _applyHint() {
    if (_region != null || _commune != null) return;
    final needle = widget.initialCommune?.trim().toLowerCase() ?? '';
    final stations = _catalog?.stations ?? const <FuelStation>[];
    if (needle.isEmpty || stations.isEmpty) return;
    final matches = [
      for (final station in stations)
        if (station.commune.toLowerCase() == needle) station,
    ];
    if (matches.isEmpty) return;
    final regions = {for (final station in matches) station.region};
    if (regions.length != 1) return;
    _region = regions.first;
    _commune = matches.first.commune;
  }

  List<String> get _regions {
    final names = {for (final station in _catalog?.stations ?? const <FuelStation>[]) station.region};
    final list = names.toList()..sort();
    return list;
  }

  List<String> get _communes {
    final names = {
      for (final station in _catalog?.stations ?? const <FuelStation>[])
        if (station.region == _region) station.commune,
    };
    final list = names.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final quotes = _quotes();
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: forestDeep),
                      ),
                      const Expanded(
                        child: Text(
                          'Precios de combustible',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: forestDeep,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar precios',
                        onPressed: _loading ? null : () => _load(force: true),
                        icon: const Icon(Icons.refresh_rounded, color: forestDeep),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _catalog == null && _loading
                      ? const _LoadingState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          children: [
                            const Text(
                              'Comisión Nacional de Energía, Bencina en Línea.',
                              style: TextStyle(color: moss, height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Text(_stamp(), style: const TextStyle(color: forestDeep, fontWeight: FontWeight.w700)),
                            if (_loading) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(color: forest, backgroundColor: line, minHeight: 4),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _Notice(text: _error!, cached: _showingCached),
                            ],
                            const SizedBox(height: 16),
                            _Menu(
                              label: 'Región',
                              value: _region,
                              items: _regions,
                              onChanged: (value) => setState(() {
                                _region = value;
                                _commune = null;
                              }),
                            ),
                            const SizedBox(height: 10),
                            _Menu(
                              label: 'Comuna',
                              value: _commune,
                              items: _communes,
                              onChanged: _region == null ? null : (value) => setState(() => _commune = value),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final fuel in ChileFuel.options)
                                  ChoiceChip(
                                    label: Text(fuel.label.replaceFirst(' Octanos', '')),
                                    selected: fuel.label == _fuel.label,
                                    selectedColor: forest,
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: fuel.label == _fuel.label ? Colors.white : forestDeep,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    side: const BorderSide(color: line),
                                    onSelected: (_) => setState(() => _fuel = fuel),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_region == null || _commune == null)
                              const Text(
                                'Elige una región y una comuna para ver las estaciones.',
                                style: TextStyle(color: moss, height: 1.35),
                              )
                            else if (quotes.isEmpty)
                              Text(
                                'No hay estaciones con ${_fuel.label} en $_commune.',
                                style: const TextStyle(color: moss, height: 1.35),
                              )
                            else
                              for (final quote in quotes) ...[
                                _StationCard(
                                  quote: quote,
                                  onUse: () => Navigator.of(context).pop(
                                    SelectedFuelPrice(
                                      fuelType: _fuel.label,
                                      pesosPerLiter: quote.pesosPerLiter,
                                      stationName: quote.station.title,
                                      address: quote.station.address,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _stamp() {
    final at = _catalog?.fetchedAt;
    if (at == null) return 'Todavía no hay una consulta guardada.';
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Última consulta: ${two(local.day)}-${two(local.month)}-${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  List<_ShownQuote> _quotes() {
    if (_region == null || _commune == null) return const [];
    final rows = <_ShownQuote>[];
    for (final station in _catalog?.stations ?? const <FuelStation>[]) {
      if (station.region != _region || station.commune != _commune) continue;
      final quote = station.quoteFor(_fuel);
      if (quote == null) continue;
      rows.add(_ShownQuote(station: station, pesosPerLiter: quote.pesosPerLiter, updatedAt: quote.updatedAt, service: quote.service));
    }
    final prices = [for (final row in rows) row.pesosPerLiter];
    final eligible = [
      for (final row in rows)
        if (priceCountsAsCheapest(row.pesosPerLiter, prices)) row.pesosPerLiter,
    ];
    final cheapest = eligible.isEmpty ? null : eligible.reduce((a, b) => a < b ? a : b);
    final shown = [
      for (final row in rows)
        _ShownQuote(
          station: row.station,
          pesosPerLiter: row.pesosPerLiter,
          updatedAt: row.updatedAt,
          service: row.service,
          cheapest: cheapest != null && row.pesosPerLiter == cheapest,
          aside: !priceCountsAsCheapest(row.pesosPerLiter, prices),
        ),
    ];
    shown.sort((a, b) {
      if (a.aside != b.aside) return a.aside ? 1 : -1;
      return a.pesosPerLiter.compareTo(b.pesosPerLiter);
    });
    return shown;
  }
}

class _ShownQuote {
  const _ShownQuote({
    required this.station,
    required this.pesosPerLiter,
    required this.updatedAt,
    required this.service,
    this.cheapest = false,
    this.aside = false,
  });

  final FuelStation station;
  final int pesosPerLiter;
  final String updatedAt;
  final String service;
  final bool cheapest;
  final bool aside;
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: forest),
            SizedBox(height: 14),
            Text(
              'Consultando los precios en Bencina en Línea...',
              textAlign: TextAlign.center,
              style: TextStyle(color: forestDeep, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.cached});

  final String text;
  final bool cached;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: forestDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cached ? '$text Se muestran los últimos precios guardados.' : text,
              style: const TextStyle(color: forestDeep, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value != null && items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        for (final item in items) DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.quote, required this.onUse});

  final _ShownQuote quote;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final address = quote.station.address.trim().isEmpty ? quote.station.commune : quote.station.address;
    final when = _shownDate(quote.updatedAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: quote.cheapest ? lime : line, width: quote.cheapest ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote.cheapest)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'La más económica',
                style: TextStyle(color: forestDeep, fontWeight: FontWeight.w800),
              ),
            ),
          Text(quote.station.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: forestDeep)),
          const SizedBox(height: 2),
          Text(address, style: const TextStyle(color: moss, height: 1.3)),
          const SizedBox(height: 10),
          Text(
            '${formatMoney(quote.pesosPerLiter)} / L',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: forestDeep, height: 1),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (quote.service.isNotEmpty) quote.service,
              if (when.isNotEmpty) 'Actualizado por la estación: $when',
            ].join(' · '),
            style: const TextStyle(color: moss, height: 1.3),
          ),
          if (quote.aside) ...[
            const SizedBox(height: 6),
            const Text(
              'Este precio se aleja del resto de la comuna, así que no se marca como el más económico.',
              style: TextStyle(color: forestDeep, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onUse,
              style: FilledButton.styleFrom(
                backgroundColor: forest,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Usar este precio', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

String _shownDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) return raw.trim();
  return '${match.group(3)}-${match.group(2)}-${match.group(1)} ${match.group(4)}:${match.group(5)}';
}
