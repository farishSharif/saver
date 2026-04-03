import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/dashboard/user/user_dashboard_screen.dart';
import '../features/dashboard/saver/saver_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.value?.session != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        if (userProfile.hasValue && userProfile.value != null) {
          if (userProfile.value!.role == 'saver') {
            return '/saver';
          }
          return '/user';
        }
        return '/loading';
      }

      // If we are at /loading and profile is fetched
      if (state.matchedLocation == '/loading') {
        if (userProfile.hasValue && userProfile.value != null) {
          if (userProfile.value!.role == 'saver') {
            return '/saver';
          }
          return '/user';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/user',
        builder: (context, state) => const UserDashboardScreen(),
      ),
      GoRoute(
        path: '/saver',
        builder: (context, state) => const SaverDashboardScreen(),
      ),
    ],
  );
});
