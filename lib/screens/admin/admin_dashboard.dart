import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/alumno.dart';
import '../../models/config_cuotas_periodo.dart';
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
  List<Alumno> _alumnos = [];
  bool _isLoading = true;

  // 0 = Cuotas e Inscripciones, 1 = Alumnos
  int _seccionActual = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stats = await _db.getEstadisticas();
      final alumnos = await _db.getAllAlumnos();

      setState(() {
        _stats = stats;
        _alumnos = alumnos;
        _isLoading = false;
      });

      _checkMonthlyConfig();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkMonthlyConfig() async {
    final ahora = DateTime.now();
    final mesKey = 'config_mes_${ahora.year}_${ahora.month}';
    final isFirstDay = ahora.day == 1;

    final prefs = await SharedPreferences.getInstance();
    if (!isFirstDay && prefs.getBool(mesKey) == true) return;

    final nivelesObjetivo = isFirstDay
        ? ['Primer Año', 'Segundo Año', 'Tercer Año']
        : await _db.verificarConfigMesActual();

    if (nivelesObjetivo.isEmpty && !isFirstDay) {
      await prefs.setBool(mesKey, true);
      return;
    }

    if (!mounted) return;
    final confirmo = await _showMonthlyConfigPopup(nivelesObjetivo, forcePrompt: isFirstDay);
    if (confirmo == true) {
      await prefs.setBool(mesKey, true);
    }
  }

  Future<bool?> _showMonthlyConfigPopup(List<String> nivelesFaltantes, {bool forcePrompt = false}) async {
    final ahora = DateTime.now();
    final mesActual = ahora.month;
    final anioActual = ahora.year;
    final nombreMes = ConfigCuotasPeriodo.nombreMes(mesActual);

    // Controllers por nivel: {nivel: [alDia, 1erVto, 2doVto]}
    final controllers = <String, List<TextEditingController>>{};
    for (final nivel in nivelesFaltantes) {
      final config = await _db.getConfigCuotasPeriodo(nivel: nivel, mes: mesActual, anio: anioActual);
      controllers[nivel] = [
        TextEditingController(text: config?.montoAlDia.toString() ?? ''),
        TextEditingController(text: config?.monto1erVto.toString() ?? ''),
        TextEditingController(text: config?.monto2doVto.toString() ?? ''),
      ];
    }
    // Solo mensual; sin replicar otro mes
    final aplicarCuotas = ValueNotifier<bool>(true);
    final incluirVencidas = ValueNotifier<bool>(true);

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                forcePrompt
                    ? 'Es 1° de mes: confirma montos de $nombreMes $anioActual'
                    : 'Configurar $nombreMes $anioActual',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forcePrompt
                    ? 'Define los valores para cada vencimiento de este mes. Si ya estaban configurados, puedes ajustarlos ahora.'
                    : 'Falta configurar los montos de cuotas para $nombreMes.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              for (final nivel in nivelesFaltantes) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nivel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controllers[nivel]![0],
                        decoration: const InputDecoration(
                          labelText: '1° Vencimiento (1-10)',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controllers[nivel]![1],
                        decoration: const InputDecoration(
                          labelText: '2° Vencimiento (11-20)',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controllers[nivel]![2],
                        decoration: const InputDecoration(
                          labelText: '3° Vencimiento (21-31)',
                          prefixText: '\$ ',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
              ValueListenableBuilder<bool>(
                valueListenable: aplicarCuotas,
                builder: (_, value, __) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Actualizar cuotas del mes con estos valores'),
                    value: value,
                    onChanged: (v) => aplicarCuotas.value = v ?? true,
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: incluirVencidas,
                builder: (_, value, __) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incluir cuotas vencidas'),
                    value: value,
                    onChanged: aplicarCuotas.value
                        ? (v) => incluirVencidas.value = v ?? true
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      for (final nivel in nivelesFaltantes) {
        final ctrls = controllers[nivel]!;
        final montoAlDia = int.tryParse(ctrls[0].text) ?? 0;
        final monto1erVto = int.tryParse(ctrls[1].text) ?? montoAlDia;
        final monto2doVto = int.tryParse(ctrls[2].text) ?? monto1erVto;
        if (montoAlDia <= 0) continue;

        await _db.guardarConfigCuotasPeriodo(ConfigCuotasPeriodo(
          nivel: nivel,
          mes: mesActual,
          anio: anioActual,
          montoAlDia: montoAlDia,
          monto1erVto: monto1erVto,
          monto2doVto: monto2doVto,
        ));

        if (aplicarCuotas.value) {
          await _db.actualizarCuotasConConfigPeriodo(
            nivel: nivel,
            mes: mesActual,
            anio: anioActual,
            soloPendientes: true,
            incluirVencidas: incluirVencidas.value,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Montos de $nombreMes configurados'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    // Dispose controllers
    for (final ctrls in controllers.values) {
      for (final c in ctrls) {
        c.dispose();
      }
    }
    return confirmar == true;
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
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar, color: Colors.white),
              tooltip: 'Configurar montos del mes',
              onPressed: () async {
                await _showMonthlyConfigPopup(['Primer Año', 'Segundo Año', 'Tercer Año'], forcePrompt: true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                _auth.logout();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Barra de navegación de secciones
              _buildNavBar(),
              // Contenido según sección
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _seccionActual == 0
                            ? _buildSeccionCuotasInscripciones()
                            : _buildSeccionAlumnos(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _buildNavButton(
                index: 0,
                icon: Icons.receipt_long,
                label: 'Cuotas e Inscripciones',
                color: AppTheme.accentColor,
                badge: _stats['total'],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNavButton(
                index: 1,
                icon: Icons.school,
                label: 'Alumnos',
                color: AppTheme.successColor,
                badge: _stats['total'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required int index,
    required IconData icon,
    required String label,
    required Color color,
    int? badge,
  }) {
    final isSelected = _seccionActual == index;

    return GestureDetector(
      onTap: () => setState(() => _seccionActual = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null && badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    color: isSelected ? color : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCuotasInscripciones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Acciones principales directas
          _buildAccionGrande(
            titulo: 'Alumnos Inscriptos',
            subtitulo: '${_stats['total'] ?? 0} alumnos registrados',
            icon: Icons.people,
            color: AppTheme.accentColor,
            onTap: () async {
              await Navigator.pushNamed(context, '/admin/inscripciones');
              if (mounted) _loadData();
            },
          ),
          const SizedBox(height: 12),
          _buildAccionGrande(
            titulo: 'Cuotas',
            subtitulo: '${_stats['cuotas_pendientes'] ?? 0} pagos pendientes',
            icon: Icons.payment,
            color: Colors.teal,
            onTap: () async {
              await Navigator.pushNamed(context, '/admin/cuotas');
              if (mounted) _loadData();
            },
          ),
          const SizedBox(height: 20),
          // Acciones secundarias
          Row(
            children: [
              Expanded(
                child: _buildAccionCompacta(
                  titulo: 'Nueva inscripción',
                  icon: Icons.person_add,
                  color: Colors.green,
                  onTap: () => Navigator.pushNamed(context, '/inscripcion'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccionCompacta(
                  titulo: 'Galería',
                  icon: Icons.photo_library,
                  color: Colors.orange,
                  onTap: () => Navigator.pushNamed(context, '/admin/galeria'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionAlumnos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Primer Año - División A
          _buildDivisionExpansion(
            nivel: 'Primer Año',
            division: 'A',
            color: Colors.indigo,
            icon: Icons.looks_one,
          ),
          const SizedBox(height: 8),
          // Primer Año - División B
          _buildDivisionExpansion(
            nivel: 'Primer Año',
            division: 'B',
            color: Colors.blue,
            icon: Icons.looks_one,
          ),
          const SizedBox(height: 8),
          // Segundo Año
          _buildDivisionExpansion(
            nivel: 'Segundo Año',
            division: null,
            color: Colors.teal,
            icon: Icons.looks_two,
          ),
          const SizedBox(height: 8),
          // Tercer Año
          _buildDivisionExpansion(
            nivel: 'Tercer Año',
            division: null,
            color: AppTheme.successColor,
            icon: Icons.looks_3,
          ),
        ],
      ),
    );
  }

  List<Alumno> _getAlumnosPorDivision(String nivel, String? division) {
    return _alumnos.where((a) {
      if (a.nivelInscripcion != nivel) return false;
      if (division != null) {
        return a.division == division;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.apellido.compareTo(b.apellido));
  }

  Widget _buildDivisionExpansion({
    required String nivel,
    required String? division,
    required Color color,
    required IconData icon,
  }) {
    final alumnos = _getAlumnosPorDivision(nivel, division);
    final titulo = division != null ? '$nivel - División $division' : nivel;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${alumnos.length} alumnos',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${alumnos.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        children: alumnos.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay alumnos en esta división',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ]
            : alumnos.map((alumno) => _buildAlumnoTile(alumno, color)).toList(),
      ),
    );
  }

  Widget _buildAlumnoTile(Alumno alumno, Color color) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Text(
          '${alumno.nombre[0]}${alumno.apellido[0]}'.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        alumno.nombreCompleto,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        'DNI: ${alumno.dni}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () async {
        await Navigator.pushNamed(context, '/admin/alumno/${alumno.id}');
        _loadData(); // Recargar al volver
      },
    );
  }

  Widget _buildAccionGrande({
    required String titulo,
    required String subtitulo,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccionCompacta({
    required String titulo,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
