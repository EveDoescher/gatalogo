import '../models/cat_analysis.dart';

class MockAnalysisService {
  static Future<CatAnalysis> analyze({required String catId}) async {
    // Simula um pequeno tempo de processamento.
    await Future.delayed(const Duration(milliseconds: 800));

    final selector =
        catId.codeUnits.fold<int>(0, (sum, value) => sum + value) % 3;

    switch (selector) {
      case 0:
        return CatAnalysis(
          catId: catId,
          status: AnalysisStatus.completed,
          coatType: 'Bicolor',
          primaryColor: 'Preto',
          colors: const [
            CoatColor(name: 'Preto', percentage: 68),
            CoatColor(name: 'Branco', percentage: 32),
          ],
          confidence: 0.92,
          analyzedAt: DateTime.now(),
        );

      case 1:
        return CatAnalysis(
          catId: catId,
          status: AnalysisStatus.completed,
          coatType: 'Rajado',
          primaryColor: 'Laranja',
          colors: const [
            CoatColor(name: 'Laranja', percentage: 79),
            CoatColor(name: 'Creme', percentage: 21),
          ],
          confidence: 0.89,
          analyzedAt: DateTime.now(),
        );

      default:
        return CatAnalysis(
          catId: catId,
          status: AnalysisStatus.completed,
          coatType: 'Tricolor',
          primaryColor: 'Branco',
          colors: const [
            CoatColor(name: 'Branco', percentage: 46),
            CoatColor(name: 'Preto', percentage: 31),
            CoatColor(name: 'Laranja', percentage: 23),
          ],
          confidence: 0.94,
          analyzedAt: DateTime.now(),
        );
    }
  }
}
