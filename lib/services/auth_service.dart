import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService with ChangeNotifier {
  static final AuthService instance = AuthService._init();
  final SupabaseService _db = SupabaseService.instance;

  AuthService._init();

  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  String? _error;
  String? _savedEmail; // Email guardado para recordar

  // Keys para SharedPreferences
  static const String _keyUser = 'admin_user';
  static const String _keyEmail = 'admin_email';

  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get userName => _currentUser?['nombre'] ?? '';
  String get userEmail => _currentUser?['email'] ?? '';
  String get userRole => _currentUser?['rol'] ?? '';
  String? get savedEmail => _savedEmail;

  // Inicializar - restaurar sesión guardada
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar email guardado
      _savedEmail = prefs.getString(_keyEmail);

      // Intentar restaurar sesión
      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        _currentUser = jsonDecode(userJson);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restaurando sesión: $e');
    }
  }

  // Guardar email para recordar
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    _savedEmail = email;
  }

  // Login
  Future<bool> login(String email, String password, {bool rememberEmail = true}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cerrar sesión previa si la hubiera
      await Supabase.instance.client.auth.signOut();

      final user = await _db.loginAdmin(email.trim(), password);

      if (user != null) {
        _currentUser = user;

        // Guardar sesión
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(user));

        // Guardar email si se pide recordar
        if (rememberEmail) {
          await prefs.setString(_keyEmail, email.trim());
          _savedEmail = email.trim();
        }

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
  Future<void> logout() async {
    Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _error = null;

    // Borrar sesión guardada (pero mantener el email)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);

    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Olvidar email guardado
  Future<void> forgetEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    _savedEmail = null;
    notifyListeners();
  }

  bool get isSuperAdmin => _currentUser?['rol'] == 'superadmin';

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) return false;
    final id = _currentUser!['id']?.toString();
    if (id == null) return false;

    // Verify current password contra la tabla de administradores
    final adminData = await _db.getAdminByEmail(userEmail);
    if (adminData == null || adminData['password'] != currentPassword) {
      _error = 'Contraseña actual incorrecta';
      notifyListeners();
      return false;
    }

    try {
      await _db.changeAdminPassword(id, newPassword, email: userEmail);

      // Si el usuario también existe en Supabase Auth, intentar actualizar allí para mantenerlo en sync
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null) {
        try {
          await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPassword));
        } catch (_) {
          // Ignorar error de Supabase Auth; la tabla ya se actualizó
        }
      }

      return true;
    } catch (e) {
      _error = 'Error al cambiar contraseña: $e';
      notifyListeners();
      return false;
    }
  }
}
