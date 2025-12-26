import 'question.dart';

class Quiz {
  final int? id;
  final String title;
  final String subject;
  final String description;
  final int timeLimit; // in minutes
  final String? materialContent;
  final String? materialUrl;
  final String? materialLink; // explicit link field (e.g., https://...)
  final String? materialFileName; // explicit file name chosen by teacher
  final String materialType; // 'text', 'file', 'pdf', 'image'
  final List<Question> questions;
  final DateTime createdAt;
  final String createdBy;

  Quiz({
    this.id,
    required this.title,
    required this.subject,
    required this.description,
    required this.timeLimit,
    this.materialContent,
    this.materialUrl,
    this.materialLink,
    this.materialFileName,
    this.materialType = 'text',
    required this.questions,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'timeLimit': timeLimit,
      'materialContent': materialContent,
      'materialUrl': materialUrl,
      'materialLink': materialLink,
      'materialFileName': materialFileName,
      'materialType': materialType,
      'questions': questions.map((q) => q.toJson()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'createdBy': createdBy,
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      id: map['id'],
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      description: map['description'] ?? '',
      timeLimit: map['timeLimit'] ?? 60,
      materialContent: map['materialContent'],
      materialUrl: map['materialUrl'],
      materialLink: map['materialLink'],
      materialFileName: map['materialFileName'],
      materialType: map['materialType'] ?? 'text',
      questions: (map['questions'] as List<dynamic>? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Quiz copyWith({
    int? id,
    String? title,
    String? subject,
    String? description,
    int? timeLimit,
    String? materialContent,
    String? materialUrl,
    String? materialLink,
    String? materialFileName,
    List<Question>? questions,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      timeLimit: timeLimit ?? this.timeLimit,
      materialContent: materialContent ?? this.materialContent,
      materialUrl: materialUrl ?? this.materialUrl,
      materialLink: materialLink ?? this.materialLink,
      materialFileName: materialFileName ?? this.materialFileName,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
