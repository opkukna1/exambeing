import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ... (Baaki imports same rahenge) ...
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
import 'package:exambeing/features/profile/screens/settings_screen.dart';
import 'package:exambeing/features/tools/screens/pomodoro_screen.dart';
import 'package:exambeing/features/tools/screens/todo_list_screen.dart';
import 'package:exambeing/features/tools/screens/timetable_screen.dart';
import 'package:exambeing/features/notes/screens/note_detail_screen.dart';
import 'package:exambeing/models/bookmarked_note_model.dart';

// ⬇️===== TEST SYSTEM IMPORTS =====⬇️
import 'package:exambeing/features/tests/daily_test_screen.dart';
import 'package:exambeing/features/tests/result_screen.dart';
import 'package:exambeing/features/tests/solution_screen.dart';
// Naya: Subject List
import 'package:exambeing/features/tests/subject_list_screen.dart'; 
import 'package:exambeing/features/tests/test_list_screen.dart';
import 'package:exambeing/features/tests/series_test_screen.dart';
// ⬆️=============================⬆️

class _ErrorRouteScreen extends StatelessWidget {
  final String path;
  const _ErrorRouteScreen({required this.path});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text('Page not found: $path')),
    );
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/',

  routes: [
    // Auth Routes...
    GoRoute(path: '/login-hub', builder: (context, state) => const LoginHubScreen()),
    GoRoute(path: '/otp', builder: (context, state) {
        if (state.extra is String) return OtpScreen(verificationId: state.extra as String);
        return _ErrorRouteScreen(path: state.matchedLocation);
    }),

    // Shell Route (Tabs)
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScreen(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/test-series', builder: (context, state) => const TestSeriesScreen()),
        GoRoute(path: '/bookmarks_home', builder: (context, state) => const BookmarksHomeScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        
        // Other Tab Routes...
        GoRoute(path: '/my-notes', builder: (context, state) => const MyNotesScreen()),
        GoRoute(path: '/public-notes', builder: (context, state) => const PublicNotesScreen()),
        GoRoute(path: '/schedules', builder: (context, state) => const SchedulesScreen()),
        GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: '/pomodoro', builder: (context, state) => const PomodoroScreen()),
        GoRoute(path: '/todo-list', builder: (context, state) => const TodoListScreen()),
        GoRoute(path: '/timetable', builder: (context, state) => const TimetableScreen()),
      ],
    ),

    // =================================================================
    // 🛑 FULL SCREEN TEST ROUTES (Updated for Nested Structure)
    // =================================================================

    // 1. SUBJECT LIST SCREEN (New)
    GoRoute(
      path: '/subject-list',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return SubjectListScreen(
          seriesId: data['seriesId'], 
          seriesTitle: data['seriesTitle']
        );
      },
    ),

    // 2. TEST LIST SCREEN (Updated to accept Map)
    GoRoute(
      path: '/test-list',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        
        return TestListScreen(
          seriesId: data['seriesId'],
          subjectId: data['subjectId'], // Ab Subject ID bhi pass hogi
          subjectTitle: data['subjectTitle'] ?? 'Tests',
        );
      },
    ),

    // 3. SERIES TEST SCREEN (Updated)
    GoRoute(
      path: '/series-test-screen',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final testInfo = state.extra as TestInfo?;
        if (testInfo == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return SeriesTestScreen(testInfo: testInfo);
      },
    ),

    // ... (Baaki Daily Test, Score, Result, Practice routes same rahenge) ...
    GoRoute(
      path: '/practice-mcq',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is Map<String, dynamic>) return PracticeMcqScreen(quizData: state.extra as Map<String, dynamic>);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/test-screen',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final questionIds = (extra?['ids'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [];
        if (questionIds.isEmpty) return _ErrorRouteScreen(path: state.matchedLocation);
        return DailyTestScreen(questionIds: questionIds);
      },
    ),
    GoRoute(
      path: '/score',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return ScoreScreen(
          totalQuestions: data['totalQuestions'],
          finalScore: data['finalScore'],
          correctCount: data['correctCount'],
          wrongCount: data['wrongCount'],
          unattemptedCount: data['unattemptedCount'],
          topicName: data['topicName'],
          questions: data['questions'],
          userAnswers: data['userAnswers'],
        );
      },
    ),
    GoRoute(
      path: '/result-screen',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return ResultScreen(
          score: data['score'],
          correct: data['correct'],
          wrong: data['wrong'],
          unattempted: data['unattempted'],
          questions: data['questions'],
          userAnswers: data['userAnswers'],
          topicName: data['topicName'],
        );
      },
    ),
    GoRoute(
      path: '/solutions',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return SolutionsScreen(
          questions: data['questions'],
          userAnswers: data['userAnswers'],
        );
      },
    ),
    GoRoute(
      path: '/solution-screen',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>?;
        if (data == null) return _ErrorRouteScreen(path: state.matchedLocation);
        return SolutionScreen(
          questions: data['questions'],
          userAnswers: data['userAnswers'],
        );
      },
    ),
    
    // Drill down & Notes routes...
    GoRoute(
      path: '/subjects',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is Map<String, String>) return SubjectsScreen(seriesData: state.extra as Map<String, String>);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/topics',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is Map<String, String>) return TopicsScreen(subjectData: state.extra as Map<String, String>);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/sets',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is Map<String, String>) return SetsScreen(topicData: state.extra as Map<String, String>);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/add-edit-note',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => AddEditNoteScreen(note: state.extra as MyNote?),
    ),
    GoRoute(
      path: '/note-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is PublicNote) return NoteDetailScreen(note: state.extra as PublicNote);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/bookmark-question-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is Question) return BookmarkedQuestionDetailScreen(question: state.extra as Question);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/bookmark-note-detail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        if (state.extra is BookmarkedNote) return BookmarkedNoteDetailScreen(note: state.extra as BookmarkedNote);
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
  ],

  redirect: (BuildContext context, GoRouterState state) {
    if (Firebase.apps.isEmpty) return null;
    final user = FirebaseAuth.instance.currentUser;
    final loggingIn = state.matchedLocation == '/login-hub' || state.matchedLocation == '/otp';
    if (user == null) return loggingIn ? null : '/login-hub';
    if (loggingIn) return '/';
    return null;
  },
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
