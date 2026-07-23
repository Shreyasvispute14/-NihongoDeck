class SRSLogic {
  static Map<String, dynamic> calculateNextReview({
    required int quality,
    required int currentInterval,
    required int repetitions,
    required double easeFactor,
  }) {
    int nextInterval;
    int nextRepetitions;
    double nextEaseFactor = easeFactor;

    // If the user remembered it (Quality 3, 4, or 5)
    if (quality >= 3) {
      if (repetitions == 0) {
        nextInterval = 1;
      } else if (repetitions == 1) {
        nextInterval = 6;
      } else {
        nextInterval = (currentInterval * easeFactor).round();
      }
      nextRepetitions = repetitions + 1;
    } 
    // If the user forgot it (Quality 0, 1, or 2)
    else {
      nextRepetitions = 0;
      nextInterval = 1;
    }

    // Calculate new Ease Factor
    nextEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (nextEaseFactor < 1.3) nextEaseFactor = 1.3;

    // Calculate the actual future date in milliseconds
    DateTime nextReviewDate = DateTime.now().add(Duration(days: nextInterval));

    return {
      'interval': nextInterval,
      'repetitions': nextRepetitions,
      'ease_factor': nextEaseFactor,
      'next_review_date': nextReviewDate.millisecondsSinceEpoch,
    };
  }
}