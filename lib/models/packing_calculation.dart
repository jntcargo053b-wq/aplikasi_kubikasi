enum PackingFastener { nails, screws }

class PackingRates {
  final double woodPerLonjor;
  final double woodStickLengthCm;
  final double woodLengthMultiplier;
  final double woodWidthMultiplier;
  final double woodHeightMultiplier;
  final double screwPerPiece;
  final double nailPerGram;
  final int nailsPerKg;
  final double laborPerPackage;
  final double electricityPerPackage;
  final double overheadPerPackage;
  final int fastenersPerPackage;
  final double boardSheetsPerPackage;
  final double boardPricePerSheet;
  final String additionalMaterialName;
  final double additionalMaterialQuantityPerPackage;
  final double additionalMaterialPricePerUnit;
  final double marginPercent;

  const PackingRates({
    this.woodPerLonjor = 3500,
    this.woodStickLengthCm = 200,
    this.woodLengthMultiplier = 8,
    this.woodWidthMultiplier = 8,
    this.woodHeightMultiplier = 4,
    this.screwPerPiece = 320,
    this.nailPerGram = 25,
    this.nailsPerKg = 430,
    this.laborPerPackage = 15000,
    this.electricityPerPackage = 1500,
    this.overheadPerPackage = 5000,
    this.fastenersPerPackage = 68,
    this.boardSheetsPerPackage = 0,
    this.boardPricePerSheet = 0,
    this.additionalMaterialName = 'Bahan tambahan',
    this.additionalMaterialQuantityPerPackage = 0,
    this.additionalMaterialPricePerUnit = 0,
    this.marginPercent = 25,
  });

  Map<String, dynamic> toJson() => {
    'woodPerLonjor': woodPerLonjor,
    'woodStickLengthCm': woodStickLengthCm,
    'woodLengthMultiplier': woodLengthMultiplier,
    'woodWidthMultiplier': woodWidthMultiplier,
    'woodHeightMultiplier': woodHeightMultiplier,
    'screwPerPiece': screwPerPiece,
    'nailPerGram': nailPerGram,
    'nailsPerKg': nailsPerKg,
    'laborPerPackage': laborPerPackage,
    'electricityPerPackage': electricityPerPackage,
    'overheadPerPackage': overheadPerPackage,
    'fastenersPerPackage': fastenersPerPackage,
    'boardSheetsPerPackage': boardSheetsPerPackage,
    'boardPricePerSheet': boardPricePerSheet,
    'additionalMaterialName': additionalMaterialName,
    'additionalMaterialQuantityPerPackage': additionalMaterialQuantityPerPackage,
    'additionalMaterialPricePerUnit': additionalMaterialPricePerUnit,
    'marginPercent': marginPercent,
  };

  factory PackingRates.fromJson(Map<String, dynamic> json) => PackingRates(
    woodPerLonjor: (json['woodPerLonjor'] as num?)?.toDouble() ?? 3500,
    woodStickLengthCm: (json['woodStickLengthCm'] as num?)?.toDouble() ?? 200,
    woodLengthMultiplier: (json['woodLengthMultiplier'] as num?)?.toDouble() ?? 8,
    woodWidthMultiplier: (json['woodWidthMultiplier'] as num?)?.toDouble() ?? 8,
    woodHeightMultiplier: (json['woodHeightMultiplier'] as num?)?.toDouble() ?? 4,
    screwPerPiece: (json['screwPerPiece'] as num?)?.toDouble() ?? 320,
    nailPerGram: (json['nailPerGram'] as num?)?.toDouble() ?? 25,
    nailsPerKg: (json['nailsPerKg'] as num?)?.toInt() ?? 430,
    laborPerPackage: (json['laborPerPackage'] as num?)?.toDouble() ?? 15000,
    electricityPerPackage: (json['electricityPerPackage'] as num?)?.toDouble() ?? 1500,
    overheadPerPackage: (json['overheadPerPackage'] as num?)?.toDouble() ?? 5000,
    fastenersPerPackage: (json['fastenersPerPackage'] as num?)?.toInt() ?? 68,
    boardSheetsPerPackage: (json['boardSheetsPerPackage'] as num?)?.toDouble() ?? 0,
    boardPricePerSheet: (json['boardPricePerSheet'] as num?)?.toDouble() ?? 0,
    additionalMaterialName: json['additionalMaterialName'] as String? ?? 'Bahan tambahan',
    additionalMaterialQuantityPerPackage: (json['additionalMaterialQuantityPerPackage'] as num?)?.toDouble() ?? 0,
    additionalMaterialPricePerUnit: (json['additionalMaterialPricePerUnit'] as num?)?.toDouble() ?? 0,
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
  final double boardQuantity;
  final double boardCost;
  final double additionalMaterialQuantity;
  final double additionalMaterialCost;
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
    required this.boardQuantity,
    required this.boardCost,
    required this.additionalMaterialQuantity,
    required this.additionalMaterialCost,
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
    double? boardCostPerPackage,
  }) {
    final values = [
      lengthCm, widthCm, heightCm,
      rates.woodPerLonjor, rates.woodStickLengthCm,
      rates.woodLengthMultiplier, rates.woodWidthMultiplier,
      rates.woodHeightMultiplier, rates.screwPerPiece,
      rates.nailPerGram, rates.laborPerPackage,
      rates.electricityPerPackage, rates.overheadPerPackage,
      rates.boardSheetsPerPackage, rates.boardPricePerSheet,
      rates.additionalMaterialQuantityPerPackage,
      rates.additionalMaterialPricePerUnit,
      rates.marginPercent, boardCostPerPackage ?? 0,
    ];
    if (values.any((value) => !value.isFinite || value < 0) ||
        lengthCm <= 0 || widthCm <= 0 || heightCm <= 0 ||
        rates.woodStickLengthCm <= 0 || packageCount <= 0 ||
        rates.nailsPerKg <= 0 || rates.fastenersPerPackage < 0 ||
        rates.marginPercent >= 100) {
      throw ArgumentError('Input kalkulasi packing tidak valid.');
    }

    final frameLength = rates.woodLengthMultiplier * lengthCm +
        rates.woodWidthMultiplier * widthCm +
        rates.woodHeightMultiplier * heightCm;
    final sticksPerPackage = (frameLength / rates.woodStickLengthCm).ceil();
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
    final boardQuantity = includeBoard ? rates.boardSheetsPerPackage * packageCount : 0.0;
    final board = includeBoard
        ? (boardCostPerPackage ?? boardQuantity * rates.boardPricePerSheet * 1.0)
        : 0.0;
    final additionalQuantity = rates.additionalMaterialQuantityPerPackage * packageCount;
    final additional = additionalQuantity * rates.additionalMaterialPricePerUnit;
    final total = woodCost + fastenerCost + labor + electricity +
        overhead + board + additional;
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
      boardQuantity: boardQuantity,
      boardCost: board,
      additionalMaterialQuantity: additionalQuantity,
      additionalMaterialCost: additional,
      totalCost: total,
      suggestedPrice: suggested,
      roundedPrice: rounded,
    );
  }
}
