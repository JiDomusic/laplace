import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final SupabaseService _db = SupabaseService.instance;
  final AuthService _auth = AuthService.instance;
  Map<String, int> _stats = {};
  bool _isLoading = true;

  bool get _puedeGestionarPagos => _auth.userRole == 'admin' || _auth.userRole == 'superadmin';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _db.getEstadisticas();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrativo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estadísticas
                    _buildStatsGrid(),
                    const SizedBox(height: 24),

                    // Acciones rápidas
                    const Text(
                      'Acciones Rapidas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildAccionesRapidas(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _auth.userName.isNotEmpty ? _auth.userName[0].toUpperCase() : 'A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _auth.userName,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _auth.userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Inscripciones'),
            trailing: _stats['pendientes'] != null && _stats['pendientes']! > 0
                ? CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.dangerColor,
                    child: Text(
                      '${_stats['pendientes']}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin/inscripciones');
            },
          ),
          if (_puedeGestionarPagos)
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('Cuotas'),
              trailing: _stats['cuotas_pendientes'] != null && _stats['cuotas_pendientes']! > 0
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.warningColor,
                      child: Text(
                        '${_stats['cuotas_pendientes']}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/admin/cuotas');
              },
            ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galeria'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/admin/galeria');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Ir al Inicio'),
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
            title: const Text('Cerrar Sesion', style: TextStyle(color: AppTheme.dangerColor)),
            onTap: () {
              _auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final cards = <Widget>[
      _buildStatCard(
        'Total Inscripciones',
        '${_stats['total'] ?? 0}',
        Icons.people,
        AppTheme.primaryColor,
      ),
      _buildStatCard(
        'Pendientes',
        '${_stats['pendientes'] ?? 0}',
        Icons.hourglass_empty,
        AppTheme.warningColor,
      ),
      _buildStatCard(
        'Aprobados',
        '${_stats['aprobados'] ?? 0}',
        Icons.check_circle,
        AppTheme.successColor,
      ),
    ];

    if (_puedeGestionarPagos) {
      cards.add(
        _buildStatCard(
          'Cuotas Pendientes',
          '${_stats['cuotas_pendientes'] ?? 0}',
          Icons.payment,
          AppTheme.dangerColor,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: cards,
    );
  }

  Widget _buildStatCard(String titulo, String valor, IconData icono, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Column(
      children: [
        _buildAccionCard(
          'Ver Inscripciones Pendientes',
          'Revisar y aprobar inscripciones',
          Icons.pending_actions,
          () => Navigator.pushNamed(context, '/admin/inscripciones'),
        ),
        _buildAccionCard(
          'Gestionar Cuotas',
          'Ver cuotas y registrar pagos',
          Icons.payment,
          () => Navigator.pushNamed(context, '/admin/cuotas'),
        ),
        _buildAccionCard(
          'Nueva Inscripcion',
          'Registrar un nuevo alumno',
          Icons.person_add,
          () => Navigator.pushNamed(context, '/inscripcion'),
        ),
      ],
    );
  }

  Widget _buildAccionCard(String titulo, String subtitulo, IconData icono, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: AppTheme.primaryColor),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
