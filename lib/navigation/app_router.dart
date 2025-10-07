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
import 'package:exambeing/helpers/database_helper.dart'; // ✅ This import makes MyNote available

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
        final verificationId = state.extra as String;
        return OtpScreen(verificationId: verificationId);
      },
    ),
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
    GoRoute(
      path: '/subjects',
      builder: (context, state) {
        final seriesData = state.extra as Map<String, String>;
        return SubjectsScreen(seriesData: seriesData);
      },
    ),
    GoRoute(
      path: '/topics',
      builder: (context, state) {
        final subjectData = state.extra as Map<String, String>;
        return TopicsScreen(subjectData: subjectData);
      },
    ),
    GoRoute(
      path: '/sets',
      builder: (context, state) {
        final topicData = state.extra as Map<String, String>;
        return SetsScreen(topicData: topicData);
      },
    ),
    GoRoute(
      path: '/practice-mcq',
      builder: (context, state) {
        final quizData = state.extra as Map<String, dynamic>;
        return PracticeMcqScreen(quizData: quizData);
      },
    ),
    GoRoute(
      path: '/score',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
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
      },
    ),
    GoRoute(
      path: '/solutions',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return SolutionsScreen(
          questions: data['questions'] as List<Question>,
          userAnswers: data['userAnswers'] as Map<int, String>,
        );
      },
    ),
    GoRoute(
      path: '/my-notes',
      builder: (context, state) => const MyNotesScreen(),
    ),
    GoRoute(
      path: '/add-edit-note',
      builder: (context, state) {
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
        final question = state.extra as Question;
        return BookmarkedQuestionDetailScreen(question: question);
      },
    ),
    GoRoute(
      path: '/bookmark-note-detail',
      builder: (context, state) {
        final note = state.extra as PublicNote;
        return BookmarkedNoteDetailScreen(note: note);
      },
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login-hub' || state.matchedLocation == '/otp';

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
    _subscription = stream.asBroadcastStream().listen((dynamic _) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
