import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcıyı getir
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email ile kayıt ol
  Future<AuthResult> signUpWithEmail(String email, String password, String displayName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Kullanıcı profilini güncelle
        await user.updateDisplayName(displayName);
        
        // Firestore'a kullanıcı bilgilerini kaydet
        final appUser = AppUser(
          id: user.uid,
          email: email,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isProfileComplete: false,
        );
        
        await _firestore.collection('users').doc(user.uid).set(appUser.toJson());
        
        return AuthResult(success: true, user: user);
      }
      
      return AuthResult(success: false, error: 'Kullanıcı oluşturulamadı');
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  // Email ile giriş yap
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        // Son giriş zamanını güncelle
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': Timestamp.fromDate(DateTime.now()),
        });
        
        return AuthResult(success: true, user: user);
      }
      
      return AuthResult(success: false, error: 'Giriş yapılamadı');
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Çıkış yapılırken hata: $e');
    }
  }

  // Şifre sıfırlama e-postası gönder
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } catch (e) {
      return AuthResult(success: false, error: _getErrorMessage(e));
    }
  }

  // Kullanıcı bilgilerini Firestore'dan getir
  Future<AppUser?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return AppUser.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Kullanıcı bilgileri alınırken hata: $e');
      return null;
    }
  }

  // Kullanıcı bilgilerini güncelle
  Future<bool> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      return true;
    } catch (e) {
      print('Kullanıcı bilgileri güncellenirken hata: $e');
      return false;
    }
  }

  // Hata mesajlarını Türkçe'ye çevir
  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'Şifre çok zayıf';
        case 'email-already-in-use':
          return 'Bu e-posta adresi zaten kullanılıyor';
        case 'invalid-email':
          return 'Geçersiz e-posta adresi';
        case 'user-not-found':
          return 'Kullanıcı bulunamadı';
        case 'wrong-password':
          return 'Hatalı şifre';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
        case 'network-request-failed':
          return 'Ağ bağlantısı hatası';
        default:
          return 'Bir hata oluştu: ${error.message}';
      }
    }
    return 'Bilinmeyen bir hata oluştu';
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.error,
  });
}
