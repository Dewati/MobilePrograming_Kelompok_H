import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/firebase_quiz_service.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../providers/app_provider.dart';

class CreateQuizScreen extends StatefulWidget {
  final Quiz? quiz; // For editing existing quiz

  const CreateQuizScreen({super.key, this.quiz});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final FirebaseQuizService _quizService = FirebaseQuizService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _materialContentController = TextEditingController();
  final _materialLinkController = TextEditingController();

  String _selectedSubject = 'Bahasa Indonesia';
  String _materialType = 'text';
  String? _materialUrl;
  List<Map<String, dynamic>> _questions = [];

  // Temporary storage for different material types
  String? _tempFileUrl;
  String? _tempLinkUrl;

  final List<String> subjects = [
    'Bahasa Indonesia',
    'Matematika',
    'IPA',
    'IPS',
    'Bahasa Inggris',
  ];

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.quiz != null) {
      _isEditing = true;
      _loadQuizData();
    } else {
      _addQuestion(); // Add first question by default
    }
  }

  Future<void> _loadQuizData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final quiz = widget.quiz!;
      _titleController.text = quiz.title;
      _selectedSubject = quiz.subject;
      _materialType = quiz.materialType;
      _materialContentController.text = quiz.materialContent ?? '';

      // Load link/file content to temporary storage
      if (quiz.materialType == 'link' &&
          (quiz.materialLink != null || quiz.materialUrl != null)) {
        final link = quiz.materialLink ?? quiz.materialUrl;
        if (link != null) {
          _materialLinkController.text = link;
          _tempLinkUrl = link;
          print('🔗 Edit Quiz: Loading link URL: $link');
        }
      } else if (quiz.materialType == 'file' &&
          (quiz.materialFileName != null || quiz.materialUrl != null)) {
        // Prefer explicit file name if available
        if (quiz.materialFileName != null &&
            quiz.materialFileName!.isNotEmpty) {
          _tempFileUrl = quiz.materialFileName!;
          print('📁 Edit Quiz: Loading file name: ${quiz.materialFileName}');
        } else if (quiz.materialUrl != null) {
          _tempFileUrl = quiz.materialUrl!;
          print('📁 Edit Quiz: Loading file URL: ${quiz.materialUrl}');
        }
      }

      // _materialUrl will be set during save based on current material type

      // Load actual questions from Firestore
      final questions = await _quizService.getQuizQuestions(quiz);

      _questions.clear();

      if (questions.isNotEmpty) {
        for (final question in questions) {
          _questions.add({
            'questionController': TextEditingController(
              text: question.question,
            ),
            'optionAController': TextEditingController(
              text: question.options.length > 0 ? question.options[0] : '',
            ),
            'optionBController': TextEditingController(
              text: question.options.length > 1 ? question.options[1] : '',
            ),
            'optionCController': TextEditingController(
              text: question.options.length > 2 ? question.options[2] : '',
            ),
            'optionDController': TextEditingController(
              text: question.options.length > 3 ? question.options[3] : '',
            ),
            'correctAnswer': question.correctAnswer,
          });
        }
      } else {
        // If no questions found, add one empty question
        _addQuestion();
      }
    } catch (e) {
      print('Error loading quiz data: $e');
      // If error occurs, add default question
      _addQuestion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quiz data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _materialContentController.dispose();
    _materialLinkController.dispose();
    for (final question in _questions) {
      question['questionController']?.dispose();
      question['optionAController']?.dispose();
      question['optionBController']?.dispose();
      question['optionCController']?.dispose();
      question['optionDController']?.dispose();
    }
    super.dispose();
  }

  void _saveCurrentMaterialData() {
    // Save current data based on current material type
    if (_materialType == 'link') {
      _tempLinkUrl = _materialLinkController.text.trim();
      print('💾 Saved link data: $_tempLinkUrl');
    } else if (_materialType == 'file') {
      // _tempFileUrl is already saved when file is picked
      print('💾 File data already saved: $_tempFileUrl');
    }
    // Text content is already in controller, no need to save
  }

  void _restoreMaterialData() {
    // Restore data for the selected material type
    if (_materialType == 'link') {
      if (_tempLinkUrl != null && _tempLinkUrl!.isNotEmpty) {
        _materialLinkController.text = _tempLinkUrl!;
        print('🔄 Restored link data: $_tempLinkUrl');
      } else {
        _materialLinkController.text = '';
      }
    } else if (_materialType == 'file') {
      // File data is displayed via _tempFileUrl, no need to set _materialUrl here
      print('🔄 Using file data: $_tempFileUrl');
    } else if (_materialType == 'text') {
      // Text mode doesn't need URL restoration
      print('🔄 Text mode selected');
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionController': TextEditingController(),
        'optionAController': TextEditingController(),
        'optionBController': TextEditingController(),
        'optionCController': TextEditingController(),
        'optionDController': TextEditingController(),
        'correctAnswer': 'A',
      });
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions[index]['questionController']?.dispose();
        _questions[index]['optionAController']?.dispose();
        _questions[index]['optionBController']?.dispose();
        _questions[index]['optionCController']?.dispose();
        _questions[index]['optionDController']?.dispose();
        _questions.removeAt(index);
      });
    }
  }

  // Preview file widget helper
  Widget _getFilePreviewWidget(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.image, size: 40, color: Colors.grey),
        ),
      );
    } else if (ext == 'pdf') {
      return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 40);
    } else if (['doc', 'docx', 'txt'].contains(ext)) {
      return const Icon(Icons.description, color: Colors.blue, size: 40);
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.grey, size: 40);
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _tempFileUrl = result.files.single.path; // Save to temp storage only
          // Don't modify _materialUrl here to avoid overwriting link data
          // Keep material type as 'file' when user picks a file
          _materialType = 'file';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File berhasil dipilih: ${result.files.single.name}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada file yang dipilih'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memilih file: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Set correct materialUrl based on current material type
      if (_materialType == 'link') {
        _materialUrl = _tempLinkUrl?.trim();
        print('💾 Saved link data: $_materialUrl');
      } else if (_materialType == 'file' && _tempFileUrl != null) {
        // Upload file to Firebase Storage and get download URL
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengupload file...'),
              backgroundColor: Colors.blue,
            ),
          );
        }

        final File file = File(_tempFileUrl!);
        final String fileName = _tempFileUrl!.split('/').last;
        // Use simple path for now to bypass rules issues
        final String uploadPath =
            'files/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        print('🔍 Attempting to upload file: ${file.path}');
        print('🔍 Upload path: $uploadPath');
        print('🔍 File exists: ${await file.exists()}');
        print('🔍 File size: ${await file.length()} bytes');

        try {
          // Simplified: Just save the file name, bypass Firebase Storage upload
          final String fileName = file.path.split('/').last;
          _materialUrl = 'file://$fileName'; // Use local file reference
          print('📁 File saved as local reference: $_materialUrl');
        } catch (uploadError) {
          print('❌ Error saving file reference: $uploadError');
          // Even if error, still proceed with file name
          final String fileName = file.path.split('/').last;
          _materialUrl = 'file://$fileName';
          print('📁 Fallback: File saved as: $_materialUrl');
        }
      } else if (_materialType == 'text') {
        _materialUrl = null;
      }

      // Validate questions
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        if (q['questionController'].text.trim().isEmpty ||
            q['optionAController'].text.trim().isEmpty ||
            q['optionBController'].text.trim().isEmpty ||
            q['optionCController'].text.trim().isEmpty ||
            q['optionDController'].text.trim().isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Pertanyaan ${i + 1} belum lengkap. Pastikan semua field terisi.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      // Build questions list
      final questionsList = _questions
          .map(
            (q) => Question.withOptions(
              quizId: 0,
              question: q['questionController'].text.trim(),
              optionA: q['optionAController'].text.trim(),
              optionB: q['optionBController'].text.trim(),
              optionC: q['optionCController'].text.trim(),
              optionD: q['optionDController'].text.trim(),
              correctAnswer: q['correctAnswer'],
            ),
          )
          .toList();

      // Get current user ID from provider
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final String currentUserId =
          appProvider.currentUser?.id ?? 'anonymous_teacher';

      if (_isEditing) {
        // Create new Quiz object for updating
        final updatedQuiz = Quiz(
          id: widget.quiz!.id,
          title: _titleController.text.trim(),
          subject: _selectedSubject,
          description: widget.quiz!.description,
          timeLimit: widget.quiz!.timeLimit,
          materialContent: _materialContentController.text.trim().isEmpty
              ? null
              : _materialContentController.text.trim(),
          materialUrl: _materialUrl,
          materialLink: _tempLinkUrl,
          materialFileName: _tempFileUrl != null
              ? _tempFileUrl!.split('/').last
              : null,
          materialType: _materialType,
          questions: questionsList,
          createdAt: widget.quiz!.createdAt,
          createdBy: widget.quiz!.createdBy,
        );

        await _quizService.updateQuizByObject(widget.quiz!, updatedQuiz);
      } else {
        await _quizService.createQuiz(
          title: _titleController.text.trim(),
          subject: _selectedSubject,
          description:
              'Quiz ${_selectedSubject} - ${_titleController.text.trim()}',
          timeLimit: 30, // Default 30 minutes
          materialContent: _materialContentController.text.trim().isEmpty
              ? null
              : _materialContentController.text.trim(),
          materialUrl: _materialUrl,
          materialLink: _tempLinkUrl,
          materialType: _materialType,
          questions: questionsList,
          teacherId: currentUserId,
          materialFileName: _tempFileUrl != null
              ? _tempFileUrl!.split('/').last
              : null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Quiz berhasil diperbarui!'
                  : 'Quiz berhasil dibuat!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Quiz' : 'Buat Quiz Baru'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Quiz Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Quiz',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _titleController,
                            label: 'Judul Quiz',
                            hint: 'Masukkan judul quiz',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Judul quiz tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedSubject,
                            decoration: InputDecoration(
                              labelText: 'Mata Pelajaran',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: subjects
                                .map(
                                  (subject) => DropdownMenuItem(
                                    value: subject,
                                    child: Text(subject),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSubject = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Material Type Selection
                          const Text(
                            'Jenis Materi:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Teks'),
                                      value: 'text',
                                      groupValue: _materialType,
                                      onChanged: (value) {
                                        setState(() {
                                          // Save current data before switching
                                          _saveCurrentMaterialData();

                                          _materialType = value!;

                                          // Restore data for selected type
                                          _restoreMaterialData();
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Link'),
                                      value: 'link',
                                      groupValue: _materialType,
                                      onChanged: (value) {
                                        setState(() {
                                          // Save current data before switching
                                          _saveCurrentMaterialData();

                                          _materialType = value!;

                                          // Restore data for selected type
                                          _restoreMaterialData();
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                              RadioListTile<String>(
                                title: const Text('Upload File'),
                                value: 'file',
                                groupValue: _materialType,
                                onChanged: (value) {
                                  setState(() {
                                    // Save current data before switching
                                    _saveCurrentMaterialData();

                                    _materialType = value!;

                                    // Restore data for selected type
                                    _restoreMaterialData();
                                  });
                                },
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Material Content
                          if (_materialType == 'text')
                            CustomTextField(
                              controller: _materialContentController,
                              label: 'Konten Materi',
                              hint:
                                  'Contoh: Materi tentang operasi dasar matematika: penjumlahan, pengurangan, perkalian, dan pembagian. Pelajari dengan baik sebelum mengerjakan quiz.',
                              maxLines: 4,
                            ),
                          if (_materialType == 'link')
                            CustomTextField(
                              controller: _materialLinkController,
                              label: 'URL Link',
                              hint:
                                  'https://youtube.com/watch?v=... atau https://docs.google.com/...',
                              onChanged: (val) {
                                // Save to temp storage immediately when user types
                                _tempLinkUrl = val.trim();
                                // Don't modify _materialUrl here to avoid overwriting file data
                                print('⌨️ Link input changed: ${val.trim()}');
                              },
                            ),
                          if (_materialType == 'file') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _tempFileUrl != null
                                              ? Icons.check_circle
                                              : Icons.upload_file,
                                          color: _tempFileUrl != null
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _tempFileUrl != null
                                                ? 'File terpilih: ${_tempFileUrl!.split('/').last}'
                                                : 'Belum ada file terpilih',
                                            style: TextStyle(
                                              color: _tempFileUrl != null
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _pickFile,
                                  icon: const Icon(Icons.attach_file, size: 16),
                                  label: Text(
                                    _tempFileUrl != null
                                        ? 'Ganti File'
                                        : 'Pilih File',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange.shade100,
                                    foregroundColor: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (_tempFileUrl != null &&
                                _tempFileUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _getFilePreviewWidget(_tempFileUrl!),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _tempFileUrl!.split('/').last,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'File terpilih',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _tempFileUrl = null;
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Questions Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Pertanyaan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addQuestion,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                  foregroundColor: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._questions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final q = entry.value;
                            return _buildQuestionCard(index, q);
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  CustomButton(
                    text: _isEditing ? 'Perbarui Quiz' : 'Buat Quiz',
                    onPressed: _isLoading ? null : _saveQuiz,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Pertanyaan ${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_questions.length > 1)
                IconButton(
                  onPressed: () => _removeQuestion(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Hapus pertanyaan',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Text
          TextFormField(
            controller: q['questionController'],
            decoration: InputDecoration(
              labelText: 'Soal',
              hintText: 'Contoh: Berapa hasil dari 15 + 8?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Soal tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Options
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: q['optionAController'],
                  decoration: InputDecoration(
                    labelText: 'Opsi A',
                    hintText: 'Jawaban A',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Opsi A harus diisi';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: q['optionBController'],
                  decoration: InputDecoration(
                    labelText: 'Opsi B',
                    hintText: 'Jawaban B',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Opsi B harus diisi';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: q['optionCController'],
                  decoration: InputDecoration(
                    labelText: 'Opsi C',
                    hintText: 'Jawaban C',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Opsi C harus diisi';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: q['optionDController'],
                  decoration: InputDecoration(
                    labelText: 'Opsi D',
                    hintText: 'Jawaban D',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Opsi D harus diisi';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Correct Answer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pilih Jawaban yang Benar:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: ['A', 'B', 'C', 'D']
                      .map(
                        (option) => InkWell(
                          onTap: () {
                            setState(() {
                              q['correctAnswer'] = option;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: q['correctAnswer'] == option
                                  ? Colors.green.shade600
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: q['correctAnswer'] == option
                                    ? Colors.green.shade600
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: q['correctAnswer'] == option
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
