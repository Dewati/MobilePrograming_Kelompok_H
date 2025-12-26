import '../models/question.dart';
import '../models/quiz.dart';
import 'firebase_quiz_service.dart';

class QuizService {
  // Singleton pattern
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  final FirebaseQuizService _firebaseService = FirebaseQuizService();

  // Create new quiz
  Future<String?> createQuiz({
    required String title,
    required String subject,
    required String description,
    required int timeLimit,
    String? materialContent,
    String? materialUrl,
    String? materialLink,
    String materialType = 'text',
    required List<Question> questions,
    required String teacherId,
    String? materialFileName,
  }) async {
    return await _firebaseService.createQuiz(
      title: title,
      subject: subject,
      description: description,
      timeLimit: timeLimit,
      materialContent: materialContent,
      materialUrl: materialUrl,
      materialLink: materialLink,
      materialType: materialType,
      questions: questions,
      teacherId: teacherId,
      materialFileName: materialFileName,
    );
  }

  // Upload material file
  Future<String?> uploadMaterialFile(dynamic file, String fileName) async {
    return await _firebaseService.uploadMaterialFile(file, fileName);
  }

  // Get all quizzes
  Future<List<Quiz>> getAllQuizzes() async {
    return await _firebaseService.getAllQuizzes();
  }

  // Get quizzes by subject
  Future<List<Quiz>> getQuizzesBySubject(String subject) async {
    return await _firebaseService.getQuizzesBySubject(subject);
  }

  // Get teacher's quizzes
  Stream<List<Quiz>> getTeacherQuizzes(String teacherId) {
    return _firebaseService.getTeacherQuizzes(teacherId);
  }

  // Get available quizzes for students
  Stream<List<Quiz>> getAvailableQuizzes() {
    return _firebaseService.getAvailableQuizzes();
  }

  // Get quiz by ID
  Future<Quiz?> getQuizById(String quizId) async {
    return await _firebaseService.getQuizById(quizId);
  }

  // Update quiz
  Future<void> updateQuiz(String quizId, Quiz quiz) async {
    return await _firebaseService.updateQuiz(quizId, quiz);
  }

  // Delete quiz
  Future<void> deleteQuiz(String quizId) async {
    return await _firebaseService.deleteQuiz(quizId);
  }

  // Delete quiz by Quiz object
  Future<void> deleteQuizByObject(Quiz quiz) async {
    return await _firebaseService.deleteQuizByObject(quiz);
  }

  // Get questions for a specific quiz
  Future<List<Question>> getQuizQuestions(Quiz quiz) async {
    return await _firebaseService.getQuizQuestions(quiz);
  }

  // Update quiz by Quiz object
  Future<void> updateQuizByObject(Quiz originalQuiz, Quiz updatedQuiz) async {
    return await _firebaseService.updateQuizByObject(originalQuiz, updatedQuiz);
  }

  // Submit quiz attempt
  Future<String> submitQuizAttempt({
    required String quizId,
    required String studentId,
    required Map<int, String> answers,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return await _firebaseService.submitQuizAttempt(
      quizId: quizId,
      studentId: studentId,
      answers: answers,
      startTime: startTime,
      endTime: endTime,
    );
  }

  // Get student attempts
  Stream<List<Map<String, dynamic>>> getStudentAttempts(String studentId) {
    return _firebaseService.getStudentAttempts(studentId);
  }

  // Get quiz attempts (for teachers)
  Stream<List<Map<String, dynamic>>> getQuizAttempts(String quizId) {
    return _firebaseService.getQuizAttempts(quizId);
  }

  // Get quiz statistics
  Future<Map<String, dynamic>> getQuizStatistics(String teacherId) async {
    return await _firebaseService.getQuizStatistics(teacherId);
  }

  // Legacy support methods for backward compatibility

  // Submit quiz and calculate score (legacy support)
  Future<int> submitQuiz(int quizId, Map<int, String> answers) async {
    final quiz = await getQuizById(quizId.toString());
    if (quiz == null) return 0;

    int correctCount = 0;

    for (int i = 0; i < quiz.questions.length; i++) {
      final question = quiz.questions[i];
      final userAnswer = answers[i];

      if (userAnswer != null && userAnswer == question.correctAnswer) {
        correctCount++;
      }
    }

    return correctCount;
  }

  // Get quiz results (legacy support)
  Future<List<Map<String, dynamic>>> getQuizResults(int quizId) async {
    // Convert to new format
    final attempts = _firebaseService.getQuizAttempts(quizId.toString());
    final List<Map<String, dynamic>> results = [];

    await for (final attemptsList in attempts.take(1)) {
      for (final attempt in attemptsList) {
        results.add({
          'name': 'Student', // Would need user info lookup
          'email': attempt['studentId'] ?? '',
          'score': attempt['correctAnswers'] ?? 0,
          'totalQuestions': attempt['totalQuestions'] ?? 0,
          'completedAt':
              (attempt['submittedAt'] as dynamic)?.millisecondsSinceEpoch ?? 0,
        });
      }
      break; // Only get first batch
    }

    return results;
  }
}
