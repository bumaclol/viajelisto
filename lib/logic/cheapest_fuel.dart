bool priceCountsAsCheapest(int price, List<int> prices) {
  if (price <= 0) return false;
  final usable = [for (final value in prices) if (value > 0) value]..sort();
  if (usable.length < 3) return true;
  final median = usable[usable.length ~/ 2];
  if (median <= 0) return false;
  return price >= median * 0.4 && price <= median * 2.5;
}
