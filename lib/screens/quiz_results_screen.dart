import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_quiz_service.dart';
import '../models/quiz.dart';

class QuizResultsScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizResultsScreen({super.key, required this.quiz});

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final FirebaseQuizService _quizService = FirebaseQuizService();
  List<Map<String, dynamic>> results = [];
  Map<String, String> studentNames = {}; // Cache untuk nama siswa
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      isLoading = true;
    });

    try {
      _quizService.getQuizAttemptsByQuiz(widget.quiz).listen((
        attemptsList,
      ) async {
        print('📊 Quiz Results: Loaded ${attemptsList.length} attempts');

        // Load student names
        for (final attempt in attemptsList) {
          final studentId = attempt['studentId'] as String?;
          if (studentId != null && !studentNames.containsKey(studentId)) {
            final studentName = await _getStudentName(studentId);
            studentNames[studentId] = studentName;
          }
        }

        for (int i = 0; i < attemptsList.length; i++) {
          final attempt = attemptsList[i];
          print('📊 Attempt $i keys: ${attempt.keys.toList()}');
          print(
            '📊 Attempt $i values: correctAnswers=${attempt['correctAnswers']}, totalQuestions=${attempt['totalQuestions']}, percentage=${attempt['percentage']}, studentId=${attempt['studentId']}, submittedAt=${attempt['submittedAt']}',
          );
        }
        if (mounted) {
          setState(() {
            results = attemptsList;
            isLoading = false;
          });
        }
      });
    } catch (e) {
      print('❌ Error loading quiz results: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<String> _getStudentName(String studentId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final name = data?['name'] as String?;
        print('📊 Found student name: $name for ID: $studentId');
        return name ?? 'Nama tidak ditemukan';
      } else {
        print('📊 Student document not found for ID: $studentId');
        return 'Siswa tidak ditemukan';
      }
    } catch (e) {
      print('❌ Error getting student name: $e');
      return 'Error memuat nama';
    }
  }

  String _getGrade(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'E';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red.shade300;
      case 'E':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    // Safe extraction with null checks and proper type conversion
    final correctAnswers = result['correctAnswers'];
    final totalQuestionsData = result['totalQuestions'];
    final percentageData = result['percentage'];

    final score = correctAnswers is int
        ? correctAnswers
        : (correctAnswers is double ? correctAnswers.toInt() : 0);
    final totalQuestions = totalQuestionsData is int
        ? totalQuestionsData
        : (totalQuestionsData is double ? totalQuestionsData.toInt() : 1);
    final percentage = percentageData is double
        ? percentageData
        : (percentageData is int ? percentageData.toDouble() : 0.0);

    final grade = _getGrade(percentage);
    final studentId =
        result['studentId'] as String? ?? 'Student ID tidak tersedia';
    final studentName = studentNames[studentId] ?? studentId;
    final submittedAt = result['submittedAt'] as Timestamp?;
    final completedAt = submittedAt?.toDate() ?? DateTime.now();

    print(
      '📊 Building card for: score=$score, totalQuestions=$totalQuestions, percentage=$percentage, studentId=$studentId',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Grade Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getGradeColor(grade),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Student Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: $studentId',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selesai: ${_formatDate(completedAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

            // Score Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score/$totalQuestions',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: _getGradeColor(grade),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatsCard() {
    if (results.isEmpty) return const SizedBox();

    final totalStudents = results.length;
    final totalScore = results.fold<int>(0, (sum, result) {
      final correctAnswers = result['correctAnswers'];
      final score = correctAnswers is int
          ? correctAnswers
          : (correctAnswers is double ? correctAnswers.toInt() : 0);
      return sum + score;
    });
    final firstResult = results.first;
    final totalQuestionsData = firstResult['totalQuestions'];
    final totalQuestions = totalQuestionsData is int
        ? totalQuestionsData
        : (totalQuestionsData is double ? totalQuestionsData.toInt() : 1);
    final averageScore = totalScore / totalStudents;
    final averagePercentage = (averageScore / totalQuestions) * 100;

    // Calculate grade distribution
    final grades = {'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0};
    for (final result in results) {
      final percentageData = result['percentage'];
      final percentage = percentageData is double
          ? percentageData
          : (percentageData is int ? percentageData.toDouble() : 0.0);
      final grade = _getGrade(percentage);
      grades[grade] = (grades[grade] ?? 0) + 1;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Statistik Quiz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Siswa',
                    totalStudents.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Nilai Rata-rata',
                    '${averageScore.toStringAsFixed(1)}/$totalQuestions',
                    Icons.analytics,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Persentase',
                    '${averagePercentage.toStringAsFixed(1)}%',
                    Icons.percent,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text(
              'Distribusi Nilai',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: grades.entries
                  .map(
                    (entry) => Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getGradeColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil: ${widget.quiz.subject}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.quiz.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadResults,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : results.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_late,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada siswa yang mengerjakan quiz ini',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pull to refresh untuk memuat ulang data',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildStatsCard(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        try {
                          return _buildResultCard(results[index]);
                        } catch (e, stackTrace) {
                          print(
                            '❌ Error building result card at index $index: $e',
                          );
                          print('❌ Stack trace: $stackTrace');
                          print('❌ Result data: ${results[index]}');
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error menampilkan hasil: $e',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
