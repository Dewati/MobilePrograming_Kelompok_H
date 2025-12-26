import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/quiz.dart';
import '../services/quiz_service.dart';
import '../providers/app_provider.dart';
import '../widgets/custom_button.dart';

class QuizTakingScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizTakingScreen({super.key, required this.quiz});

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  final QuizService _quizService = QuizService();

  int _currentQuestionIndex = 0;
  Map<int, String> _selectedAnswers = {};
  Timer? _timer;
  int _remainingSeconds = 0;
  DateTime? _startTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _remainingSeconds =
        widget.quiz.timeLimit * 60; // Convert minutes to seconds
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _submitQuiz(); // Auto submit when time's up
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentQuestionIndex = index;
    });
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final currentUser = appProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Submit quiz attempt to Firebase
      final attemptId = await _quizService.submitQuizAttempt(
        quizId: widget.quiz.id?.toString() ?? '0',
        studentId: currentUser.id ?? 'anonymous',
        answers: _selectedAnswers,
        startTime: _startTime!,
        endTime: DateTime.now(),
      );

      if (mounted) {
        // Calculate score for immediate feedback
        int correctAnswers = 0;
        for (int i = 0; i < widget.quiz.questions.length; i++) {
          final userAnswer = _selectedAnswers[i];
          final correctAnswer = widget.quiz.questions[i].correctAnswer;

          if (userAnswer == correctAnswer) {
            correctAnswers++;
          }
        }

        final score = correctAnswers;
        final totalQuestions = widget.quiz.questions.length;
        final percentage = (score / totalQuestions * 100).round();

        // Navigate to results screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultScreen(
              quiz: widget.quiz,
              score: score,
              totalQuestions: totalQuestions,
              percentage: percentage,
              attemptId: attemptId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quiz: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.quiz.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog before leaving
        return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Keluar dari Quiz?'),
                content: const Text(
                  'Jika Anda keluar sekarang, jawaban Anda tidak akan disimpan. Apakah Anda yakin?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      child: Scaffold(
        backgroundColor: Colors.blue.shade50,
        appBar: AppBar(
          title: Text(widget.quiz.title),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    color: _remainingSeconds < 300 ? Colors.red : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds < 300
                          ? Colors.red
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Progress Bar
            Container(
              height: 8,
              margin: const EdgeInsets.all(16),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
              ),
            ),

            // Question Counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pertanyaan ${_currentQuestionIndex + 1} dari ${widget.quiz.questions.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showQuestionNavigator(context),
                    icon: const Icon(Icons.list),
                    label: const Text('Navigasi'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Question Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        currentQuestion.question,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Answer Options
                    ...currentQuestion.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final optionLetter = String.fromCharCode(
                        65 + index,
                      ); // A, B, C, D
                      final isSelected =
                          _selectedAnswers[_currentQuestionIndex] ==
                          optionLetter;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _selectAnswer(optionLetter),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade100
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.shade600
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade400,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      optionLetter,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentQuestionIndex > 0)
                    Expanded(
                      child: CustomButton(
                        text: 'Sebelumnya',
                        onPressed: _previousQuestion,
                        backgroundColor: Colors.grey.shade600,
                        icon: Icons.arrow_back,
                      ),
                    ),

                  if (_currentQuestionIndex > 0 &&
                      _currentQuestionIndex < widget.quiz.questions.length - 1)
                    const SizedBox(width: 16),

                  if (_currentQuestionIndex < widget.quiz.questions.length - 1)
                    Expanded(
                      child: CustomButton(
                        text: 'Selanjutnya',
                        onPressed: _nextQuestion,
                        icon: Icons.arrow_forward,
                      ),
                    ),

                  if (_currentQuestionIndex == widget.quiz.questions.length - 1)
                    Expanded(
                      child: CustomButton(
                        text: _isSubmitting ? 'Mengirim...' : 'Selesai',
                        onPressed: _isSubmitting ? null : _submitQuiz,
                        backgroundColor: Colors.green,
                        icon: _isSubmitting ? null : Icons.check,
                        isLoading: _isSubmitting,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionNavigator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Navigasi Pertanyaan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.quiz.questions.length,
              itemBuilder: (context, index) {
                final isAnswered = _selectedAnswers.containsKey(index);
                final isCurrent = index == _currentQuestionIndex;

                return InkWell(
                  onTap: () {
                    _goToQuestion(index);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.blue.shade600
                          : isAnswered
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.blue.shade600
                            : isAnswered
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white
                              : isAnswered
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildLegendItem(Colors.blue.shade600, 'Saat ini'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.green.shade600, 'Terjawab'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.grey.shade400, 'Belum dijawab'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// Quiz Result Screen
class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final int score;
  final int totalQuestions;
  final int percentage;
  final String attemptId;

  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.attemptId,
  });

  @override
  Widget build(BuildContext context) {
    final passed = percentage >= 60;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Hasil Quiz'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Result Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: passed ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        passed ? Icons.check : Icons.close,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Result Title
                    Text(
                      passed ? 'Selamat!' : 'Belum Berhasil',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: passed ? Colors.green : Colors.red,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Score Details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$score / $totalQuestions',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: passed ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Jawaban Benar',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Result Message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: passed
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: passed
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        passed
                            ? 'Anda telah berhasil menyelesaikan quiz ini dengan nilai yang memuaskan!'
                            : 'Jangan menyerah! Pelajari materi lagi dan coba lakukan quiz sekali lagi.',
                        style: TextStyle(
                          fontSize: 16,
                          color: passed
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Column(
              children: [
                CustomButton(
                  text: 'Kembali ke Dashboard',
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: Icons.home,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Lihat Detail Jawaban',
                  onPressed: () {
                    // TODO: Navigate to detailed answer review
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Fitur review jawaban akan segera tersedia',
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.grey.shade600,
                  icon: Icons.visibility,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
