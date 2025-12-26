import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'models/quiz.dart';
import 'screens/splash_screen.dart';
import 'screens/create_quiz_screen.dart';
import 'screens/quiz_list_screen.dart';
import 'screens/quiz_taking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
    } else {
      print('⚠️  Firebase already initialized');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    // Continue without Firebase for fallback mode
  }

  runApp(const QuizMateApp());
}

class QuizMateApp extends StatelessWidget {
  const QuizMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..initializeAuth(),
      child: MaterialApp(
        title: 'QuizMate',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/create-quiz': (context) => const CreateQuizScreen(),
          '/quiz-list': (context) => const QuizListScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/quiz-taking':
              final quiz = settings.arguments as Quiz?;
              if (quiz != null) {
                return MaterialPageRoute(
                  builder: (context) => QuizTakingScreen(quiz: quiz),
                );
              }
              break;
            case '/create-quiz':
              final quiz = settings.arguments as Quiz?;
              return MaterialPageRoute(
                builder: (context) => CreateQuizScreen(quiz: quiz),
              );
          }
          return null;
        },
      ),
    );
  }
}
