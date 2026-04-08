import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/auth_service.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../../home/presentation/main_navigation_shell.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          // 1. User is not authenticated in Firebase
          return const LoginScreen();
        }

        // 2. User is authenticated, wait for Firestore doc check
        final appUserAsync = ref.watch(appUserProvider);

        return appUserAsync.when(
          data: (appUser) {
            if (appUser == null) {
              // 3. User doc missing, they need to onboard
              return OnboardingScreen(firebaseUser: user);
            }
            // 4. Fully authenticated and onboarded
            return const MainNavigationShell();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Scaffold(
            body: Center(child: Text('Error loading user profile: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Error with authentication: $e')),
      ),
    );
  }
}
