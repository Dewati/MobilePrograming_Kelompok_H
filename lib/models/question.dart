class Question {
  final int? id;
  final int quizId;
  final String question;
  final List<String> options;
  final String correctAnswer;

  Question({
    this.id,
    required this.quizId,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  // Convenience getters for individual options
  String get optionA => options.isNotEmpty ? options[0] : '';
  String get optionB => options.length > 1 ? options[1] : '';
  String get optionC => options.length > 2 ? options[2] : '';
  String get optionD => options.length > 3 ? options[3] : '';

  // Constructor for creating Question with individual options
  Question.withOptions({
    this.id,
    required this.quizId,
    required this.question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required this.correctAnswer,
  }) : options = [optionA, optionB, optionC, optionD];

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      quizId: json['quizId'],
      question: json['question'],
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quizId': quizId,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
    };
  }

  @override
  String toString() {
    return 'Question(id: $id, quizId: $quizId, question: $question, options: $options, correctAnswer: $correctAnswer)';
  }
}
