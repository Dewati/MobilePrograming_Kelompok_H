import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'register_screen.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'role_selection_screen.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = await provider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      final user = provider.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User tidak ditemukan, silakan login ulang.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate based on user role
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return user.role == UserRole.student
                ? const StudentDashboard()
                : const TeacherDashboard();
          },
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      print('🚀 Starting Google Sign-In flow...');

      // Use the complete Google Sign-In flow that authenticates with Firebase
      final success = await provider.loginWithGoogle();

      if (success && mounted) {
        final user = provider.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User tidak ditemukan, silakan login ulang.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        print('✅ Google Sign-In successful, navigating to dashboard...');
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return user.role == UserRole.student
                  ? const StudentDashboard()
                  : const TeacherDashboard();
            },
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                      child: child,
                    ),
                  );
                },
          ),
        );
      } else if (!success && mounted) {
        // Check if we need to show role selection for new user
        if (provider.errorMessage?.contains('role selection') == true) {
          // This means new user needs role selection
          final userData = await provider.initiateGoogleSignIn();
          if (userData != null && mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    RoleSelectionScreen(
                      userName: userData['userName'],
                      userEmail: userData['userEmail'],
                      profileImageUrl: userData['profileImageUrl'],
                      firebaseUid: userData['googleUser']?.id,
                    ),
                transitionDuration: const Duration(milliseconds: 800),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                          child: child,
                        ),
                      );
                    },
              ),
            );
          }
        } else if (provider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.blue.shade100, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Consumer<AppProvider>(
              builder: (context, provider, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),

                          // App Logo/Title
                          SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Hero(
                                    tag: 'app-logo',
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blue.withValues(
                                              alpha: 0.3,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.quiz,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'QuizMate',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  Text(
                                    'Platform Quiz Pembelajaran',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Login Form
                          SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              children: [
                                // Email Field
                                CustomTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  hint: 'Masukkan email Anda',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Email tidak valid';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Password Field
                                CustomTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hint: 'Masukkan password Anda',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password tidak boleh kosong';
                                    }
                                    if (value.length < 6) {
                                      return 'Password minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Error Message
                          if (provider.errorMessage != null)
                            SlideTransition(
                              position: _slideAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        provider.errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Login Button
                          SlideTransition(
                            position: _slideAnimation,
                            child: CustomButton(
                              text: 'Masuk',
                              onPressed: provider.isLoading ? null : _login,
                              isLoading: provider.isLoading,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Google Sign-In Button
                          SlideTransition(
                            position: _slideAnimation,
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : _loginWithGoogle,
                                icon: SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CustomPaint(
                                    painter: GoogleSvgLogoPainter(),
                                  ),
                                ),
                                label: const Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF3c4043),
                                    letterSpacing: 0.25,
                                  ),
                                ),
                                style:
                                    OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF3c4043),
                                      side: const BorderSide(
                                        color: Color(0xFFdadce0),
                                        width: 1,
                                      ),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      elevation: 0,
                                    ).copyWith(
                                      overlayColor:
                                          MaterialStateProperty.resolveWith<
                                            Color?
                                          >((Set<MaterialState> states) {
                                            if (states.contains(
                                              MaterialState.hovered,
                                            )) {
                                              return const Color(
                                                0xFF3c4043,
                                              ).withOpacity(0.04);
                                            }
                                            if (states.contains(
                                              MaterialState.pressed,
                                            )) {
                                              return const Color(
                                                0xFF3c4043,
                                              ).withOpacity(0.12);
                                            }
                                            return null;
                                          }),
                                    ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // OR Divider
                          SlideTransition(
                            position: _slideAnimation,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(color: Colors.grey.shade400),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'ATAU',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Register Link
                          SlideTransition(
                            position: _slideAnimation,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Belum punya akun? ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => const RegisterScreen(),
                                        transitionDuration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              return SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(1.0, 0.0),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              );
                                            },
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue.shade600,
                                  ),
                                  child: const Text(
                                    'Daftar di sini',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter berdasarkan SVG Google logo asli
class GoogleSvgLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Scale factor untuk menyesuaikan dari ukuran SVG (48x48) ke ukuran widget
    final scale = size.width / 48.0;

    canvas.save();
    canvas.scale(scale);

    // Warna sesuai SVG asli
    const yellowColor = Color(0xFFFFC107); // #FFC107
    const redColor = Color(0xFFFF3D00); // #FF3D00
    const greenColor = Color(0xFF4CAF50); // #4CAF50
    const blueColor = Color(0xFF1976D2); // #1976D2

    // Path 1: Yellow/Kuning (bagian atas kiri)
    paint.color = yellowColor;
    final yellowPath = Path();
    yellowPath.moveTo(43.611, 20.083);
    yellowPath.lineTo(42, 20.083);
    yellowPath.lineTo(42, 20);
    yellowPath.lineTo(24, 20);
    yellowPath.lineTo(24, 28);
    yellowPath.lineTo(35.303, 28);
    yellowPath.cubicTo(33.654, 32.657, 29.223, 36, 24, 36);
    yellowPath.cubicTo(17.373, 36, 12, 30.627, 12, 24);
    yellowPath.cubicTo(12, 17.373, 17.373, 12, 24, 12);
    yellowPath.cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039);
    yellowPath.lineTo(37.618, 9.382);
    yellowPath.cubicTo(34.046, 6.053, 29.268, 4, 24, 4);
    yellowPath.cubicTo(12.955, 4, 4, 12.955, 4, 24);
    yellowPath.cubicTo(4, 35.045, 12.955, 44, 24, 44);
    yellowPath.cubicTo(35.045, 44, 44, 35.045, 44, 24);
    yellowPath.cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083);
    yellowPath.close();
    canvas.drawPath(yellowPath, paint);

    // Path 2: Red/Merah (bagian kiri atas)
    paint.color = redColor;
    final redPath = Path();
    redPath.moveTo(6.306, 14.691);
    redPath.lineTo(12.877, 19.51);
    redPath.cubicTo(14.655, 15.108, 18.961, 12, 24, 12);
    redPath.cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039);
    redPath.lineTo(37.618, 9.382);
    redPath.cubicTo(34.046, 6.053, 29.268, 4, 24, 4);
    redPath.cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691);
    redPath.close();
    canvas.drawPath(redPath, paint);

    // Path 3: Green/Hijau (bagian bawah)
    paint.color = greenColor;
    final greenPath = Path();
    greenPath.moveTo(24, 44);
    greenPath.cubicTo(29.166, 44, 33.86, 42.023, 37.409, 38.808);
    greenPath.lineTo(31.219, 33.57);
    greenPath.cubicTo(29.211, 35.091, 26.715, 36, 24, 36);
    greenPath.cubicTo(18.798, 36, 14.381, 32.683, 12.717, 28.054);
    greenPath.lineTo(6.195, 33.079);
    greenPath.cubicTo(9.505, 39.556, 16.227, 44, 24, 44);
    greenPath.close();
    canvas.drawPath(greenPath, paint);

    // Path 4: Blue/Biru (bagian kanan)
    paint.color = blueColor;
    final bluePath = Path();
    bluePath.moveTo(43.611, 20.083);
    bluePath.lineTo(42, 20.083);
    bluePath.lineTo(42, 20);
    bluePath.lineTo(24, 20);
    bluePath.lineTo(24, 28);
    bluePath.lineTo(35.303, 28);
    bluePath.cubicTo(34.511, 30.237, 33.072, 32.166, 31.216, 33.571);
    bluePath.lineTo(31.219, 33.569);
    bluePath.lineTo(37.409, 38.807);
    bluePath.cubicTo(36.971, 39.205, 44, 34, 44, 24);
    bluePath.cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083);
    bluePath.close();
    canvas.drawPath(bluePath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
