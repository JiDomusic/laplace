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
    _loadData();
  }

  Future<void> _loadData() async {
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _auth.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: IconThemeData(color: Colors.grey.shade800),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo_laplace.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.school,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Instituto Laplace',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black87),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeCard(),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildSeccionTitulo(
                          'Acciones rapidas',
                          descripcion: 'Atajos para las tareas que mas usas',
                        ),
                        const SizedBox(height: 12),
                        _buildAccionesGrid(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final hora = DateTime.now().hour;
    String saludo;
    if (hora < 12) {
      saludo = 'Buenos dias';
    } else if (hora < 19) {
      saludo = 'Buenas tardes';
    } else {
      saludo = 'Buenas noches';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), AppTheme.primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 400;

            final infoColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Admin ${_auth.userRole}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.shield_moon, color: Colors.white.withOpacity(0.8)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$saludo,',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  _auth.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Text(
                  'Panel de administracion · Ciclo 2026',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            );

            final statsBox = Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isWide
                  ? Column(
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          '${_stats['total'] ?? 0} alumnos',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Activos',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/admin/inscripciones'),
                          child: const Text('Ver inscripciones', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.school, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_stats['total'] ?? 0} alumnos',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  'Activos',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/admin/inscripciones'),
                          child: const Text('Ver', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: infoColumn),
                  const SizedBox(width: 12),
                  statsBox,
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  infoColumn,
                  const SizedBox(height: 16),
                  statsBox,
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final items = <Map<String, dynamic>>[
      {
        'label': 'Total de alumnos',
        'valor': '${_stats['total'] ?? 0}',
        'icon': Icons.people,
        'color': AppTheme.primaryColor,
        'detalle': 'Matriculas activas',
      },
      {
        'label': 'Pendientes',
        'valor': '${_stats['pendientes'] ?? 0}',
        'icon': Icons.schedule,
        'color': AppTheme.warningColor,
        'detalle': 'Inscripciones en revisión',
      },
      {
        'label': 'Aprobados',
        'valor': '${_stats['aprobados'] ?? 0}',
        'icon': Icons.check_circle,
        'color': AppTheme.successColor,
        'detalle': 'Listos para cursar',
      },
    ];

    if (_puedeGestionarPagos) {
      items.add(
        {
          'label': 'Cuotas',
          'valor': '${_stats['cuotas_pendientes'] ?? 0}',
          'icon': Icons.payment,
          'color': AppTheme.dangerColor,
          'detalle': 'Pagos pendientes',
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final crossAxisCount = isWide ? 4 : 2;
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _buildStatCard(
                    valor: item['valor'] as String,
                    label: item['label'] as String,
                    icon: item['icon'] as IconData,
                    color: item['color'] as Color,
                    detalle: item['detalle'] as String?,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String valor,
    required String label,
    required IconData icon,
    required Color color,
    String? detalle,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              valor,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 6),
              Text(
                detalle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, {String? descripcion, Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (descripcion != null)
                Text(
                  descripcion,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildAccionesGrid() {
    final acciones = <Map<String, dynamic>>[
      {
        'titulo': 'Inscripciones',
        'subtitulo': '${_stats['pendientes'] ?? 0} pendientes',
        'icon': Icons.people,
        'color': Colors.indigo,
        'onTap': () => Navigator.pushNamed(context, '/admin/inscripciones'),
      },
      {
        'titulo': 'Cuotas',
        'subtitulo': 'Gestionar pagos',
        'icon': Icons.payment,
        'color': Colors.teal,
        'onTap': () => Navigator.pushNamed(context, '/admin/cuotas'),
      },
      {
        'titulo': 'Galeria',
        'subtitulo': 'Fotos de eventos',
        'icon': Icons.photo_library,
        'color': Colors.orange,
        'onTap': () => Navigator.pushNamed(context, '/admin/galeria'),
      },
      {
        'titulo': 'Nueva inscripción',
        'subtitulo': 'Registrar alumno',
        'icon': Icons.person_add,
        'color': Colors.green,
        'onTap': () => Navigator.pushNamed(context, '/inscripcion'),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final crossAxisCount = isWide ? 4 : 2;
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: acciones
              .map(
                (accion) => SizedBox(
                  width: itemWidth,
                  child: _buildAccionCard(
                    accion['titulo'] as String,
                    accion['subtitulo'] as String,
                    accion['icon'] as IconData,
                    accion['color'] as Color,
                    accion['onTap'] as VoidCallback,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAccionCard(
    String titulo,
    String subtitulo,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo_laplace.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school,
                        color: AppTheme.primaryColor,
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Instituto Laplace',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Rosario - Santa Fe',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _buildDrawerItem(Icons.dashboard, 'Dashboard', true, () => Navigator.pop(context)),
                _buildDrawerItem(
                  Icons.people,
                  'Inscripciones',
                  false,
                  () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin/inscripciones');
                  },
                  badge: _stats['pendientes'],
                ),
                if (_puedeGestionarPagos)
                  _buildDrawerItem(
                    Icons.payment,
                    'Cuotas',
                    false,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin/cuotas');
                    },
                  ),
                _buildDrawerItem(
                  Icons.photo_library,
                  'Galeria',
                  false,
                  () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin/galeria');
                  },
                ),
                const Divider(),
                _buildDrawerItem(
                  Icons.home,
                  'Ir al Inicio',
                  false,
                  () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    _auth.userName.isNotEmpty ? _auth.userName[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _auth.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _auth.userRole,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: AppTheme.dangerColor),
                  onPressed: () {
                    _auth.logout();
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool selected, VoidCallback onTap, {int? badge}) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppTheme.primaryColor : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? AppTheme.primaryColor : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: badge != null && badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.dangerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
