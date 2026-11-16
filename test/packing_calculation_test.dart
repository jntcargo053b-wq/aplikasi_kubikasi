import 'package:flutter_test/flutter_test.dart';
import 'package:volume_calculator/models/packing_calculation.dart';

void main() {
  test('packing frame estimate for 110 x 55 x 56 cm matches manual calculation', () {
    final result = PackingCalculation.calculate(
      lengthCm: 110,
      widthCm: 55,
      heightCm: 56,
    );

    expect(result.frameLengthCm, 1544);
    expect(result.woodSticksPerPackage, 8);
    expect(result.woodCost, 28000);
    expect(result.fastenerQuantity, closeTo(158.1395, 0.001));
    expect(result.fastenerCost, closeTo(3953.488, 0.01));
    expect(result.totalCost, closeTo(53453.488, 0.01));
    expect(result.roundedPrice, 72000);
    expect(result.boardCost, 0);
  });

  test('packing frame estimate for 54 x 43 x 45 cm matches manual calculation', () {
    final result = PackingCalculation.calculate(
      lengthCm: 54,
      widthCm: 43,
      heightCm: 45,
    );

    expect(result.frameLengthCm, 956);
    expect(result.woodSticksPerPackage, 5);
    expect(result.woodCost, 17500);
    expect(result.totalCost, closeTo(42953.488, 0.01));
    expect(result.roundedPrice, 58000);
  });

  test('screw option uses per-piece rate and optional board cost is added only when enabled', () {
    final withoutBoard = PackingCalculation.calculate(
      lengthCm: 54,
      widthCm: 43,
      heightCm: 45,
      fastener: PackingFastener.screws,
    );
    final withBoard = PackingCalculation.calculate(
      lengthCm: 54,
      widthCm: 43,
      heightCm: 45,
      fastener: PackingFastener.screws,
      includeBoard: true,
      boardCostPerPackage: 10000,
    );

    expect(withoutBoard.fastenerCost, 68 * 320);
    expect(withoutBoard.boardCost, 0);
    expect(withBoard.boardCost, 10000);
    expect(withBoard.totalCost - withoutBoard.totalCost, 10000);
  });

  test('multiple packages multiply materials and labor', () {
    final result = PackingCalculation.calculate(
      lengthCm: 54,
      widthCm: 43,
      heightCm: 45,
      packageCount: 2,
    );

    expect(result.woodSticksPerPackage, 5);
    expect(result.woodCost, 35000);
    expect(result.laborCost, 30000);
    expect(result.electricityCost, 3000);
    expect(result.overheadCost, 10000);
  });

  test('rejects invalid dimensions and invalid margin', () {
    expect(
      () => PackingCalculation.calculate(lengthCm: 0, widthCm: 43, heightCm: 45),
      throwsArgumentError,
    );
    expect(
      () => PackingCalculation.calculate(
        lengthCm: 54,
        widthCm: 43,
        heightCm: 45,
        rates: const PackingRates(marginPercent: 100),
      ),
      throwsArgumentError,
    );
  });

  test('custom wood length, frame multipliers, board sheets and extra material are applied', () {
    const customRates = PackingRates(
      woodPerLonjor: 5000,
      woodStickLengthCm: 300,
      woodLengthMultiplier: 6,
      woodWidthMultiplier: 4,
      woodHeightMultiplier: 6,
      screwPerPiece: 320,
      fastenersPerPackage: 40,
      boardSheetsPerPackage: 2,
      boardPricePerSheet: 12000,
      additionalMaterialQuantityPerPackage: 3,
      additionalMaterialPricePerUnit: 1500,
      laborPerPackage: 10000,
      electricityPerPackage: 1000,
      overheadPerPackage: 2000,
      marginPercent: 20,
    );
    final result = PackingCalculation.calculate(
      lengthCm: 100,
      widthCm: 50,
      heightCm: 40,
      rates: customRates,
      fastener: PackingFastener.screws,
      includeBoard: true,
    );

    expect(result.frameLengthCm, 1040);
    expect(result.woodSticksPerPackage, 4);
    expect(result.woodCost, 20000);
    expect(result.fastenerQuantity, 40);
    expect(result.fastenerCost, 12800);
    expect(result.boardQuantity, 2);
    expect(result.boardCost, 24000);
    expect(result.additionalMaterialQuantity, 3);
    expect(result.additionalMaterialCost, 4500);
    expect(result.totalCost, 74300);
    expect(result.roundedPrice, 93000);
  });

  test('custom packing rates survive JSON round trip', () {
    const rates = PackingRates(
      woodStickLengthCm: 250,
      woodLengthMultiplier: 5,
      woodWidthMultiplier: 6,
      woodHeightMultiplier: 3,
      fastenersPerPackage: 44,
      boardSheetsPerPackage: 1.5,
      boardPricePerSheet: 18000,
      additionalMaterialQuantityPerPackage: 2,
      additionalMaterialPricePerUnit: 3500,
    );
    final restored = PackingRates.fromJson(rates.toJson());

    expect(restored.woodStickLengthCm, 250);
    expect(restored.woodLengthMultiplier, 5);
    expect(restored.woodWidthMultiplier, 6);
    expect(restored.woodHeightMultiplier, 3);
    expect(restored.fastenersPerPackage, 44);
    expect(restored.boardSheetsPerPackage, 1.5);
    expect(restored.boardPricePerSheet, 18000);
    expect(restored.additionalMaterialQuantityPerPackage, 2);
    expect(restored.additionalMaterialPricePerUnit, 3500);
  });

}
