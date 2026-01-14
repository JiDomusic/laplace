import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService with ChangeNotifier {
  static final AuthService instance = AuthService._init();
  final SupabaseService _db = SupabaseService.instance;

  AuthService._init();

  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get userName => _currentUser?['nombre'] ?? '';
  String get userEmail => _currentUser?['email'] ?? '';
  String get userRole => _currentUser?['rol'] ?? '';

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cerrar sesión previa si la hubiera
      await Supabase.instance.client.auth.signOut();

      final user = await _db.loginAdmin(email.trim(), password);

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Email o contraseña incorrectos';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error al iniciar sesión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  void logout() {
    Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
