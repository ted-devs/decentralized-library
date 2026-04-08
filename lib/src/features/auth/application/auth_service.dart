import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/app_user.dart';

// --- Providers ---

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Watches the Firebase Auth state and fetches the corresponding Firestore document.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              return AppUser.fromMap(snapshot.data()!, snapshot.id);
            }
            return null;
          });
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => Stream.error(err),
  );
});

/// Fetches a specific user profile by their ID.
final userProvider = StreamProvider.family<AppUser?, String>((ref, userId) {
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          return AppUser.fromMap(snapshot.data()!, snapshot.id);
        }
        return null;
      });
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

// --- Service Implementation ---

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  AuthService(this._auth);

  /// Ensures the Google Sign In plugin is initialized for Android.
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      // For Android, authenticate() triggers the native one-tap or account picker
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // Explicitly await the authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Access tokens for Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      // Re-throwing so your UI can catch and show a SnackBar/Alert
      throw Exception('Google Sign-In failed: $e');
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception(_parseAuthError(e));
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_parseAuthError(e));
    }
  }

  String _parseAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'The account already exists for that email.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'weak-password':
          return 'The password is too weak (min 6 chars).';
        default:
          return e.message ?? 'An unknown error occurred.';
      }
    }
    return e.toString();
  }

  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      // Important to sign out of both to allow user to switch accounts next time
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }
}
