import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'openid',
    ],
    serverClientId: '350136792509-5skp9610671pa007roroqim6pq441i3m.apps.googleusercontent.com',
    signInOption: SignInOption.standard,
  );

  User? _user;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _userProfile?['role'] == 'Admin';
  bool get isInitialized => _user != null || _userProfile != null || !_isLoading;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() async {
    print('Initializing AuthProvider...');

    // Check current session first
    final session = _supabase.auth.currentSession;
    print('Current session: ${session != null ? 'exists' : 'null'}');

    if (session != null) {
      _user = session.user;
      print('User from session: ${_user?.email}');
      await _loadUserProfile();
    } else {
      print('No active session found');
    }

    // Listen for auth state changes
    _supabase.auth.onAuthStateChange.listen((event) {
      print('Auth state change: ${event.event}');
      _user = event.session?.user;
      if (_user != null) {
        print('User authenticated: ${_user?.email}');
        _loadUserProfile();
      } else {
        print('User signed out');
        _userProfile = null;
      }
      notifyListeners();
    });

    print('AuthProvider initialization complete');
  }

  Future<void> _loadUserProfile() async {
    if (_user == null) return;

    try {
      print('Loading user profile for: ${_user!.id}');
      final response = await _supabase
          .from('kl_users')
          .select()
          .eq('id', _user!.id)
          .single();

      _userProfile = response;
      print('User profile loaded: ${_userProfile?['full_name']} (${_userProfile?['role']})');
      notifyListeners();
    } catch (e) {
      print('Error loading user profile: $e');
      // User profile doesn't exist yet, will be created during registration
      _userProfile = null;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('Google Sign-In: Starting authentication process...');

      // Sign out first to ensure clean state
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In: User cancelled sign-in');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('Google Sign-In: User selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google Sign-In: Authentication object received');

      // Check if we have the required tokens
      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        print('Google Sign-In Error: No ID token received');
        print('Google Sign-In: Available tokens - ID: ${googleAuth.idToken != null}, Access: ${googleAuth.accessToken != null}');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      print('Google Sign-In: ID token received, length: ${googleAuth.idToken!.length}');
      print('Google Sign-In: Attempting to authenticate with Supabase...');

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );

      _user = response.user;
      print('Google Sign-In: Authentication successful for user: ${_user?.email}');
      print('Google Sign-In: User ID: ${_user?.id}');

      await _loadUserProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      print('Google Sign-In Error: $e');
      print('Google Sign-In StackTrace: $stackTrace');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      _user = response.user;
      await _loadUserProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Email Sign-In Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      _user = response.user;
      // Note: User profile will be created during registration completion

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Email Sign-Up Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeRegistration({
    required String fullName,
    required String phoneNumber,
    required String fullAddress,
  }) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.from('kl_users').insert({
        'id': _user!.id,
        'email': _user!.email,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'full_address': fullAddress,
        'role': 'Customer',
        'created_at': DateTime.now().toIso8601String(),
      });

      await _loadUserProfile();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Profile Registration Error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    print('Signing out user...');
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      print('Successfully signed out from Supabase and Google');
    } catch (e) {
      print('Sign out error: $e');
    } finally {
      _user = null;
      _userProfile = null;
      print('Cleared local authentication state');
      notifyListeners();
    }
  }

  Future<void> refreshAuthState() async {
    print('Refreshing authentication state...');
    final session = _supabase.auth.currentSession;
    print('Current session check: ${session != null ? 'exists' : 'null'}');

    if (session != null) {
      _user = session.user;
      print('Session user: ${_user?.email}');
      await _loadUserProfile();
      print('Refreshed auth state: user=${_user?.email}, profile=${_userProfile != null}, role=${_userProfile?['role']}');
    } else {
      _user = null;
      _userProfile = null;
      print('No active session found - user set to null');
    }
    notifyListeners();
  }

  Future<void> clearAllData() async {
    print('Clearing all authentication data...');
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      _user = null;
      _userProfile = null;
      print('All authentication data cleared');
      notifyListeners();
    } catch (e) {
      print('Error clearing data: $e');
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? fullAddress,
  }) async {
    if (_user == null || _userProfile == null) return false;

    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (fullAddress != null) updates['full_address'] = fullAddress;

      await _supabase
          .from('kl_users')
          .update(updates)
          .eq('id', _user!.id);

      await _loadUserProfile();
      return true;
    } catch (e) {
      return false;
    }
  }
}