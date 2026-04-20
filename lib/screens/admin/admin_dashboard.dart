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
    // IMPORTANTE: dejamos los campos VACIOS para que la admin ingrese los montos reales.
    // Los valores previos (si existen) se muestran como helperText solo de referencia.
    final controllers = <String, List<TextEditingController>>{};
    final previos = <String, List<String?>>{};
    for (final nivel in nivelesFaltantes) {
      final config = await _db.getConfigCuotasPeriodo(nivel: nivel, mes: mesActual, anio: anioActual);
      controllers[nivel] = [
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ];
      previos[nivel] = [
        config?.montoAlDia.toString(),
        config?.monto1erVto.toString(),
        config?.monto2doVto.toString(),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ATENCIÓN: Los montos que pongas acá se usan para TODO el sistema: cuotas nuevas, PDFs y recargos. Revisalos bien antes de guardar.',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                forcePrompt
                    ? 'Define los valores para cada vencimiento de este mes. Si ya estaban configurados, puedes ajustarlos ahora.'
                    : 'Falta configurar los montos de cuotas para $nombreMes.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1976D2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tres vencimientos por mes:',
                        style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• 1° Vencimiento: lo paga del 1 al 10 (monto más bajo)', style: TextStyle(fontSize: 12, height: 1.4)),
                    Text('• 2° Vencimiento: lo paga del 11 al 20 (monto medio)', style: TextStyle(fontSize: 12, height: 1.4)),
                    Text('• 3° Vencimiento: lo paga del 21 en adelante (monto más alto)', style: TextStyle(fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF6F00)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                        SizedBox(width: 6),
                        Text('REGLA IMPORTANTE',
                            style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Si un alumno paga una cuota atrasada en otro mes, siempre se cobra con el 3° VENCIMIENTO del mes en el que está pagando (no del mes original).',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFD32F2F), width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_note, color: Color(0xFFD32F2F), size: 22),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los campos están VACÍOS a propósito. Vos tenés que escribir los montos de este mes. Si abajo aparece "Anterior: \$...", es solo de referencia del mes pasado.',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
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
                        decoration: InputDecoration(
                          labelText: '1° Vencimiento (1-10)',
                          prefixText: '\$ ',
                          isDense: true,
                          hintText: 'Escribí el monto',
                          helperText: previos[nivel]![0] != null
                              ? 'Anterior: \$${previos[nivel]![0]} (ingresá el monto actualizado)'
                              : null,
                          helperStyle: const TextStyle(color: Color(0xFF757575), fontSize: 11),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controllers[nivel]![1],
                        decoration: InputDecoration(
                          labelText: '2° Vencimiento (11-20)',
                          prefixText: '\$ ',
                          isDense: true,
                          hintText: 'Escribí el monto',
                          helperText: previos[nivel]![1] != null
                              ? 'Anterior: \$${previos[nivel]![1]} (ingresá el monto actualizado)'
                              : null,
                          helperStyle: const TextStyle(color: Color(0xFF757575), fontSize: 11),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controllers[nivel]![2],
                        decoration: InputDecoration(
                          labelText: '3° Vencimiento (21-31)',
                          prefixText: '\$ ',
                          isDense: true,
                          hintText: 'Escribí el monto',
                          helperText: previos[nivel]![2] != null
                              ? 'Anterior: \$${previos[nivel]![2]} (ingresá el monto actualizado)'
                              : null,
                          helperStyle: const TextStyle(color: Color(0xFF757575), fontSize: 11),
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
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 48),
                  title: const Text('¿Seguro que querés omitir?', textAlign: TextAlign.center),
                  content: const Text(
                    'Si omitís, el sistema va a seguir usando los montos del mes anterior. '
                    'Esto puede hacer que las cuotas nuevas y los recargos salgan MAL.\n\n'
                    'Solo omitas si ya los configuraste antes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('NO, volver a configurar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sí, omitir', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              );
              if (confirmar == true && context.mounted) {
                Navigator.pop(context, false);
              }
            },
            child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('GUARDAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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

  Widget _buildBannerConfigMontos() {
    final ahora = DateTime.now();
    final nombreMes = ConfigCuotasPeriodo.nombreMes(ahora.month);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFFF6F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IMPORTANTE — LEER CADA MES',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cada 1° de mes tenés que CONFIGURAR los montos de cuotas de $nombreMes ${ahora.year}.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PASO A PASO:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                SizedBox(height: 6),
                Text('1. Tocá el botón del calendario 📅 arriba a la derecha.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                Text('2. Poné los 3 montos REALES (1°, 2° y 3° vencimiento) para CADA año.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                Text('3. Confirmá que los montos son los correctos de ESTE mes.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                Text('4. Tocá GUARDAR (NO toques "Omitir").',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.yellowAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Si los montos están mal, TODO el sistema cobra mal: cuotas nuevas, PDFs y recargos.',
                    style: TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.rule, color: Color(0xFFD32F2F), size: 18),
                    SizedBox(width: 6),
                    Text('REGLA DE PAGO EN OTRO MES',
                        style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Si un alumno paga una cuota atrasada en otro mes, se cobra con el 3° VENCIMIENTO del mes en el que está pagando.',
                  style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _showMonthlyConfigPopup(['Primer Año', 'Segundo Año', 'Tercer Año'], forcePrompt: true);
              },
              icon: const Icon(Icons.edit_calendar),
              label: Text('CONFIGURAR MONTOS DE ${nombreMes.toUpperCase()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionCuotasInscripciones() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBannerConfigMontos(),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAccionCompacta(
                  titulo: 'Usuarios',
                  icon: Icons.admin_panel_settings,
                  color: Colors.purple,
                  onTap: () => Navigator.pushNamed(context, '/admin/usuarios'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
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
          // Primer Año - Sin asignar
          _buildDivisionExpansion(
            nivel: 'Primer Año',
            division: 'sin_asignar',
            color: Colors.orange,
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
        if (division == 'sin_asignar') {
          return a.division == null || a.division!.isEmpty;
        }
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
