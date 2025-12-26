import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';
import '../providers/app_provider.dart';
import '../widgets/custom_button.dart';
import 'quiz_taking_screen.dart';

class QuizListScreen extends StatefulWidget {
  const QuizListScreen({super.key});

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  final QuizService _quizService = QuizService();
  String _selectedSubject = 'Semua';

  final List<String> subjects = [
    'Semua',
    'Bahasa Indonesia',
    'Matematika',
    'IPA',
    'IPS',
    'Bahasa Inggris',
  ];

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isTeacher = appProvider.currentUser?.role.name == 'teacher';

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Quiz Tersedia'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (isTeacher)
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-quiz');
              },
              icon: const Icon(Icons.add),
              tooltip: 'Buat Quiz Baru',
            ),
        ],
      ),
      body: Column(
        children: [
          // Subject Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Mata Pelajaran:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final isSelected = subject == _selectedSubject;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(subject),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedSubject = subject;
                            });
                          },
                          selectedColor: Colors.blue.shade100,
                          backgroundColor: Colors.grey.shade100,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Quiz List
          Expanded(
            child: StreamBuilder<List<Quiz>>(
              stream: _quizService.getAvailableQuizzes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Coba Lagi',
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                }

                final allQuizzes = snapshot.data ?? [];
                final filteredQuizzes = _selectedSubject == 'Semua'
                    ? allQuizzes
                    : allQuizzes
                          .where((quiz) => quiz.subject == _selectedSubject)
                          .toList();

                if (filteredQuizzes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.quiz_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedSubject == 'Semua'
                              ? 'Belum ada quiz tersedia'
                              : 'Belum ada quiz untuk $_selectedSubject',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (isTeacher) ...[
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Buat Quiz Pertama',
                            onPressed: () {
                              Navigator.pushNamed(context, '/create-quiz');
                            },
                            icon: Icons.add,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredQuizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = filteredQuizzes[index];
                      return QuizCard(
                        quiz: quiz,
                        isTeacher: isTeacher,
                        onTake: () => _takeQuiz(quiz),
                        onEdit: isTeacher ? () => _editQuiz(quiz) : null,
                        onDelete: isTeacher ? () => _deleteQuiz(quiz) : null,
                        onViewResults: isTeacher
                            ? () => _viewResults(quiz)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _takeQuiz(Quiz quiz) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (appProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mulai Quiz: ${quiz.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mata Pelajaran: ${quiz.subject}'),
            Text('Jumlah Pertanyaan: ${quiz.questions.length}'),
            Text('Waktu: ${quiz.timeLimit} menit'),
            const SizedBox(height: 16),
            const Text(
              'Pastikan Anda siap sebelum memulai quiz. Timer akan berjalan setelah Anda memulai.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          CustomButton(
            text: 'Mulai Quiz',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QuizTakingScreen(quiz: quiz)),
      );
    }
  }

  void _editQuiz(Quiz quiz) {
    Navigator.pushNamed(context, '/create-quiz', arguments: quiz);
  }

  void _deleteQuiz(Quiz quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Quiz'),
        content: Text(
          'Apakah Anda yakin ingin menghapus quiz "${quiz.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _quizService.deleteQuizByObject(quiz);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quiz berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewResults(Quiz quiz) {
    // TODO: Navigate to quiz results screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur lihat hasil akan segera tersedia')),
    );
  }
}

class QuizCard extends StatelessWidget {
  final Quiz quiz;
  final bool isTeacher;
  final VoidCallback onTake;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onViewResults;

  const QuizCard({
    super.key,
    required this.quiz,
    required this.isTeacher,
    required this.onTake,
    this.onEdit,
    this.onDelete,
    this.onViewResults,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSubjectColor(quiz.subject),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          quiz.subject,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTeacher)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'results':
                          onViewResults?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'results',
                        child: Row(
                          children: [
                            Icon(Icons.assessment),
                            SizedBox(width: 8),
                            Text('Lihat Hasil'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            if (quiz.description.isNotEmpty) ...[
              Text(
                quiz.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

            // Quiz Info
            Row(
              children: [
                _buildInfoItem(Icons.quiz, '${quiz.questions.length} soal'),
                const SizedBox(width: 16),
                _buildInfoItem(Icons.timer, '${quiz.timeLimit} menit'),
                const SizedBox(width: 16),
                _buildInfoItem(
                  Icons.calendar_today,
                  _formatDate(quiz.createdAt),
                ),
              ],
            ),

            // Material Info
            if (quiz.materialUrl != null ||
                (quiz.materialContent?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getMaterialIcon(quiz.materialType),
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Materi tersedia',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: isTeacher ? 'Kelola Quiz' : 'Mulai Quiz',
                onPressed: isTeacher ? (onEdit ?? () {}) : onTake,
                icon: isTeacher ? Icons.settings : Icons.play_arrow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Bahasa Indonesia':
        return Colors.red.shade400;
      case 'Matematika':
        return Colors.blue.shade400;
      case 'IPA':
        return Colors.green.shade400;
      case 'IPS':
        return Colors.orange.shade400;
      case 'Bahasa Inggris':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  IconData _getMaterialIcon(String materialType) {
    switch (materialType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'file':
        return Icons.attach_file;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hari ini';
    } else if (difference.inDays == 1) {
      return 'Kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
