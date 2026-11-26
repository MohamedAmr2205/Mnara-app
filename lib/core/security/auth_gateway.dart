import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Signed-in account.
class AuthUser {
  /// Creates an account descriptor.
  const AuthUser({required this.uid, required this.email});

  /// Firebase uid.
  final String uid;

  /// Account email.
  final String email;
}

/// Sign-in problem with a ready-to-show Arabic message.
class AuthFailure implements Exception {
  /// Creates a failure.
  const AuthFailure(this.message);

  /// Message for the user.
  final String message;

  @override
  String toString() => message;
}

/// Account operations, abstracted so the lock logic is testable.
abstract class AuthGateway {
  /// The persisted Firebase session, if any (works offline).
  AuthUser? get currentUser;

  /// Signs in with email and password (needs the network).
  Future<AuthUser> signIn(String email, String password);

  /// Re-checks the password of the signed-in account (needs the network).
  Future<void> reauthenticate(String password);

  /// Reads `users/{uid}.teacherId`.
  Future<String?> fetchTeacherId(String uid);

  /// Signs out.
  Future<void> signOut();
}

/// Firebase implementation.
class FirebaseAuthGateway implements AuthGateway {
  /// Creates the gateway.
  FirebaseAuthGateway({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    if (u == null) return null;
    return AuthUser(uid: u.uid, email: u.email ?? '');
  }

  static AuthFailure _map(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const AuthFailure('الإيميل مش مكتوب صح');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFailure('الإيميل أو الباسورد غلط');
      case 'network-request-failed':
        return const AuthFailure('مفيش نت. أول دخول لازم يكون والنت شغال.');
      case 'too-many-requests':
        return const AuthFailure('محاولات كتير. استنى شوية وجرّب تاني.');
      case 'user-disabled':
        return const AuthFailure('الحساب ده متوقف. كلّم المدرس.');
      default:
        return const AuthFailure('حصلت مشكلة. جرّب تاني.');
    }
  }

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final u = cred.user!;
      return AuthUser(uid: u.uid, email: u.email ?? email.trim());
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final u = _auth.currentUser;
    if (u == null || u.email == null) {
      throw const AuthFailure('لازم تسجّل دخول من جديد.');
    }
    try {
      await u.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: u.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String?> fetchTeacherId(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data();
      if (data == null || data['role'] != 'assistant') return null;
      return data['teacherId'] as String?;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
