import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/firebase_quiz_service.dart';
import '../providers/app_provider.dart';
import '../models/quiz.dart';
import '../models/quiz_result.dart';
import 'quiz_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final FirebaseQuizService _firebaseQuizService = FirebaseQuizService();
  final List<String> subjects = [
    'Bahasa Indonesia',
    'Matematika',
    'IPA',
    'IPS',
    'Bahasa Inggris',
  ];

  String selectedSubject = 'Semua';
  List<Quiz> quizzes = [];
  Map<int, QuizResult?> quizResults = {};
  List<Map<String, dynamic>> userAttempts = [];
  bool isLoading = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
    _startAutoRefresh();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  void _startAutoRefresh() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) {
        _loadData(showLoading: false);
        return true;
      }
      return false;
    });
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final user = provider.currentUser;

      if (user == null || user.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User tidak ditemukan, silakan login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }

      // Ambil quiz dari service
      if (selectedSubject == 'Semua') {
        quizzes = await _firebaseQuizService.getAllQuizzes();
      } else {
        quizzes = await _firebaseQuizService.getQuizzesBySubject(
          selectedSubject,
        );
      }

      // Load quiz results for current user
      quizResults.clear();
      userAttempts.clear();

      // Load user's quiz attempts
      await _loadUserAttempts(user.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserAttempts(String userId) async {
    try {
      // Get quiz attempts stream and convert to list
      final stream = _firebaseQuizService.getStudentAttempts(userId);
      final snapshot = await stream.first;

      setState(() {
        userAttempts = snapshot;
      });

      print('📊 Loaded ${userAttempts.length} quiz attempts for user $userId');
    } catch (e) {
      print('❌ Error loading user attempts: $e');
    }
  }

  bool _isQuizCompleted(Quiz quiz) {
    final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
        .hashCode
        .abs()
        .toString();

    return userAttempts.any(
      (attempt) =>
          attempt['quizIdentifier'] == quizIdentifier ||
          (attempt['quizTitle'] == quiz.title &&
              attempt['quizSubject'] == quiz.subject),
    );
  }

  Map<String, dynamic>? _getQuizAttempt(Quiz quiz) {
    final quizIdentifier = '${quiz.title}_${quiz.subject}_${quiz.createdBy}'
        .hashCode
        .abs()
        .toString();

    try {
      return userAttempts.firstWhere(
        (attempt) =>
            attempt['quizIdentifier'] == quizIdentifier ||
            (attempt['quizTitle'] == quiz.title &&
                attempt['quizSubject'] == quiz.subject),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _showMaterial(Quiz quiz) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.book, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Materi: ${quiz.title}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quiz.materialContent != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konten Materi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quiz.materialContent!,
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Display file material
              if ((quiz.materialFileName != null &&
                      quiz.materialFileName!.isNotEmpty) ||
                  (quiz.materialUrl != null &&
                      quiz.materialType == 'file')) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Materi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          // If we have an explicit file name (teacher selected file)
                          if (quiz.materialFileName != null &&
                              quiz.materialFileName!.isNotEmpty) {
                            _showFileInfo('file://${quiz.materialFileName}');
                            return;
                          }

                          if (quiz.materialUrl != null) {
                            if (quiz.materialUrl!.startsWith('http')) {
                              _launchUrl(quiz.materialUrl!);
                            } else if (quiz.materialUrl!.startsWith('data:')) {
                              _downloadDataUrl(quiz.materialUrl!);
                            } else if (quiz.materialUrl!.startsWith(
                              'file://',
                            )) {
                              // Show file info dialog for local files
                              _showFileInfo(quiz.materialUrl!);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (quiz.materialUrl != null &&
                                    quiz.materialUrl!.startsWith('http'))
                                ? Colors.blue.shade100
                                : (quiz.materialUrl != null &&
                                      quiz.materialUrl!.startsWith('data:'))
                                ? Colors.green.shade100
                                : Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  (quiz.materialUrl != null &&
                                      quiz.materialUrl!.startsWith('http'))
                                  ? Colors.blue.shade300
                                  : (quiz.materialUrl != null &&
                                        quiz.materialUrl!.startsWith('data:'))
                                  ? Colors.green.shade300
                                  : Colors.purple.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (quiz.materialUrl != null &&
                                        quiz.materialUrl!.startsWith('http'))
                                    ? Icons.download
                                    : (quiz.materialUrl != null &&
                                          quiz.materialUrl!.startsWith('data:'))
                                    ? Icons.file_present
                                    : Icons.description,
                                size: 20,
                                color:
                                    (quiz.materialUrl != null &&
                                        quiz.materialUrl!.startsWith('http'))
                                    ? Colors.blue.shade700
                                    : (quiz.materialUrl != null &&
                                          quiz.materialUrl!.startsWith('data:'))
                                    ? Colors.green.shade700
                                    : Colors.purple.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quiz.materialFileName ??
                                          _getFileName(quiz.materialUrl ?? ''),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color:
                                            (quiz.materialUrl != null &&
                                                quiz.materialUrl!.startsWith(
                                                  'http',
                                                ))
                                            ? Colors.blue.shade700
                                            : (quiz.materialUrl != null &&
                                                  quiz.materialUrl!.startsWith(
                                                    'data:',
                                                  ))
                                            ? Colors.green.shade700
                                            : Colors.purple.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (quiz.materialUrl != null &&
                                              quiz.materialUrl!.startsWith(
                                                'http',
                                              ))
                                          ? 'Ketuk untuk download file'
                                          : (quiz.materialUrl != null &&
                                                quiz.materialUrl!.startsWith(
                                                  'data:',
                                                ))
                                          ? 'Ketuk untuk buka file'
                                          : 'Ketuk untuk info file',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            (quiz.materialUrl != null &&
                                                quiz.materialUrl!.startsWith(
                                                  'http',
                                                ))
                                            ? Colors.blue.shade600
                                            : (quiz.materialUrl != null &&
                                                  quiz.materialUrl!.startsWith(
                                                    'data:',
                                                  ))
                                            ? Colors.green.shade600
                                            : Colors.purple.shade600,
                                        fontStyle:
                                            (quiz.materialUrl != null &&
                                                (quiz.materialUrl!.startsWith(
                                                      'http',
                                                    ) ||
                                                    quiz.materialUrl!
                                                        .startsWith('data:')))
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (quiz.materialUrl != null &&
                                  quiz.materialUrl!.startsWith('http'))
                                Icon(
                                  Icons.open_in_new,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                )
                              else if (quiz.materialUrl != null &&
                                  quiz.materialUrl!.startsWith('data:'))
                                Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Colors.green.shade700,
                                )
                              else
                                Icon(
                                  Icons.info,
                                  size: 16,
                                  color: Colors.purple.shade700,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Display Link Material (always show if materialLink exists)
              if ((quiz.materialLink != null &&
                      quiz.materialLink!.isNotEmpty) ||
                  (quiz.materialUrl != null &&
                      quiz.materialType == 'link')) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link Materi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _launchUrl(
                          quiz.materialLink ?? quiz.materialUrl ?? '',
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  quiz.materialLink ?? quiz.materialUrl ?? '',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      // Normalize URL - add https:// if no scheme
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }

      print('🔗 Launching URL: $normalizedUrl');

      final uri = Uri.parse(normalizedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ URL launched successfully');
      } else {
        print('❌ Cannot launch URL: $normalizedUrl');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka link'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error launching URL: $e');
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

  String _getFileName(String path) {
    if (path.contains('/')) {
      return path.split('/').last;
    }
    return path;
  }

  Widget _buildQuizCard(Quiz quiz, int index) {
    final isCompleted = _isQuizCompleted(quiz);
    final attemptData = _getQuizAttempt(quiz);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.quiz,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          quiz.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted ? Icons.check_circle : Icons.pending,
                              size: 14,
                              color: isCompleted
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompleted ? 'Selesai' : 'Belum',
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.subject,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mata Pelajaran: ${quiz.subject}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (isCompleted) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.grade,
                            color: Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attemptData != null
                                  ? 'Nilai: ${attemptData['correctAnswers']}/${attemptData['totalQuestions']} (${(attemptData['percentage'] as double).toStringAsFixed(1)}%)'
                                  : 'Nilai: -/-',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMaterial(quiz),
                          icon: const Icon(Icons.book, size: 16),
                          label: const Text('Lihat Materi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isCompleted
                              ? null
                              : () => _startQuiz(quiz),
                          icon: Icon(
                            isCompleted ? Icons.check : Icons.play_arrow,
                            size: 16,
                          ),
                          label: Text(
                            isCompleted ? 'Sudah Selesai' : 'Kerjakan Quiz',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompleted
                                ? Colors.grey.shade200
                                : Colors.green.shade100,
                            foregroundColor: isCompleted
                                ? Colors.grey.shade500
                                : Colors.green.shade700,
                            elevation: isCompleted ? 0 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startQuiz(Quiz quiz) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuizScreen(quiz: quiz),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    ).then((_) => _loadData()); // Reload data after quiz completion
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text(
          'Dashboard Siswa',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<AppProvider>(
            builder: (context, appProvider, child) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await appProvider.logout();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } else if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person),
                        const SizedBox(width: 8),
                        Text(appProvider.user?.name ?? 'Student'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // Subject Filter
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubjectChip('Semua'),
                  ...subjects.map((subject) => _buildSubjectChip(subject)),
                ],
              ),
            ),
          ),

          // Quiz List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadData(),
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Memuat quiz...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : quizzes.isEmpty
                  ? Center(
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
                            'Belum ada quiz tersedia',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tarik ke bawah untuk refresh',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: quizzes.length,
                      itemBuilder: (context, index) {
                        return _buildQuizCard(quizzes[index], index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(String subject) {
    final isSelected = selectedSubject == subject;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          subject,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedSubject = subject;
          });
          _loadData();
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue.shade600,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blue.shade300 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  // Handle data URL download/view
  Future<void> _downloadDataUrl(String dataUrl) async {
    try {
      print('📱 Attempting to open data URL file');

      // Extract file info from data URL
      final String header = dataUrl.split(',')[0];
      final String base64Data = dataUrl.split(',')[1];

      // Get MIME type
      final RegExp mimeRegex = RegExp(r'data:([^;]+)');
      final Match? mimeMatch = mimeRegex.firstMatch(header);
      final String mimeType = mimeMatch?.group(1) ?? 'application/octet-stream';

      print('📄 File MIME type: $mimeType');

      // Decode base64
      final Uint8List bytes = base64Decode(base64Data);
      print('📊 File size: ${bytes.length} bytes');

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();

      // Generate filename based on MIME type
      String extension = 'bin';
      if (mimeType.contains('pdf'))
        extension = 'pdf';
      else if (mimeType.contains('image/jpeg'))
        extension = 'jpg';
      else if (mimeType.contains('image/png'))
        extension = 'png';
      else if (mimeType.contains('msword'))
        extension = 'doc';
      else if (mimeType.contains('text/plain'))
        extension = 'txt';

      final String fileName =
          'material_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final File tempFile = File('${tempDir.path}/$fileName');

      // Write bytes to temporary file
      await tempFile.writeAsBytes(bytes);
      print('📁 Temporary file created: ${tempFile.path}');

      // For now, show a dialog with file info instead of trying to open
      _showDownloadedFileDialog(fileName, bytes.length, mimeType);
      print('✅ File info shown to user');
    } catch (e) {
      print('❌ Error opening data URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show file info dialog for local files
  Future<void> _showFileInfo(String fileUrl) async {
    final String fileName = fileUrl.replaceFirst('file://', '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.purple),
              SizedBox(width: 8),
              Text('Info File'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'File berhasil dipilih oleh guru:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, color: Colors.purple.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'File ini telah dipilih oleh guru sebagai materi pembelajaran. '
                'Guru dapat menampilkan atau mendiskusikan file ini saat pembelajaran.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show downloaded file dialog with file details
  Future<void> _showDownloadedFileDialog(
    String fileName,
    int fileSize,
    String mimeType,
  ) async {
    String formatFileSize(int bytes) {
      if (bytes < 1024) return '${bytes} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    String getFileTypeDisplay(String mimeType) {
      if (mimeType.contains('pdf')) return 'PDF Document';
      if (mimeType.contains('image')) return 'Image';
      if (mimeType.contains('msword')) return 'Word Document';
      if (mimeType.contains('text')) return 'Text File';
      return 'File';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_present, color: Colors.green),
              SizedBox(width: 8),
              Text('File Materi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Jenis: ${getFileTypeDisplay(mimeType)}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.storage,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ukuran: ${formatFileSize(fileSize)}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File berhasil dimuat dan tersimpan sebagai materi pembelajaran.',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
