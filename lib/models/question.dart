class Question {
  final String text;
  final List<String> choices; // shuffled once, at construction
  final String correct;

  const Question({
    required this.text,
    required this.choices,
    required this.correct,
  });
}

class QuizException implements Exception {
  final String message;
  const QuizException(this.message);
  @override
  String toString() => message;
}
