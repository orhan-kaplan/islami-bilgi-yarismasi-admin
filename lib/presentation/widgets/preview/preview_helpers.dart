import 'package:flutter/painting.dart';

import 'preview_tokens.dart';

/// Önizleme ekran bağlamı — feedback mesajının gösterildiği mobil uygulama ekranı.
enum PreviewContext { quizResult, dashboard, learnedResult }

/// Kategori → varsayılan önizleme bağlamı eşlemesi.
///
/// Feedback mesajının kategorisine göre hangi ekran bağlamında
/// önizleme yapılacağını belirler.
PreviewContext defaultContextForCategory(String category) {
  switch (category) {
    case 'quiz':
    case 'speed_quiz':
      return PreviewContext.quizResult;
    case 'time':
    case 'comeback':
    case 'streak':
      return PreviewContext.dashboard;
    case 'learned':
      return PreviewContext.learnedResult;
    default:
      return PreviewContext.quizResult;
  }
}

/// Learned subcategory → yüzde değeri eşlemesi.
///
/// Öğrenilen quiz sonuç ekranında gösterilecek yüzde değerini
/// alt kategoriye göre belirler.
int percentageForSubcategory(String? subcategory) {
  switch (subcategory) {
    case '100':
      return 100;
    case '75':
      return 75;
    case '50':
      return 50;
    case '25':
      return 25;
    case '0':
      return 0;
    default:
      return 50;
  }
}

/// Yüzde → vurgu rengi eşlemesi.
///
/// Öğrenilen quiz sonuç ekranında yüzdelik dilime göre
/// uygulanacak vurgu rengini döndürür.
Color accentColorForPercentage(int percentage) {
  if (percentage >= 100) return PreviewTokens.learnedFeedbackGold;
  if (percentage >= 75) return PreviewTokens.learnedFeedbackGreen;
  if (percentage >= 50) return PreviewTokens.learnedFeedbackBlue;
  if (percentage > 0) return PreviewTokens.learnedFeedbackOrange;
  return PreviewTokens.learnedFeedbackRed;
}

/// Quiz kategorisi başarı durumu belirleme.
///
/// Alt kategori 'failure' değilse başarılı kabul edilir.
bool isSuccessCategory(String? subcategory) {
  return subcategory != 'failure';
}
