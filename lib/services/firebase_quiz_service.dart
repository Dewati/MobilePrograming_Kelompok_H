import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/quiz.dart';
import '../models/question.dart';

class FirebaseQuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new quiz
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
    try {
      // Generate quiz identifier for consistent referencing
      final quizIdentifier = '${title}_${subject}_${teacherId}'.hashCode
          .abs()
          .toString();

      // Create quiz document
      final docRef = await _firestore.collection('quizzes').add({
        'title': title,
        'description': description,
        'subject': subject,
        'timeLimit': timeLimit,
        'materialContent': materialContent,
        'materialUrl': materialUrl,
        'materialLink': materialLink,
        'materialType': materialType,
        'materialFileName': materialFileName,
        'totalQuestions': questions.length,
        'totalMarks': questions.length.toDouble(), // 1 mark per question
        'passingMarks': (questions.length * 0.6).toDouble(), // 60% passing
        'createdBy': teacherId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'quizIdentifier':
            quizIdentifier, // Add this field for consistent referencing
      });

      // Add questions to subcollection
      final batch = _firestore.batch();

      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final questionRef = docRef.collection('questions').doc();

        batch.set(questionRef, {
          'question': question.question,
          'options': question.options,
          'correctAnswer': question.correctAnswer,
          'marks': 1.0,
          'order': i,
        });
      }

      await batch.commit();
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create quiz: $e');
    }
  }

  // Upload quiz material file
  Future<String?> uploadMaterialFile(File file, String fileName) async {
    try {
      final ref = _storage.ref().child('quiz_materials/$fileName');
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // Get quizzes created by a teacher
  Stream<List<Quiz>> getTeacherQuizzes(String teacherId) {
    return _firestore
        .collection('quizzes')
        .where('createdBy', isEqualTo: teacherId)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Quiz> quizzes = [];

          for (var doc in snapshot.docs) {
            final quiz = await _buildQuizFromDoc(doc);
            quizzes.add(quiz);
          }

          return quizzes;
        });
  }

  // Get all active quizzes for students
  Stream<List<Quiz>> getAvailableQuizzes() {
    return _firestore
        .collection('quizzes')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Quiz> quizzes = [];

          for (var doc in snapshot.docs) {
            final quiz = await _buildQuizFromDoc(doc);
            quizzes.add(quiz);
          }

          return quizzes;
        });
  }

  // Get a specific quiz by ID
  Future<Quiz?> getQuizById(String quizId) async {
    try {
      final doc = await _firestore.collection('quizzes').doc(quizId).get();

      if (!doc.exists) return null;

      return await _buildQuizFromDocSnapshot(doc);
    } catch (e) {
      throw Exception('Failed to get quiz: $e');
    }
  }

  // Get questions for a specific quiz
  Future<List<Question>> getQuizQuestions(Quiz quiz) async {
    try {
      final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
          .hashCode
          .abs()
          .toString();

      // First, try to find by quizIdentifier
      var querySnapshot = await _firestore
          .collection('quizzes')
          .where('quizIdentifier', isEqualTo: quizIdentifier)
          .get();

      // If not found by quizIdentifier, try to find by title, subject, and createdBy
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('quizzes')
            .where('title', isEqualTo: quiz.title)
            .where('subject', isEqualTo: quiz.subject)
            .where('createdBy', isEqualTo: quiz.createdBy)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      final quizDoc = querySnapshot.docs.first;
      final questionsSnapshot = await quizDoc.reference
          .collection('questions')
          .orderBy('order')
          .get();

      List<Question> questions = [];
      for (var doc in questionsSnapshot.docs) {
        final data = doc.data();
        questions.add(
          Question(
            quizId: quiz.id ?? 0,
            question: data['question'] ?? '',
            options: List<String>.from(data['options'] ?? []),
            correctAnswer: data['correctAnswer'] ?? 'A',
          ),
        );
      }

      return questions;
    } catch (e) {
      throw Exception('Failed to get quiz questions: $e');
    }
  }

  // Update quiz by Quiz object (using identifier system)
  Future<void> updateQuizByObject(Quiz originalQuiz, Quiz updatedQuiz) async {
    try {
      final quizIdentifier =
          '${originalQuiz.title}_${originalQuiz.subject}_${originalQuiz.createdBy}'
              .hashCode
              .abs()
              .toString();

      // Find the quiz document using the identifier
      var querySnapshot = await _firestore
          .collection('quizzes')
          .where('quizIdentifier', isEqualTo: quizIdentifier)
          .get();

      // If not found by quizIdentifier, try to find by title, subject, and createdBy
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('quizzes')
            .where('title', isEqualTo: originalQuiz.title)
            .where('subject', isEqualTo: originalQuiz.subject)
            .where('createdBy', isEqualTo: originalQuiz.createdBy)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Quiz tidak ditemukan untuk update');
      }

      final quizDoc = querySnapshot.docs.first;
      final batch = _firestore.batch();

      // Generate new quiz identifier if title/subject changed
      final newQuizIdentifier =
          '${updatedQuiz.title}_${updatedQuiz.subject}_${updatedQuiz.createdBy}'
              .hashCode
              .abs()
              .toString();

      // Update quiz document
      batch.update(quizDoc.reference, {
        'title': updatedQuiz.title,
        'description': updatedQuiz.description,
        'subject': updatedQuiz.subject,
        'timeLimit': updatedQuiz.timeLimit,
        'materialContent': updatedQuiz.materialContent,
        'materialUrl': updatedQuiz.materialUrl,
        'materialLink': updatedQuiz.materialLink,
        'materialFileName': updatedQuiz.materialFileName,
        'materialType': updatedQuiz.materialType,
        'totalQuestions': updatedQuiz.questions.length,
        'quizIdentifier': newQuizIdentifier,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete existing questions
      final existingQuestionsSnapshot = await quizDoc.reference
          .collection('questions')
          .get();

      for (var questionDoc in existingQuestionsSnapshot.docs) {
        batch.delete(questionDoc.reference);
      }

      // Add updated questions
      for (int i = 0; i < updatedQuiz.questions.length; i++) {
        final question = updatedQuiz.questions[i];
        final questionRef = quizDoc.reference.collection('questions').doc();

        batch.set(questionRef, {
          'question': question.question,
          'options': question.options,
          'correctAnswer': question.correctAnswer,
          'marks': 1.0,
          'order': i,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update quiz: $e');
    }
  }

  // Update quiz (legacy method for backward compatibility)
  Future<void> updateQuiz(String quizId, Quiz quiz) async {
    try {
      final batch = _firestore.batch();

      // Update quiz document
      final quizRef = _firestore.collection('quizzes').doc(quizId);
      batch.update(quizRef, {
        'title': quiz.title,
        'description': quiz.description,
        'subject': quiz.subject,
        'timeLimit': quiz.timeLimit,
        'materialContent': quiz.materialContent,
        'materialUrl': quiz.materialUrl,
        'materialLink': quiz.materialLink,
        'materialFileName': quiz.materialFileName,
        'materialType': quiz.materialType,
        'totalQuestions': quiz.questions.length,
        'totalMarks': quiz.questions.length.toDouble(),
        'passingMarks': (quiz.questions.length * 0.6).toDouble(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Delete existing questions
      final questionsSnapshot = await quizRef.collection('questions').get();
      for (var doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Add updated questions
      for (int i = 0; i < quiz.questions.length; i++) {
        final question = quiz.questions[i];
        final questionRef = quizRef.collection('questions').doc();

        batch.set(questionRef, {
          'question': question.question,
          'options': question.options,
          'correctAnswer': question.correctAnswer,
          'marks': 1.0,
          'order': i,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to update quiz: $e');
    }
  }

  // Delete quiz
  Future<void> deleteQuiz(String quizId) async {
    try {
      final batch = _firestore.batch();

      // Delete all questions first
      final questionsSnapshot = await _firestore
          .collection('quizzes')
          .doc(quizId)
          .collection('questions')
          .get();

      for (var doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete quiz document
      batch.delete(_firestore.collection('quizzes').doc(quizId));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete quiz: $e');
    }
  }

  // Delete quiz by Quiz object (using multiple search strategies)
  Future<void> deleteQuizByObject(Quiz quiz) async {
    try {
      // Strategy 1: Search by quizIdentifier (for new quizzes)
      final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
          .hashCode
          .abs()
          .toString();
      var querySnapshot = await _firestore
          .collection('quizzes')
          .where('quizIdentifier', isEqualTo: quizIdentifier)
          .get();

      // Strategy 2: Search by title, subject, and createdBy (for older quizzes)
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('quizzes')
            .where('title', isEqualTo: quiz.title)
            .where('subject', isEqualTo: quiz.subject)
            .where('createdBy', isEqualTo: quiz.createdBy)
            .get();
      }

      // Strategy 3: Search just by title and createdBy (more flexible)
      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await _firestore
            .collection('quizzes')
            .where('title', isEqualTo: quiz.title)
            .where('createdBy', isEqualTo: quiz.createdBy)
            .get();
      }

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Quiz tidak ditemukan dalam database');
      }

      final batch = _firestore.batch();

      for (var quizDoc in querySnapshot.docs) {
        // Delete all questions first
        final questionsSnapshot = await quizDoc.reference
            .collection('questions')
            .get();

        for (var questionDoc in questionsSnapshot.docs) {
          batch.delete(questionDoc.reference);
        }

        // Delete quiz document
        batch.delete(quizDoc.reference);
      }

      // Also delete related quiz attempts (try both identifiers)
      final attemptsSnapshot1 = await _firestore
          .collection('quiz_attempts')
          .where('quizIdentifier', isEqualTo: quizIdentifier)
          .get();

      for (var attemptDoc in attemptsSnapshot1.docs) {
        batch.delete(attemptDoc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Gagal menghapus quiz: ${e.toString()}');
    }
  }

  // Submit quiz attempt
  Future<String> submitQuizAttempt({
    required String quizId,
    required String studentId,
    required Map<int, String> answers,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      // Get quiz and questions to calculate score
      final quiz = await getQuizById(quizId);
      if (quiz == null) throw Exception('Quiz not found');

      int correctAnswers = 0;
      double totalScore = 0;

      // Calculate score
      for (int i = 0; i < quiz.questions.length; i++) {
        final question = quiz.questions[i];
        final userAnswer = answers[i];

        if (userAnswer == question.correctAnswer) {
          correctAnswers++;
          totalScore += 1.0; // 1 mark per question
        }
      }

      final maxScore = quiz.questions.length.toDouble();
      final percentage = (totalScore / maxScore) * 100;
      final passed = totalScore >= (maxScore * 0.6); // 60% passing

      // Save attempt to Firestore
      final attemptRef = await _firestore.collection('quiz_attempts').add({
        'quizId': quizId,
        'studentId': studentId,
        'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'totalScore': totalScore,
        'maxScore': maxScore,
        'correctAnswers': correctAnswers,
        'totalQuestions': quiz.questions.length,
        'percentage': percentage,
        'passed': passed,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Quiz attempt submitted successfully with ID: ${attemptRef.id}');

      // Return score in format "correctAnswers/totalQuestions"
      return '${correctAnswers.toInt()}/${quiz.questions.length}';
    } catch (e) {
      throw Exception('Failed to submit quiz: $e');
    }
  }

  // Submit quiz attempt with Quiz object directly (no need for separate quizId lookup)
  Future<String> submitQuizAttemptWithQuiz({
    required Quiz quiz,
    required String studentId,
    required Map<int, String> answers,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      int correctAnswers = 0;
      double totalScore = 0;

      // Calculate score
      for (int i = 0; i < quiz.questions.length; i++) {
        final question = quiz.questions[i];
        final userAnswer = answers[i];

        if (userAnswer == question.correctAnswer) {
          correctAnswers++;
          totalScore += 1.0; // 1 mark per question
        }
      }

      final maxScore = quiz.questions.length.toDouble();
      final percentage = (totalScore / maxScore) * 100;
      final passed = totalScore >= (maxScore * 0.6); // 60% passing

      // Generate a unique identifier for this quiz (use title + subject hash)
      final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
          .hashCode
          .abs()
          .toString();

      // Save attempt to Firestore
      final attemptRef = await _firestore.collection('quiz_attempts').add({
        'quizIdentifier': quizIdentifier,
        'quizTitle': quiz.title,
        'quizSubject': quiz.subject,
        'studentId': studentId,
        'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'totalScore': totalScore,
        'maxScore': maxScore,
        'correctAnswers': correctAnswers,
        'totalQuestions': quiz.questions.length,
        'percentage': percentage,
        'passed': passed,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Quiz attempt submitted successfully with ID: ${attemptRef.id}');

      // Return score in format "correctAnswers/totalQuestions"
      return '${correctAnswers.toInt()}/${quiz.questions.length}';
    } catch (e) {
      print('❌ Error submitting quiz attempt: $e');
      throw Exception('Failed to submit quiz: $e');
    }
  }

  // Get student's quiz attempts
  Stream<List<Map<String, dynamic>>> getStudentAttempts(String studentId) {
    return _firestore
        .collection('quiz_attempts')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          // Manual sorting to avoid composite index requirement
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort by submittedAt timestamp manually
          docs.sort((a, b) {
            final timestampA = a['submittedAt'] as Timestamp?;
            final timestampB = b['submittedAt'] as Timestamp?;

            if (timestampA == null && timestampB == null) return 0;
            if (timestampA == null) return 1;
            if (timestampB == null) return -1;

            return timestampB.compareTo(timestampA); // Descending order
          });

          return docs;
        });
  }

  // Get attempts for a specific quiz (for teachers)
  Stream<List<Map<String, dynamic>>> getQuizAttempts(String quizId) {
    return _firestore
        .collection('quiz_attempts')
        .where('quizId', isEqualTo: quizId)
        .snapshots()
        .map((snapshot) {
          // Manual sorting to avoid composite index requirement
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort by submittedAt timestamp manually
          docs.sort((a, b) {
            final timestampA = a['submittedAt'] as Timestamp?;
            final timestampB = b['submittedAt'] as Timestamp?;

            if (timestampA == null && timestampB == null) return 0;
            if (timestampA == null) return 1;
            if (timestampB == null) return -1;

            return timestampB.compareTo(timestampA); // Descending order
          });

          return docs;
        });
  }

  // Get attempts for a specific quiz by Quiz object (for teachers)
  Stream<List<Map<String, dynamic>>> getQuizAttemptsByQuiz(Quiz quiz) {
    final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
        .hashCode
        .abs()
        .toString();

    return _firestore
        .collection('quiz_attempts')
        .where('quizIdentifier', isEqualTo: quizIdentifier)
        .snapshots()
        .map((snapshot) {
          // Manual sorting to avoid composite index requirement
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

          // Sort by submittedAt timestamp manually
          docs.sort((a, b) {
            final timestampA = a['submittedAt'] as Timestamp?;
            final timestampB = b['submittedAt'] as Timestamp?;

            if (timestampA == null && timestampB == null) return 0;
            if (timestampA == null) return 1;
            if (timestampB == null) return -1;

            return timestampB.compareTo(timestampA); // Descending order
          });

          return docs;
        });
  }

  // Get quiz statistics for teacher dashboard
  Future<Map<String, dynamic>> getQuizStatistics(String teacherId) async {
    try {
      // Get total quizzes created
      final quizzesSnapshot = await _firestore
          .collection('quizzes')
          .where('createdBy', isEqualTo: teacherId)
          .get();

      final totalQuizzes = quizzesSnapshot.docs.length;

      // Get total attempts across all quizzes
      int totalAttempts = 0;
      double averageScore = 0;
      int passedAttempts = 0;

      for (var quizDoc in quizzesSnapshot.docs) {
        final attemptsSnapshot = await _firestore
            .collection('quiz_attempts')
            .where('quizId', isEqualTo: quizDoc.id)
            .get();

        totalAttempts += attemptsSnapshot.docs.length;

        for (var attemptDoc in attemptsSnapshot.docs) {
          final data = attemptDoc.data();
          averageScore += (data['percentage'] ?? 0).toDouble();
          if (data['passed'] == true) {
            passedAttempts++;
          }
        }
      }

      if (totalAttempts > 0) {
        averageScore = averageScore / totalAttempts;
      }

      return {
        'totalQuizzes': totalQuizzes,
        'totalAttempts': totalAttempts,
        'averageScore': averageScore,
        'passedAttempts': passedAttempts,
        'passRate': totalAttempts > 0
            ? (passedAttempts / totalAttempts) * 100
            : 0,
      };
    } catch (e) {
      throw Exception('Failed to get quiz statistics: $e');
    }
  }

  // Helper method to build Quiz object from QueryDocumentSnapshot
  Future<Quiz> _buildQuizFromDoc(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Get questions from subcollection
    final questionsSnapshot = await doc.reference
        .collection('questions')
        .orderBy('order')
        .get();

    final questions = questionsSnapshot.docs.map((questionDoc) {
      final questionData = questionDoc.data();
      return Question(
        quizId: 0, // Will be set when needed
        question: questionData['question'] ?? '',
        options: List<String>.from(questionData['options'] ?? []),
        correctAnswer: questionData['correctAnswer'] ?? '',
      );
    }).toList();

    return Quiz(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subject: data['subject'] ?? '',
      timeLimit: data['timeLimit'] ?? 0,
      materialContent: data['materialContent'],
      materialUrl: data['materialUrl'],
      materialLink: data['materialLink'],
      materialFileName: data['materialFileName'],
      materialType: data['materialType'] ?? 'text',
      questions: questions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  // Helper method for DocumentSnapshot
  Future<Quiz> _buildQuizFromDocSnapshot(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Get questions from subcollection
    final questionsSnapshot = await doc.reference
        .collection('questions')
        .orderBy('order')
        .get();

    final questions = questionsSnapshot.docs.map((questionDoc) {
      final questionData = questionDoc.data();
      return Question(
        quizId: 0, // Will be set when needed
        question: questionData['question'] ?? '',
        options: List<String>.from(questionData['options'] ?? []),
        correctAnswer: questionData['correctAnswer'] ?? '',
      );
    }).toList();

    return Quiz(
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subject: data['subject'] ?? '',
      timeLimit: data['timeLimit'] ?? 0,
      materialContent: data['materialContent'],
      materialUrl: data['materialUrl'],
      materialLink: data['materialLink'],
      materialFileName: data['materialFileName'],
      materialType: data['materialType'] ?? 'text',
      questions: questions,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  // Legacy method support for existing code
  Future<List<Quiz>> getAllQuizzes() async {
    final snapshot = await _firestore
        .collection('quizzes')
        .where('isActive', isEqualTo: true)
        .get();

    List<Quiz> quizzes = [];
    for (var doc in snapshot.docs) {
      final quiz = await _buildQuizFromDoc(doc);
      quizzes.add(quiz);
    }

    // Sort manually to avoid composite index requirement
    quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quizzes;
  }

  // Get quizzes by subject
  Future<List<Quiz>> getQuizzesBySubject(String subject) async {
    final snapshot = await _firestore
        .collection('quizzes')
        .where('isActive', isEqualTo: true)
        .where('subject', isEqualTo: subject)
        .get();

    List<Quiz> quizzes = [];
    for (var doc in snapshot.docs) {
      final quiz = await _buildQuizFromDoc(doc);
      quizzes.add(quiz);
    }

    // Sort manually to avoid composite index requirement
    quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quizzes;
  }
}
