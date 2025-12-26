import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_quiz_service.dart';
import '../providers/app_provider.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../widgets/custom_button.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final FirebaseQuizService _quizService = FirebaseQuizService();
  List<Question> questions = [];
  Map<int, String> answers = {};
  int currentQuestionIndex = 0;
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      // Questions are already in the quiz object
      questions = widget.quiz.questions;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: ${e.toString()}')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      answers[currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    // Check if all questions are answered
    if (answers.length < questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap jawab semua pertanyaan')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final studentId = provider.currentUser?.uid ?? '';

      if (studentId.isEmpty) {
        throw Exception('Student ID is required but user not logged in');
      }

      // Use a simple approach - submit quiz with Quiz object directly
      print('🚀 Submitting quiz: ${widget.quiz.title}');

      final result = await _quizService.submitQuizAttemptWithQuiz(
        quiz: widget.quiz,
        studentId: studentId,
        answers: answers,
        startTime: DateTime.now().subtract(
          Duration(minutes: widget.quiz.timeLimit),
        ),
        endTime: DateTime.now(),
      );

      print('✅ Quiz submission result: $result');

      // Parse score from result string
      final score = int.tryParse(result.split('/')[0]) ?? 0;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Quiz Selesai!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Skor Anda: $score/${questions.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Persentase: ${(score / questions.length * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                child: const Text('Kembali ke Dashboard'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Tidak ada pertanyaan dalam quiz ini')),
      );
    }

    final question = questions[currentQuestionIndex];
    final selectedAnswer = answers[currentQuestionIndex];

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(widget.quiz.title),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pertanyaan ${currentQuestionIndex + 1} dari ${questions.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${answers.length}/${questions.length} dijawab',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / questions.length,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    Expanded(
                      child: Column(
                        children: [
                          _buildOption(
                            'A',
                            question.options[0],
                            selectedAnswer,
                          ),
                          const SizedBox(height: 12),
                          _buildOption(
                            'B',
                            question.options[1],
                            selectedAnswer,
                          ),
                          const SizedBox(height: 12),
                          _buildOption(
                            'C',
                            question.options[2],
                            selectedAnswer,
                          ),
                          const SizedBox(height: 12),
                          _buildOption(
                            'D',
                            question.options[3],
                            selectedAnswer,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Navigation buttons
            Row(
              children: [
                if (currentQuestionIndex > 0)
                  Expanded(
                    child: CustomButton(
                      text: 'Sebelumnya',
                      onPressed: _previousQuestion,
                      backgroundColor: Colors.grey.shade600,
                    ),
                  ),
                if (currentQuestionIndex > 0) const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: currentQuestionIndex < questions.length - 1
                        ? 'Selanjutnya'
                        : 'Selesai',
                    onPressed: currentQuestionIndex < questions.length - 1
                        ? _nextQuestion
                        : _submitQuiz,
                    isLoading: isSubmitting,
                    backgroundColor: currentQuestionIndex < questions.length - 1
                        ? Colors.blue.shade600
                        : Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(String letter, String text, String? selectedAnswer) {
    final isSelected = selectedAnswer == letter;

    return GestureDetector(
      onTap: () => _selectAnswer(letter),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected
                      ? Colors.blue.shade800
                      : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
