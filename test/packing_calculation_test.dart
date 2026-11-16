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
}
