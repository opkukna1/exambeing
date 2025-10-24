import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

// Helper widget, agar data galat ho to ise dikhayein
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

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  initialLocation: '/login-hub',
  routes: [
    GoRoute(
      path: '/login-hub',
      builder: (context, state) => const LoginHubScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) {
        // ✅ FIX: Check if data is valid
        if (state.extra is String) {
          final verificationId = state.extra as String;
          return OtpScreen(verificationId: verificationId);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
            path: '/test-series',
            builder: (context, state) => const TestSeriesScreen()),
        GoRoute(
            path: '/bookmarks_home',
            builder: (context, state) => const BookmarksHomeScreen()),
        GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen()),
      ],
    ),
    GoRoute(
      path: '/subjects',
      builder: (context, state) {
        // ✅ FIX: Check if data is valid
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
        // ✅ FIX: Check if data is valid
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
        // ✅ FIX: Check if data is valid
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
        // ✅ FIX: Check if data is valid
        if (state.extra is Map<String, dynamic>) {
          final quizData = state.extra as Map<String, dynamic>;
          return PracticeMcqScreen(quizData: quizData);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
    GoRoute(
      path: '/score',
      builder: (context, state) {
        final data = state.extra;
        // ✅ FIX: Check data type and all keys before casting
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
            // Catch if casting inside fails (e.g., totalQuestions was a String)
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
        // ✅ FIX: Check data type and all keys before casting
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
    GoRoute(
      path: '/my-notes',
      builder: (context, state) => const MyNotesScreen(),
    ),
    GoRoute(
      path: '/add-edit-note',
      builder: (context, state) {
        // This was already safe, no change needed
        final MyNote? note = state.extra as MyNote?;
        return AddEditNoteScreen(note: note);
      },
    ),
    GoRoute(
      path: '/public-notes',
      builder: (context, state) => const PublicNotesScreen(),
    ),
    GoRoute(
      path: '/schedules',
      builder: (context, state) => const SchedulesScreen(),
    ),
    GoRoute(
      path: '/bookmark-question-detail',
      builder: (context, state) {
        // ✅ FIX: Check if data is valid
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
        // ✅ FIX: Check if data is valid
        if (state.extra is PublicNote) {
          final note = state.extra as PublicNote;
          return BookmarkedNoteDetailScreen(note: note);
        }
        return _ErrorRouteScreen(path: state.matchedLocation);
      },
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool loggingIn =
        state.matchedLocation == '/login-hub' || state.matchedLocation == '/otp';

    if (!loggedIn) {
      return loggingIn ? null : '/login-hub';
    }

    if (loggingIn) {
      return '/';
    }

    return null;
  },
);

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
