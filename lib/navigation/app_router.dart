import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 📱 Screens Imports
import 'package:exambeing/features/home/main_screen.dart';
import 'package:exambeing/features/home/home_screen.dart';
import 'package:exambeing/features/auth/screens/login_hub_screen.dart';
import 'package:exambeing/features/auth/screens/otp_screen.dart';
import 'package:exambeing/features/practice/screens/test_series_screen.dart';
import 'package:exambeing/features/practice/screens/subjects_screen.dart';
import 'package:exambeing/features/practice/screens/topics_screen.dart';
import 'package:exambeing/features/practice/screens/sets_screen.dart';
import 'package:exambeing/features/practice/screens/practice_mcq_screen.dart';
import 'package:exambeing/features/practice/screens/score_screen.dart';
import 'package:exambeing/features/bookmarks/screens/bookmarks_home_screen.dart';
import 'package:exambeing/features/practice/screens/solutions_screen.dart';
import 'package:exambeing/features/notes/screens/my_notes_screen.dart';
import 'package:exambeing/features/notes/screens/add_edit_note_screen.dart';
import 'package:exambeing/features/notes/screens/public_notes_screen.dart';
import 'package:exambeing/features/schedule/screens/schedules_screen.dart';
import 'package:exambeing/features/bookmarks/screens/bookmarked_question_detail_screen.dart';
import 'package:exambeing/features/bookmarks/screens/bookmarked_note_detail_screen.dart';
import 'package:exambeing/features/profile/screens/profile_screen.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/helpers/database_helper.dart';
import 'package:exambeing/features/profile/screens/settings_screen.dart';

// ⬇️===== NAYE IMPORTS (Tools Ke Liye) =====⬇️
import 'package:exambeing/features/tools/screens/pomodoro_screen.dart';
import 'package:exambeing/features/tools/screens/todo_list_screen.dart';
// ⬆️=======================================⬆️


/// 🚨 Safe Error Screen for bad route data
class _ErrorRouteScreen extends StatelessWidget {
  final String path;
  const _ErrorRouteScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Routing Error: Invalid or missing data for route "$path".\nPlease go back and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// 🔥 Main Router Config
final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/',

  routes: [
    // 🔐 Auth Routes
    GoRoute(
      path: '/login-hub',
      builder: (context, state) => const LoginHubScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        if (state.extra is String) {
          final verificationId = state.extra as String;
          return OtpScreen(verificationId: verificationId);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),

    // 🏠 Shell Route with Bottom Navigation
    ShellRoute(
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/test-series', builder: (context, state) => const TestSeriesScreen()),
        GoRoute(path: '/bookmarks_home', builder: (context, state) => const BookmarksHomeScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      ],
    ),

    // 🧠 Practice Routes
    GoRoute(
      path: '/subjects',
      builder: (context, state) {
        if (state.extra is Map<String, String>) {
          final seriesData = state.extra as Map<String, String>;
          return SubjectsScreen(seriesData: seriesData);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/topics',
      builder: (context, state) {
        if (state.extra is Map<String, String>) {
          final subjectData = state.extra as Map<String, String>;
          return TopicsScreen(subjectData: subjectData);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/sets',
      builder: (context, state) {
        if (state.extra is Map<String, String>) {
          final topicData = state.extra as Map<String, String>;
          return SetsScreen(topicData: topicData);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/practice-mcq',
      builder: (context, state) {
        if (state.extra is Map<String, dynamic>) {
          final quizData = state.extra as Map<String, dynamic>;
          return PracticeMcqScreen(quizData: quizData);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),

    // 🏁 Score & Solutions
    GoRoute(
      path: '/score',
      builder: (context, state) {
        final data = state.extra;
        if (data is Map<String, dynamic> &&
            data.containsKey('totalQuestions') &&
            data.containsKey('finalScore') &&
            data.containsKey('correctCount') &&
            data.containsKey('wrongCount') &&
            data.containsKey('unattemptedCount') &&
            data.containsKey('topicName') &&
            data.containsKey('questions') &&
            data.containsKey('userAnswers')) {
          try {
            return ScoreScreen(
              totalQuestions: data['totalQuestions'] as int,
              finalScore: data['finalScore'] as double,
              correctCount: data['correctCount'] as int,
              wrongCount: data['wrongCount'] as int,
              unattemptedCount: data['unattemptedCount'] as int,
              topicName: data['topicName'] as String,
              questions: data['questions'] as List<Question>,
              userAnswers: data['userAnswers'] as Map<int, String>,
            );
          } catch (e) {
            return _ErrorRouteScreen(path: state.matchedLocation);
          }
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/solutions',
      builder: (context, state) {
        final data = state.extra;
        if (data is Map<String, dynamic> &&
            data.containsKey('questions') &&
            data.containsKey('userAnswers')) {
          try {
            return SolutionsScreen(
              questions: data['questions'] as List<Question>,
              userAnswers: data['userAnswers'] as Map<int, String>,
            );
          } catch (e) {
            return _ErrorRouteScreen(path: state.matchedLocation);
          }
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),

    // 📒 Notes
    GoRoute(path: '/my-notes', builder: (context, state) => const MyNotesScreen()),
    GoRoute(
      path: '/add-edit-note',
      builder: (context, state) {
        final MyNote? note = state.extra as MyNote?;
        return AddEditNoteScreen(note: note);
      },
    ),
    GoRoute(path: '/public-notes', builder: (context, state) => const PublicNotesScreen()),

    // 📅 Schedules
    GoRoute(path: '/schedules', builder: (context, state) => const SchedulesScreen()),

    // 📘 Bookmarks
    GoRoute(
      path: '/bookmark-question-detail',
      builder: (context, state) {
        if (state.extra is Question) {
          final question = state.extra as Question;
          return BookmarkedQuestionDetailScreen(question: question);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/bookmark-note-detail',
      builder: (context, state) {
        if (state.extra is PublicNote) {
          final note = state.extra as PublicNote;
          return BookmarkedNoteDetailScreen(note: note);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),

    // ⚙️ Settings
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),

    // ⬇️===== NAYE ROUTES (Tools Ke Liye) =====⬇️
    GoRoute(
      path: '/pomodoro',
      builder: (context, state) => const PomodoroScreen(),
    ),
    GoRoute(
      path: '/todo-list',
      builder: (context, state) => const TodoListScreen(),
    ),
    // ⬆️======================================⬆️

  ], // <-- routes ki list yahaan band hoti hai

  /// 🧠 Redirect Logic (fixed)
  redirect: (BuildContext context, GoRouterState state) {
    // Firebase initialization check
    if (Firebase.apps.isEmpty) return null;

    final user = FirebaseAuth.instance.currentUser;
    final loggingIn = state.matchedLocation == '/login-hub' || state.matchedLocation == '/otp';

    if (user == null) {
      return loggingIn ? null : '/login-hub';
    }

    if (loggingIn) {
      return '/';
    }

    return null;
  },
);

/// 🔁 Helper class to auto-refresh GoRouter on auth state change
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription =
        stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
