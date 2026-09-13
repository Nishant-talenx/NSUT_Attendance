import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imsnsit/root_scaffold.dart';
import 'package:imsnsit/screens/about_screen.dart';
import 'package:imsnsit/screens/attendance/attandance_screen.dart';
import 'package:imsnsit/screens/attendance/subject_attendance_screen.dart';
import 'package:imsnsit/screens/authentication/login_screen.dart';
import 'package:imsnsit/screens/authentication/manual_relogin.dart';
import 'package:imsnsit/screens/initial_screen.dart';
import 'package:imsnsit/screens/profile_screen.dart';
import 'package:imsnsit/widgets/update_dialog.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _shellNavigatorProfileKey =
    GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

final _shellNavigatorAttendanceKey =
    GlobalKey<NavigatorState>(
  debugLabel: 'shellAttendance',
);

class MyAppRouter {
  static GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/initial_screen',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return AppScaffold(
            child: child,
          );
        },
        branches: [
          // ATTENDANCE
          StatefulShellBranch(
            navigatorKey:
                _shellNavigatorAttendanceKey,
            routes: [
              GoRoute(
                path: '/attendance/total',
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(
                  child: AttandanceScreen(),
                  maintainState: true,
                ),
              ),
              GoRoute(
                name: 'subject_attendance',
                path:
                    '/attendance/subject_wise/:subject/:subjectCode',
                pageBuilder:
                    (context, state) =>
                        MaterialPage(
                  child: SubjectAttandanceScreen(
                    subject:
                        state.pathParameters[
                            'subject']!,
                    subjectCode:
                        state.pathParameters[
                            'subjectCode']!,
                  ),
                ),
              ),
            ],
          ),

          // PROFILE
          StatefulShellBranch(
            navigatorKey:
                _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: '/profile_screen',
                pageBuilder:
                    (context, state) =>
                        const MaterialPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // LOGIN
      GoRoute(
        path: '/authentication/login_screen',
        pageBuilder:
            (context, state) =>
                const MaterialPage(
          child: LoginScreen(),
        ),
      ),

      // MANUAL LOGIN
      GoRoute(
        path: '/authentication/manual_login',
        pageBuilder:
            (context, state) =>
                const MaterialPage(
          child: ManualRelogin(),
        ),
      ),

      // ABOUT
      GoRoute(
        path: '/about_screen',
        pageBuilder:
            (context, state) =>
                const MaterialPage(
          child: AboutScreen(),
        ),
      ),

      // INITIAL SCREEN
      GoRoute(
        path: '/initial_screen',
        pageBuilder:
            (context, state) =>
                const MaterialPage(
          child: InitialScreen(),
        ),
      ),

      // UPDATE
      GoRoute(
        path: '/update_screen',
        pageBuilder:
            (context, state) =>
                const MaterialPage(
          fullscreenDialog: true,
          maintainState: true,
          child: UpdateDialog(),
        ),
      ),
    ],
  );
}
