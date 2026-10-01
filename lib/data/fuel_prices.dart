class FuelOption {
  const FuelOption(this.name, this.pricePerLiter);

  final String name;
  final double pricePerLiter;
}

const fuelOptions = [
  FuelOption('Bencina 93 Octanos', 1500),
  FuelOption('Bencina 95 Octanos', 1600),
  FuelOption('Bencina 97 Octanos', 1700),
  FuelOption('Diésel', 1400),
];

const defaultFuelType = 'Bencina 95 Octanos';

double priceForFuel(String name) {
  for (final option in fuelOptions) {
    if (option.name == name) return option.pricePerLiter;
  }
  return fuelOptions[1].pricePerLiter;
}
