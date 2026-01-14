/// Configuración centralizada para credenciales de Supabase.
/// Se recomienda pasar las credenciales en tiempo de compilación:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Si no se pasan, usa los valores por defecto aquí definidos.
class SupabaseConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mpeocakidrwiinhttivr.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1wZW9jYWtpZHJ3aWluaHR0aXZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzNDA5ODgsImV4cCI6MjA4MzkxNjk4OH0.3rVUEYfTCHy4zwGLJJDROIlvxvTTzDZP9kOXhVy_Pk8',
  );
}
