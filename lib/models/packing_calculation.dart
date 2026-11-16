enum PackingFastener { nails, screws }

class PackingRates {
  final double woodPerLonjor;
  final double screwPerPiece;
  final double nailPerGram;
  final int nailsPerKg;
  final double laborPerPackage;
  final double electricityPerPackage;
  final double overheadPerPackage;
  final int fastenersPerPackage;
  final double marginPercent;

  const PackingRates({
    this.woodPerLonjor = 3500,
    this.screwPerPiece = 320,
    this.nailPerGram = 25,
    this.nailsPerKg = 430,
    this.laborPerPackage = 15000,
    this.electricityPerPackage = 1500,
    this.overheadPerPackage = 5000,
    this.fastenersPerPackage = 68,
    this.marginPercent = 25,
  });

  Map<String, dynamic> toJson() => {
    'woodPerLonjor': woodPerLonjor,
    'screwPerPiece': screwPerPiece,
    'nailPerGram': nailPerGram,
    'nailsPerKg': nailsPerKg,
    'laborPerPackage': laborPerPackage,
    'electricityPerPackage': electricityPerPackage,
    'overheadPerPackage': overheadPerPackage,
    'fastenersPerPackage': fastenersPerPackage,
    'marginPercent': marginPercent,
  };

  factory PackingRates.fromJson(Map<String, dynamic> json) => PackingRates(
    woodPerLonjor: (json['woodPerLonjor'] as num?)?.toDouble() ?? 3500,
    screwPerPiece: (json['screwPerPiece'] as num?)?.toDouble() ?? 320,
    nailPerGram: (json['nailPerGram'] as num?)?.toDouble() ?? 25,
    nailsPerKg: (json['nailsPerKg'] as num?)?.toInt() ?? 430,
    laborPerPackage: (json['laborPerPackage'] as num?)?.toDouble() ?? 15000,
    electricityPerPackage: (json['electricityPerPackage'] as num?)?.toDouble() ?? 1500,
    overheadPerPackage: (json['overheadPerPackage'] as num?)?.toDouble() ?? 5000,
    fastenersPerPackage: (json['fastenersPerPackage'] as num?)?.toInt() ?? 68,
    marginPercent: (json['marginPercent'] as num?)?.toDouble() ?? 25,
  );
}

class PackingCalculation {
  final double frameLengthCm;
  final int woodSticksPerPackage;
  final double woodCost;
  final double fastenerQuantity;
  final String fastenerUnit;
  final double fastenerCost;
  final double laborCost;
  final double electricityCost;
  final double overheadCost;
  final double boardCost;
  final double totalCost;
  final double suggestedPrice;
  final double roundedPrice;

  const PackingCalculation({
    required this.frameLengthCm,
    required this.woodSticksPerPackage,
    required this.woodCost,
    required this.fastenerQuantity,
    required this.fastenerUnit,
    required this.fastenerCost,
    required this.laborCost,
    required this.electricityCost,
    required this.overheadCost,
    required this.boardCost,
    required this.totalCost,
    required this.suggestedPrice,
    required this.roundedPrice,
  });

  factory PackingCalculation.calculate({
    required double lengthCm,
    required double widthCm,
    required double heightCm,
    int packageCount = 1,
    PackingFastener fastener = PackingFastener.nails,
    PackingRates rates = const PackingRates(),
    bool includeBoard = false,
    double boardCostPerPackage = 0,
  }) {
    if (![lengthCm, widthCm, heightCm, boardCostPerPackage].every(
      (value) => value.isFinite && value >= 0,
    ) || lengthCm <= 0 || widthCm <= 0 || heightCm <= 0 ||
        packageCount <= 0 || rates.nailsPerKg <= 0 ||
        rates.fastenersPerPackage < 0 ||
        rates.marginPercent < 0 || rates.marginPercent >= 100) {
      throw ArgumentError('Input kalkulasi packing tidak valid.');
    }

    // Four corner posts + top/bottom perimeters + mid-rails on all
    // four sides + one cross rail on the top and bottom.
    final frameLength = 4 * heightCm + 8 * (lengthCm + widthCm);
    final sticksPerPackage = (frameLength / 200).ceil();
    final woodCost = sticksPerPackage * rates.woodPerLonjor * packageCount;

    final fastenerCount = rates.fastenersPerPackage * packageCount;
    final fastenerQuantity = fastener == PackingFastener.nails
        ? fastenerCount * 1000 / rates.nailsPerKg
        : fastenerCount.toDouble();
    final fastenerCost = fastener == PackingFastener.nails
        ? fastenerQuantity * rates.nailPerGram
        : fastenerQuantity * rates.screwPerPiece;

    final labor = rates.laborPerPackage * packageCount;
    final electricity = rates.electricityPerPackage * packageCount;
    final overhead = rates.overheadPerPackage * packageCount;
    final board = includeBoard ? boardCostPerPackage * packageCount : 0.0;
    final total = woodCost + fastenerCost + labor + electricity + overhead + board;
    final suggested = total / (1 - rates.marginPercent / 100);
    final rounded = (suggested / 1000).ceil() * 1000.0;

    return PackingCalculation(
      frameLengthCm: frameLength,
      woodSticksPerPackage: sticksPerPackage,
      woodCost: woodCost,
      fastenerQuantity: fastenerQuantity,
      fastenerUnit: fastener == PackingFastener.nails ? 'gram' : 'buah',
      fastenerCost: fastenerCost,
      laborCost: labor,
      electricityCost: electricity,
      overheadCost: overhead,
      boardCost: board,
      totalCost: total,
      suggestedPrice: suggested,
      roundedPrice: rounded,
    );
  }
}
