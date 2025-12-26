class QuizResult {
  final int? id;
  final String userId;
  final int quizId;
  final int score;
  final int totalQuestions;
  final double percentage;
  final DateTime completedAt;
  final List<UserAnswer> answers;

  QuizResult({
    this.id,
    required this.userId,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.completedAt,
    required this.answers,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'quizId': quizId,
      'score': score,
      'totalQuestions': totalQuestions,
      'percentage': percentage,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'answers': answers.map((a) => a.toMap()).toList(),
    };
  }

  factory QuizResult.fromMap(Map<String, dynamic> map) {
    return QuizResult(
      id: map['id'],
      userId: map['userId'] ?? '',
      quizId: map['quizId'] ?? 0,
      score: map['score'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      percentage: (map['percentage'] ?? 0.0).toDouble(),
      completedAt: DateTime.fromMillisecondsSinceEpoch(map['completedAt'] ?? 0),
      answers: (map['answers'] as List<dynamic>? ?? [])
          .map((a) => UserAnswer.fromMap(a))
          .toList(),
    );
  }
}

class UserAnswer {
  final int questionIndex;
  final int selectedAnswer;
  final bool isCorrect;

  UserAnswer({
    required this.questionIndex,
    required this.selectedAnswer,
    required this.isCorrect,
  });

  Map<String, dynamic> toMap() {
    return {
      'questionIndex': questionIndex,
      'selectedAnswer': selectedAnswer,
      'isCorrect': isCorrect,
    };
  }

  factory UserAnswer.fromMap(Map<String, dynamic> map) {
    return UserAnswer(
      questionIndex: map['questionIndex'] ?? 0,
      selectedAnswer: map['selectedAnswer'] ?? 0,
      isCorrect: map['isCorrect'] ?? false,
    );
  }
}
