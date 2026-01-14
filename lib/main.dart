import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/inscripcion_provider.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'screens/home_screen.dart';
import 'screens/inscripcion_screen.dart';
import 'screens/exito_screen.dart';
import 'screens/admin/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/inscripciones_screen.dart';
import 'screens/admin/ver_alumno_screen.dart';
import 'screens/admin/cuotas_screen.dart';
import 'screens/admin/galeria_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InscripcionProvider()),
        ChangeNotifierProvider.value(value: AuthService.instance),
      ],
      child: MaterialApp(
        title: 'Instituto Laplace',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/inscripcion': (context) => const InscripcionScreen(),
          '/exito': (context) => const ExitoScreen(),
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AuthGuard(child: AdminDashboard()),
          '/admin/inscripciones': (context) => const AuthGuard(child: InscripcionesScreen()),
          '/admin/cuotas': (context) => const AuthGuard(child: CuotasScreen()),
          '/admin/galeria': (context) => const AuthGuard(child: GaleriaScreen()),
        },
        onGenerateRoute: (settings) {
          if (settings.name?.startsWith('/admin/alumno/') ?? false) {
            final id = settings.name!.split('/').last;
            return MaterialPageRoute(
              builder: (context) => AuthGuard(
                child: VerAlumnoScreen(alumnoId: id),
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

/// Widget que protege las rutas del admin
class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          // Redirigir al login si no está autenticado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/login');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child;
      },
    );
  }
}
