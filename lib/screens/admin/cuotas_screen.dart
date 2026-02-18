import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../models/alumno.dart';
import '../../models/cuota.dart';
import '../../models/config_cuotas_periodo.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';

class CuotasScreen extends StatefulWidget {
  const CuotasScreen({super.key});

  @override
  State<CuotasScreen> createState() => _CuotasScreenState();
}

class _CuotasScreenState extends State<CuotasScreen> {
  final SupabaseService _db = SupabaseService.instance;
  final AuthService _auth = AuthService.instance;
  final Map<String, Alumno?> _alumnos = {};
  List<Cuota> _cuotas = [];
  bool _isLoading = true;
  String _busqueda = '';
  String _filtroEstado = '';
  String _filtroNivel = '';
  String _filtroDivision = '';
  int _filtroAnio = DateTime.now().year;
  bool _generandoTodos = false;
  List<Alumno> _alumnosDisponibles = [];
  bool _vistaCalendario = true; // Vista calendario por defecto
  final Map<String, bool> _gruposExpandidos = {}; // Control de grupos plegables

  @override
  void initState() {
    super.initState();
    _verificarPermisos();
  }

  bool get _puedeGestionarPagos => _auth.userRole == 'admin' || _auth.userRole == 'superadmin';

  Future<void> _verificarPermisos() async {
    if (!_puedeGestionarPagos) {
      // Regresar si no tiene permisos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo administradores pueden ver las cuotas')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _loadCuotas();
  }

  Future<void> _loadCuotas() async {
    setState(() => _isLoading = true);
    try {
      // Cargar cuotas y alumnos en paralelo (2 queries en vez de N)
      final results = await Future.wait([
        _db.getAllCuotas(),
        _db.getAllAlumnos(),
      ]);
      final cuotas = results[0] as List<Cuota>;
      final todosAlumnos = results[1] as List<Alumno>;

      // Indexar alumnos por id de una sola vez
      final alumnoMap = <String, Alumno>{};
      for (final a in todosAlumnos) {
        if (a.id != null) alumnoMap[a.id!] = a;
      }

      // Filtrar por año
      final cuotasFiltradas = cuotas.where((c) => c.anio == _filtroAnio).toList();

      // Recopilar configs necesarias y cargarlas en paralelo
      final configKeys = <String, Future<ConfigCuotasPeriodo?>>{};
      for (final cuota in cuotasFiltradas) {
        final alumno = alumnoMap[cuota.alumnoId];
        if (alumno != null) {
          final cacheKey = '${alumno.nivelInscripcion}_${cuota.mes}_${cuota.anio}';
          if (!configKeys.containsKey(cacheKey)) {
            configKeys[cacheKey] = _db.getConfigCuotasPeriodo(
              nivel: alumno.nivelInscripcion,
              mes: cuota.mes,
              anio: cuota.anio,
            );
          }
        }
      }
      final configResults = <String, ConfigCuotasPeriodo?>{};
      final keys = configKeys.keys.toList();
      final values = await Future.wait(configKeys.values);
      for (int i = 0; i < keys.length; i++) {
        configResults[keys[i]] = values[i];
      }

      // Aplicar días de rango
      for (int i = 0; i < cuotasFiltradas.length; i++) {
        final cuota = cuotasFiltradas[i];
        final alumno = alumnoMap[cuota.alumnoId];
        if (alumno != null) {
          final cacheKey = '${alumno.nivelInscripcion}_${cuota.mes}_${cuota.anio}';
          final config = configResults[cacheKey];
          cuotasFiltradas[i] = cuota.copyWith(
            diaFinRangoA: config?.diaFinRangoA ?? 10,
            diaFinRangoB: config?.diaFinRangoB ?? 20,
          );
        }
      }

      // Actualizar mapa de alumnos sin fotos para mostrar rápido
      _alumnos.addAll(alumnoMap.map((k, v) => MapEntry(k, v)));
      _alumnosDisponibles = todosAlumnos;
      setState(() {
        _cuotas = cuotasFiltradas;
        _isLoading = false;
      });

      // Cargar fotos en background sin bloquear la UI
      _loadFotosEnBackground(cuotasFiltradas, alumnoMap);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFotosEnBackground(List<Cuota> cuotas, Map<String, Alumno> alumnoMap) async {
    final alumnoIdsConFoto = <String>{};
    for (final cuota in cuotas) {
      final alumno = alumnoMap[cuota.alumnoId];
      if (alumno != null && alumno.fotoAlumno != null && alumno.fotoAlumno!.isNotEmpty) {
        alumnoIdsConFoto.add(cuota.alumnoId);
      }
    }
    for (final id in alumnoIdsConFoto) {
      final alumno = alumnoMap[id];
      if (alumno == null) continue;
      final signed = await _db.getSignedFotoAlumno(alumno.fotoAlumno);
      if (signed != null && mounted) {
        _alumnos[id] = alumno.copyWith(fotoAlumno: signed);
      }
    }
    if (mounted) setState(() {});
  }

  List<Cuota> get _cuotasFiltradas {
    Iterable<Cuota> resultado = _cuotas;

    if (_filtroEstado.isNotEmpty) {
      resultado = resultado.where((c) => _estadoCuota(c) == _filtroEstado);
    }

    resultado = resultado.where((c) => c.anio == _filtroAnio);

    if (_filtroNivel.isNotEmpty) {
      resultado = resultado.where((c) {
        final alumno = _alumnos[c.alumnoId];
        return alumno?.nivelInscripcion == _filtroNivel;
      });
    }

    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      resultado = resultado.where((c) {
        final alumno = _alumnos[c.alumnoId];
        final nombre = alumno?.nombreCompleto.toLowerCase() ?? '';
        final codigo = alumno?.codigoInscripcion?.toLowerCase() ?? '';
        final dni = alumno?.dni.toLowerCase() ?? '';
        return nombre.contains(query) ||
            codigo.contains(query) ||
            dni.contains(query) ||
            c.concepto.toLowerCase().contains(query);
      });
    }

    final lista = resultado.toList();

    // Ordenar por apellido / nombre y vencimiento
    lista.sort((a, b) {
      final alumnoA = _alumnos[a.alumnoId];
      final alumnoB = _alumnos[b.alumnoId];
      final nombreA = alumnoA?.apellido.toLowerCase() ?? '';
      final nombreB = alumnoB?.apellido.toLowerCase() ?? '';
      final cmpNombre = nombreA.compareTo(nombreB);
      if (cmpNombre != 0) return cmpNombre;
      return a.fechaVencimiento.compareTo(b.fechaVencimiento);
    });

    return lista;
  }

  String _estadoCuota(Cuota cuota) {
    if (cuota.estaPagada) return 'pagada';
    // Parcial tiene prioridad sobre vencida para que el pago se refleje
    if (cuota.esParcial) return 'parcial';
    if (cuota.estaVencida || cuota.estado == 'vencida') return 'vencida';
    return 'pendiente';
  }

  String _formatMoney(num amount) {
    return '\$${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // Estadísticas
  Map<String, dynamic> get _estadisticas {
    final ahora = DateTime.now();
    final mesActual = ahora.month;
    final anioActual = ahora.year;

    int totalCobrado = 0;        // Todo lo que ya entró
    int totalPorCobrar = 0;      // Todo lo que falta cobrar
    int totalFacturacion = 0;    // Total que debería entrar

    // Por categoría - mostramos deuda pendiente por estado
    int montoPagadas = 0;        // Monto de cuotas completamente pagadas
    int montoParciales = 0;      // Lo que se cobró de cuotas parciales
    int deudaParciales = 0;      // Lo que falta de cuotas parciales
    int deudaPendientes = 0;     // Deuda de cuotas pendientes (no vencidas)
    int deudaVencidas = 0;       // Deuda de cuotas vencidas
    int cobradoVencidas = 0;     // Pagos parciales en cuotas vencidas

    int cantPagadas = 0;
    int cantParciales = 0;
    int cantPendientes = 0;
    int cantVencidas = 0;

    // Sólo cuotas del mes y año vigentes
    final cuotasMesActual = _cuotas.where((c) => c.mes == mesActual && c.anio == anioActual);

    for (final cuota in cuotasMesActual) {
      totalCobrado += cuota.montoPagado;
      totalPorCobrar += cuota.deuda;
      totalFacturacion += cuota.montoActual;

      final estado = _estadoCuota(cuota);
      switch (estado) {
        case 'pagada':
          cantPagadas++;
          montoPagadas += cuota.montoPagado; // Usar montoPagado para consistencia
          break;
        case 'parcial':
          cantParciales++;
          montoParciales += cuota.montoPagado;
          deudaParciales += cuota.deuda;
          break;
        case 'vencida':
          cantVencidas++;
          deudaVencidas += cuota.deuda;
          cobradoVencidas += cuota.montoPagado; // Capturar pagos parciales en vencidas
          break;
        default:
          cantPendientes++;
          deudaPendientes += cuota.deuda;
      }
    }

    return {
      // Totales generales
      'totalCobrado': totalCobrado,
      'totalPorCobrar': totalPorCobrar,
      'totalFacturacion': totalFacturacion,
      // Por categoría
      'montoPagadas': montoPagadas,
      'montoParciales': montoParciales,
      'deudaParciales': deudaParciales,
      'deudaPendientes': deudaPendientes,
      'deudaVencidas': deudaVencidas,
      'cobradoVencidas': cobradoVencidas,
      // Cantidades
      'cantPagadas': cantPagadas,
      'cantParciales': cantParciales,
      'cantPendientes': cantPendientes,
      'cantVencidas': cantVencidas,
    };
  }

  bool _mostrarAcciones = false;

  @override
  Widget build(BuildContext context) {
    final stats = _estadisticas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de cuotas'),
        actions: [
          IconButton(
            icon: Icon(_vistaCalendario ? Icons.list : Icons.calendar_view_month),
            tooltip: _vistaCalendario ? 'Vista lista' : 'Vista calendario',
            onPressed: () => setState(() => _vistaCalendario = !_vistaCalendario),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCuotas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCuotas,
              child: CustomScrollView(
                slivers: [
                  // Panel de acciones
                  SliverToBoxAdapter(
                    child: _buildPanelAcciones(),
                  ),

                  // Resumen compacto
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      child: Row(
                        children: [
                          _buildMiniStat('Cobrado', stats['totalCobrado'], AppTheme.successColor),
                          _buildMiniStat('Por cobrar', stats['totalPorCobrar'], AppTheme.dangerColor),
                          _buildMiniStat('Total', stats['totalFacturacion'], AppTheme.primaryColor),
                        ],
                      ),
                    ),
                  ),

                  // Filtros compactos
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 40,
                            child: TextField(
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Buscar alumno...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              onChanged: (v) => setState(() => _busqueda = v),
                            ),
                          ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                                _buildMiniChip('1°A', 'Primer Año', division: 'A'),
                                _buildMiniChip('1°B', 'Primer Año', division: 'B'),
                                _buildMiniChip('2°', 'Segundo Año'),
                                _buildMiniChip('3°', 'Tercer Año'),
                                const SizedBox(width: 8),
                                _buildEstadoChip('✓', 'pagada', AppTheme.successColor),
                    _buildEstadoChip('◐', 'parcial', Colors.orange),
                    _buildEstadoChip('○', 'pendiente', AppTheme.warningColor),
                    _buildEstadoChip('!', 'vencida', AppTheme.dangerColor),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upgrade, size: 16),
                      label: const Text('Promocionar alumnos'),
                      onPressed: _abrirPromocionarAlumnos,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.undo, size: 16, color: Colors.red),
                      label: const Text('Deshacer promoción', style: TextStyle(color: Colors.red)),
                      onPressed: _deshacerPromocion,
                    ),
                  ],
                ),
              ),
            ],
          ),
                  ),
                ),

                // Leyenda
                if (_vistaCalendario)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Año: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              DropdownButton<int>(
                                value: _filtroAnio,
                                items: [
                                  for (final a in [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1])
                                    DropdownMenuItem(value: a, child: Text('$a')),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _filtroAnio = v);
                                  _loadCuotas();
                                },
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _buildLeyendaItem('✓', AppTheme.successColor, 'Pagada'),
                              _buildLeyendaItem('◐', Colors.orange, 'Parcial'),
                              _buildLeyendaItem('○', Colors.grey.shade500, 'Pendiente'),
                              _buildLeyendaItem('!', AppTheme.dangerColor, 'Vencida'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _abrirGenerarMensuales,
                                  icon: const Icon(Icons.playlist_add),
                                  label: const Text('Generar/Completar cuotas del año'),
                                ),
                                TextButton.icon(
                                  onPressed: _generandoTodos ? null : _generarCuotasParaTodos,
                                  icon: _generandoTodos
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.group_add),
                                  label: const Text('Generar para todos'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contenido principal
                  if (_vistaCalendario)
                    _buildVistaCalendario()
                  else
                    _buildVistaLista(),
                  // Espacio inferior para evitar contenido pegado al borde en scroll
                  SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildPanelAcciones() {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // === GESTIÓN DE PAGOS ===
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payments, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Text('Gestión de Pagos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildBotonGestion(
                          icon: Icons.add_circle,
                          label: 'Ingresar\nPago',
                          color: AppTheme.successColor,
                          onTap: _abrirIngresarPago,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBotonGestion(
                          icon: Icons.receipt_long,
                          label: 'Detalle\nAlumno',
                          color: Colors.blue,
                          onTap: _abrirGenerarPDF,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBotonGestion(
                          icon: Icons.bar_chart,
                          label: 'Totales\npor Mes',
                          color: Colors.orange,
                          onTap: _abrirTotalesPorMes,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // === GENERAR CUOTAS ===
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _mostrarAcciones = !_mostrarAcciones),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: _mostrarAcciones
                          ? const BorderRadius.vertical(top: Radius.circular(12))
                          : BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_card, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Generar Cuotas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Icon(_mostrarAcciones ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                if (_mostrarAcciones)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildAccionCard(
                          icon: Icons.school,
                          color: Colors.purple,
                          titulo: 'Inscripción 1° Año',
                          subtitulo: 'Cuota única de inscripción',
                          onTap: _abrirGenerarCuotas,
                        ),
                        const SizedBox(height: 10),
                        _buildAccionCard(
                          icon: Icons.calendar_month,
                          color: Colors.blue,
                          titulo: 'Cuotas Mensuales',
                          subtitulo: '1° año: Mar-Dic  •  2°/3° año: Ene-Dic',
                          onTap: _abrirGenerarMensuales,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                          child: _buildAccionMini(
                            icon: Icons.tune,
                            label: 'Ajustar montos',
                            onTap: _abrirAjustarMes,
                          ),
                        ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildAccionMini(
                                icon: Icons.access_time,
                                label: 'Vencimientos',
                                onTap: _abrirConfigVencimientos,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildAccionMini(
                          icon: Icons.cleaning_services,
                          label: 'Limpiar cuotas duplicadas',
                          onTap: _abrirLimpiarCuotas,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonGestion({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccionCard({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccionMini({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Colors.grey.shade700;
    return Material(
      color: color != null ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: c),
              const SizedBox(width: 8),
              Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: c))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeyendaItem(String symbol, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(child: Text(symbol, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildMiniStat(String label, num value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Text(_formatMoney(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, String nivel, {String? division}) {
    final isSelected = _filtroNivel == nivel && (division == null || _filtroDivision == division);
    final tooltip = division != null ? 'Filtrar $nivel Division $division' : 'Filtrar $nivel';
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => setState(() {
            if (isSelected) {
              _filtroNivel = '';
              _filtroDivision = '';
            } else {
              _filtroNivel = nivel;
              _filtroDivision = division ?? '';
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade700)),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoChip(String symbol, String estado, Color color) {
    final isSelected = _filtroEstado == estado;
    final tooltips = {
      'pagada': 'Filtrar cuotas pagadas',
      'parcial': 'Filtrar cuotas con pago parcial',
      'pendiente': 'Filtrar cuotas pendientes de pago',
      'vencida': 'Filtrar cuotas vencidas sin pagar',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltips[estado] ?? estado,
        child: InkWell(
          onTap: () => setState(() => _filtroEstado = isSelected ? '' : estado),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(symbol, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : color))),
          ),
        ),
      ),
    );
  }

  // Vista calendario tipo tabla
  Widget _buildVistaCalendario() {
    // Agrupar alumnos por nivel y división
    final grupos = <String, List<Alumno>>{};
    for (final alumno in _alumnosDisponibles) {
      if (_busqueda.isNotEmpty) {
        final query = _busqueda.toLowerCase();
        if (!alumno.nombreCompleto.toLowerCase().contains(query) && !alumno.dni.toLowerCase().contains(query)) continue;
      }
      if (_filtroNivel.isNotEmpty && alumno.nivelInscripcion != _filtroNivel) continue;
      if (_filtroDivision.isNotEmpty && alumno.division != _filtroDivision) continue;

      String grupo;
      if (alumno.nivelInscripcion == 'Primer Año') {
        grupo = '1° ${alumno.division ?? 'S/D'}';
      } else if (alumno.nivelInscripcion == 'Segundo Año') {
        grupo = '2° Año';
      } else {
        grupo = '3° Año';
      }
      grupos.putIfAbsent(grupo, () => []);
      grupos[grupo]!.add(alumno);
    }

    // Ordenar grupos
    final gruposOrdenados = ['1° A', '1° B', '1° S/D', '2° Año', '3° Año'].where((g) => grupos.containsKey(g)).toList();

    if (gruposOrdenados.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No hay alumnos', style: TextStyle(color: Colors.grey.shade600))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final grupo = gruposOrdenados[index];
          final alumnos = grupos[grupo]!..sort((a, b) {
            final cmp = a.apellido.toLowerCase().compareTo(b.apellido.toLowerCase());
            if (cmp != 0) return cmp;
            return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
          });
          return _buildGrupoCalendario(grupo, alumnos);
        },
        childCount: gruposOrdenados.length,
      ),
    );
  }

  Widget _buildGrupoCalendario(String grupo, List<Alumno> alumnos) {
    final esPrimerAnio = grupo.startsWith('1°');
    final meses = esPrimerAnio
        ? [
            {'mes': 0, 'label': 'INSC'},
            {'mes': 3, 'label': 'Mar'},
            {'mes': 4, 'label': 'Abr'},
            {'mes': 5, 'label': 'May'},
            {'mes': 6, 'label': 'Jun'},
            {'mes': 7, 'label': 'Jul'},
            {'mes': 8, 'label': 'Ago'},
            {'mes': 9, 'label': 'Sep'},
            {'mes': 10, 'label': 'Oct'},
            {'mes': 11, 'label': 'Nov'},
            {'mes': 12, 'label': 'Dic'},
          ]
        : [
            {'mes': 1, 'label': 'Ene'},
            {'mes': 2, 'label': 'Feb'},
            {'mes': 3, 'label': 'Mar'},
            {'mes': 4, 'label': 'Abr'},
            {'mes': 5, 'label': 'May'},
            {'mes': 6, 'label': 'Jun'},
            {'mes': 7, 'label': 'Jul'},
            {'mes': 8, 'label': 'Ago'},
            {'mes': 9, 'label': 'Sep'},
            {'mes': 10, 'label': 'Oct'},
            {'mes': 11, 'label': 'Nov'},
            {'mes': 12, 'label': 'Dic'},
          ];

    final expandido = _gruposExpandidos[grupo] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header clickeable del grupo
        InkWell(
          onTap: () => setState(() => _gruposExpandidos[grupo] = !expandido),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppTheme.primaryColor,
            child: Row(
              children: [
                Icon(
                  expandido ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white, size: 20,
                ),
                const SizedBox(width: 4),
                Text(grupo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text('${alumnos.length} alumnos', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
        // Contenido colapsable
        if (expandido) ...[
          // Header de meses
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 130, child: Padding(padding: EdgeInsets.only(left: 8), child: Text('ALUMNO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)))),
                ...meses.map((b) => SizedBox(
                  width: 38,
                  child: Center(child: Text(b['label'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                )),
                const SizedBox(width: 55, child: Center(child: Text('DEUDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)))),
              ],
            ),
          ),
          // Filas de alumnos
          ...alumnos.map((alumno) => _buildFilaAlumno(alumno, meses)),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildFilaAlumno(Alumno alumno, List<Map<String, dynamic>> meses) {
    final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumno.id).toList();
    int deudaTotal = cuotasAlumno.fold(0, (sum, c) => sum + c.deuda);

    // Filtrar por estado si hay filtro
    if (_filtroEstado.isNotEmpty) {
      final tieneEstado = cuotasAlumno.any((c) => _estadoCuota(c) == _filtroEstado);
      if (!tieneEstado) return const SizedBox.shrink();
    }

    // Si no hay cuotas en el año seleccionado, mostrar aviso con acción para generarlas
    if (cuotasAlumno.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'El alumno ${alumno.nombreCompleto} no tiene cuotas en $_filtroAnio.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: () => _generarCuotasParaAlumno(alumno),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Generar cuotas'),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _mostrarDetallePago(alumno),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          color: deudaTotal > 0 ? AppTheme.dangerColor.withOpacity(0.03) : null,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Nombre
              SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${alumno.apellido}, ${alumno.nombre.split(' ').first}',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Celdas de meses
              ...meses.map((b) {
                final mes = b['mes'] as int;
                Cuota? cuota;
                if (mes == 0) {
                  // Inscripción
                  cuota = cuotasAlumno.where((c) => c.concepto.toLowerCase().contains('inscripción')).firstOrNull;
                } else {
                  cuota = cuotasAlumno.where((c) => c.mes == mes && !c.concepto.toLowerCase().contains('inscripción')).firstOrNull;
                }
                return _buildCeldaEstado(cuota, alumno);
              }),
              // Deuda
              SizedBox(
                width: 70,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    deudaTotal > 0 ? _formatMoney(deudaTotal) : '',
                    style: TextStyle(fontSize: 11, color: deudaTotal > 0 ? AppTheme.dangerColor : Colors.grey, fontWeight: deudaTotal > 0 ? FontWeight.bold : FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildCeldaEstado(Cuota? cuota, Alumno alumno) {
  Color color;
  String symbol;
    if (cuota == null) {
      color = Colors.grey.shade300;
      symbol = '';
    } else if (cuota.estaPagada) {
      color = AppTheme.successColor;
      symbol = '✓';
    } else if (cuota.esParcial) {
      color = Colors.orange;
      symbol = '◐';
    } else if (cuota.estaVencida) {
      color = AppTheme.dangerColor;
      symbol = '!';
    } else {
      color = Colors.grey.shade400;
      symbol = '○';
    }

    return GestureDetector(
      onTap: cuota != null ? () => _mostrarOpcionesCuota(cuota, alumno) : null,
      child: Container(
        width: 42,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(cuota == null ? 0.3 : 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: Text(symbol, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
      ),
  );
}

  String _tituloCuota(Cuota cuota) {
    if (cuota.mes == 0 || cuota.concepto.toLowerCase().contains('inscripción')) {
      return 'Inscripción ${cuota.anio}';
    }
    return 'Cuota ${Cuota.nombreMes(cuota.mes)} ${cuota.anio}';
  }

  Future<void> _generarCuotasParaAlumno(Alumno alumno) async {
    if (alumno.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El alumno no tiene ID válido'), backgroundColor: Colors.red),
      );
      return;
    }

    final cuotasAntes = _cuotas.where((c) => c.alumnoId == alumno.id && c.anio == _filtroAnio).length;
    try {
      await _db.generarCuotasDesdeConfig(alumno.id!, _filtroAnio);
      await _loadCuotas();
      if (mounted) {
        final cuotasDespues = _cuotas.where((c) => c.alumnoId == alumno.id && c.anio == _filtroAnio).length;
        if (cuotasDespues > cuotasAntes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuotas generadas con la configuración del año'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se generaron cuotas. Revisa la configuración de montos de ${alumno.nivelInscripcion ?? ''} para $_filtroAnio.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron generar cuotas: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generarCuotasParaTodos() async {
    if (_generandoTodos) return;
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    // Contar cuotas actuales por alumno/año para saber si luego se agregaron
    final countsBefore = <String, int>{};
    for (final c in _cuotas.where((c) => c.anio == _filtroAnio)) {
      countsBefore[c.alumnoId] = (countsBefore[c.alumnoId] ?? 0) + 1;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar cuotas para todos'),
        content: Text('Se generarán las cuotas del año $_filtroAnio para todos los alumnos usando la configuración mensual. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _generandoTodos = true);
    int yaExistian = 0;
    int errores = 0;
    final skipPorFaltaConfig = <String,int>{}; // nivel -> meses sin config

    for (final alumno in _alumnosDisponibles) {
      final id = alumno.id;
      if (id == null) {
        errores++;
        continue;
      }
      try {
        await _db.generarCuotasDesdeConfig(id, _filtroAnio);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('Ya existen cuotas') || msg.contains('ya existen cuotas')) {
          yaExistian++;
        } else if (msg.contains('No hay configuración de montos')) {
          final nivel = alumno.nivelInscripcion;
          skipPorFaltaConfig[nivel] = (skipPorFaltaConfig[nivel] ?? 0) + 1;
        } else {
          errores++;
        }
      }
    }

    await _loadCuotas();

    // Calcular cuántas nuevas se sumaron por alumno/año
    final countsAfter = <String, int>{};
    for (final c in _cuotas.where((c) => c.anio == _filtroAnio)) {
      countsAfter[c.alumnoId] = (countsAfter[c.alumnoId] ?? 0) + 1;
    }
    int generadas = 0;
    int sinNuevas = 0;
    for (final alumno in _alumnosDisponibles) {
      final id = alumno.id;
      if (id == null) continue;
      final before = countsBefore[id] ?? 0;
      final after = countsAfter[id] ?? 0;
      if (after > before) {
        generadas += (after - before);
      } else {
        sinNuevas++;
      }
    }

    if (mounted) {
      final skipMsg = skipPorFaltaConfig.entries.isNotEmpty
          ? ' | Sin config: ' + skipPorFaltaConfig.entries.map((e) => '${e.key} (${e.value})').join(', ')
          : '';
      final sinMsg = sinNuevas > 0 ? ' | Sin nuevas: $sinNuevas alumnos (revisar config del año)' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generadas: $generadas • Ya existían: $yaExistian • Errores: $errores$skipMsg$sinMsg'),
          backgroundColor: errores > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
    setState(() => _generandoTodos = false);
  }


  void _mostrarOpcionesCuota(Cuota cuota, Alumno alumno) {
    if (cuota.estaPagada) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alumno.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${cuota.concepto} - PAGADA', style: TextStyle(color: AppTheme.successColor)),
              const SizedBox(height: 8),
              Text('Monto pagado: ${_formatMoney(cuota.montoPagado)}'),
              if (cuota.fechaPago != null) Text('Fecha: ${DateFormat('dd/MM/yyyy').format(cuota.fechaPago!)}'),
              if (cuota.metodoPago != null) Text('Método: ${cuota.metodoPago}'),
              if (cuota.numRecibo != null && cuota.numRecibo!.isNotEmpty) Text('Recibo: ${cuota.numRecibo}'),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alumno.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_tituloCuota(cuota), style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Monto: ${_formatMoney(cuota.montoActual)}'),
                const SizedBox(width: 16),
                if (cuota.montoPagado > 0) Text('Pagado: ${_formatMoney(cuota.montoPagado)}', style: TextStyle(color: AppTheme.successColor)),
                const SizedBox(width: 16),
                Text('Debe: ${_formatMoney(cuota.deuda)}', style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _registrarPagoParcial(cuota);
                    },
                    child: const Text('Pago Parcial'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _registrarPagoTotal(cuota);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                    child: const Text('Pago Total'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editarMonto(cuota);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar Montos'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editarMontoMes(cuota);
                    },
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Editar Mes'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetallePago(Alumno alumno) async {
    final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumno.id).toList()
      ..sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    if (cuotasAlumno.isEmpty) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sin cuotas generadas'),
          content: Text(
            'El alumno ${alumno.nombreCompleto} no tiene cuotas para este año.\n\n¿Generar con los montos configurados?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generar'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        try {
          final alumnoId = alumno.id;
          if (alumnoId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('El alumno no tiene ID válido'), backgroundColor: Colors.red),
            );
            return;
          }
          await _db.generarCuotasDesdeConfig(alumnoId!, DateTime.now().year);
          await _loadCuotas();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cuotas generadas con la configuración actual'), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudieron generar cuotas: ${e.toString()}'), backgroundColor: Colors.red),
            );
          }
        }
      }
      return;
    }

    final pdfData = await PdfService.generarDetalleCuotas(alumno, cuotasAlumno);
    if (mounted) {
      final nombreSeguro = '${alumno.apellido}_${alumno.nombre}'.replaceAll(' ', '_');
      final anio = DateTime.now().year;
      await Printing.layoutPdf(onLayout: (_) => pdfData, name: 'EstadoCuenta_${nombreSeguro}_$anio.pdf');
    }
  }

  // Vista lista compacta
  Widget _buildVistaLista() {
    if (_cuotasFiltradas.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No hay cuotas', style: TextStyle(color: Colors.grey.shade600))),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cuota = _cuotasFiltradas[index];
            final alumno = _alumnos[cuota.alumnoId];
            return _buildCuotaCardCompacta(cuota, alumno);
          },
          childCount: _cuotasFiltradas.length,
        ),
      ),
    );
  }

  Widget _buildCuotaCardCompacta(Cuota cuota, Alumno? alumno) {
    final estado = _estadoCuota(cuota);
    final color = estado == 'pagada' ? AppTheme.successColor : estado == 'parcial' ? Colors.orange : estado == 'vencida' ? AppTheme.dangerColor : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alumno?.nombreCompleto ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(cuota.concepto, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatMoney(cuota.montoActual), style: const TextStyle(fontSize: 12)),
              if (cuota.deuda > 0 && !cuota.estaPagada)
                Text('Debe: ${_formatMoney(cuota.deuda)}', style: TextStyle(fontSize: 10, color: AppTheme.dangerColor)),
            ],
          ),
          const SizedBox(width: 8),
          if (!cuota.estaPagada)
            IconButton(
              icon: Icon(Icons.payment, color: AppTheme.successColor, size: 20),
              onPressed: () => _registrarPagoTotal(cuota),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
        ],
      ),
    );
  }

  Future<void> _abrirGenerarCuotas() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    // Filtrar solo alumnos de primer año
    final alumnosPrimerAnio = _alumnosDisponibles.where((a) => a.nivelInscripcion == 'Primer Año').toList();

    if (alumnosPrimerAnio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay alumnos de primer año para generar inscripción'), backgroundColor: Colors.orange),
      );
      return;
    }

    final alumnoSeleccionado = ValueNotifier<String?>(alumnosPrimerAnio.first.id);
    final inscripcionController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuota de inscripción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Genera la cuota de inscripción para alumnos de primer año.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String?>(
              valueListenable: alumnoSeleccionado,
              builder: (_, value, __) {
                return DropdownButtonFormField<String>(
                  value: value,
                  items: alumnosPrimerAnio
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.nombreCompleto} (${a.division ?? "S/D"})'),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Alumno de 1° año'),
                  onChanged: (v) => alumnoSeleccionado.value = v,
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inscripcionController,
              decoration: const InputDecoration(
                labelText: 'Monto de inscripción',
                prefixText: '\$ ',
                helperText: 'Se genera una sola vez por alumno',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generar'),
          ),
        ],
      ),
    );

    if (confirmar == true && alumnoSeleccionado.value != null) {
      final montoInsc = int.tryParse(inscripcionController.text) ?? 0;
      if (montoInsc <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
        );
        return;
      }
      try {
        await _db.generarCuotaInscripcion(
          alumnoSeleccionado.value!,
          montoInsc,
        );
        await _loadCuotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuota de inscripción generada'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El alumno ya tiene una cuota de inscripción'), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }

  Future<void> _abrirGenerarMensuales() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    final alumnoSeleccionado = ValueNotifier<String?>(_alumnosDisponibles.isNotEmpty ? _alumnosDisponibles.first.id : null);
    final montoAlDiaController = TextEditingController();
    final monto1erVtoController = TextEditingController();
    final monto2doVtoController = TextEditingController();
    final anioController = TextEditingController(text: DateTime.now().year.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuotas Mensuales'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se generan cuotas mensuales: 1° año Mar-Dic, 2°/3° año Ene-Dic.',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String?>(
                valueListenable: alumnoSeleccionado,
                builder: (_, value, __) {
                  Alumno? alumnoActual;
                  try {
                    alumnoActual = _alumnosDisponibles.firstWhere((a) => a.id == value);
                  } catch (_) {}
                  final nivel = alumnoActual?.nivelInscripcion ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: value,
                        isExpanded: true,
                        items: _alumnosDisponibles
                            .map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.nombreCompleto} (${a.nivelInscripcion == 'Primer Año' ? '1°' : a.nivelInscripcion == 'Segundo Año' ? '2°' : '3°'})'),
                            ))
                            .toList(),
                        decoration: const InputDecoration(labelText: 'Alumno'),
                        onChanged: (v) => alumnoSeleccionado.value = v,
                      ),
                      if (nivel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: nivel == 'Primer Año' ? Colors.purple.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            nivel == 'Primer Año'
                                ? 'Se generarán 10 cuotas (Mar-Dic)'
                                : 'Se generarán 12 cuotas (Ene-Dic)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: nivel == 'Primer Año' ? Colors.purple.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Montos de vencimiento (enteros):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: montoAlDiaController,
                decoration: const InputDecoration(
                  labelText: '1° Vencimiento (1-10)',
                  prefixText: '\$ ',
                  hintText: 'Ej: 15000',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(
                  labelText: '2° Vencimiento (11-20)',
                  prefixText: '\$ ',
                  hintText: 'Ej: 16500',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(
                  labelText: '3° Vencimiento (21-31)',
                  prefixText: '\$ ',
                  hintText: 'Ej: 18000',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: anioController,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Generar'),
          ),
        ],
      ),
    );

    if (confirmar == true && alumnoSeleccionado.value != null) {
      final montoAlDia = int.tryParse(montoAlDiaController.text) ?? 0;
      final monto1erVto = int.tryParse(monto1erVtoController.text) ?? montoAlDia;
      final monto2doVto = int.tryParse(monto2doVtoController.text) ?? monto1erVto;
      final anio = int.tryParse(anioController.text) ?? DateTime.now().year;
      if (montoAlDia <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
        );
        return;
      }
      try {
        await _db.generarCuotasMensuales(
          alumnoSeleccionado.value!,
          montoAlDia,
          anio,
          monto1erVto: monto1erVto,
          monto2doVto: monto2doVto,
        );
        await _loadCuotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuotas mensuales generadas'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _abrirAjustarMes({int? mesInicial, int? anioInicial}) async {
    final montoAlDiaController = TextEditingController();
    final monto1erVtoController = TextEditingController();
    final monto2doVtoController = TextEditingController();
    final anioController = TextEditingController(text: (anioInicial ?? DateTime.now().year).toString());
    final mesController = ValueNotifier<int>(mesInicial ?? DateTime.now().month);
    final soloPendientes = ValueNotifier<bool>(true);
    final incluirVencidas = ValueNotifier<bool>(true);

    Future<void> _cargarConfig(int mes, int anio, void Function(void Function()) setStateDialog) async {
      final cfg = await _db.getConfigCuotasPeriodo(nivel: 'Primer Año', mes: mes, anio: anio);
      setStateDialog(() {
        montoAlDiaController.text = cfg?.montoAlDia.toString() ?? '';
        monto1erVtoController.text = cfg?.monto1erVto.toString() ?? '';
        monto2doVtoController.text = cfg?.monto2doVto.toString() ?? '';
      });
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Cargar config inicial
          _cargarConfig(mesController.value, int.tryParse(anioController.text) ?? DateTime.now().year, setStateDialog);
          return AlertDialog(
            title: const Text('Ajustar montos del mes'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Actualiza los montos de las cuotas de un mes.'),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: mesController,
                    builder: (_, value, __) {
                      return DropdownButtonFormField<int>(
                        value: value,
                        decoration: const InputDecoration(labelText: 'Mes'),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(value: m, child: Text(Cuota.nombreMes(m))))
                            .toList(),
                        onChanged: (v) {
                          mesController.value = v ?? DateTime.now().month;
                          _cargarConfig(mesController.value, int.tryParse(anioController.text) ?? DateTime.now().year, setStateDialog);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Montos de vencimiento (enteros):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: montoAlDiaController,
                    decoration: const InputDecoration(labelText: '1° Vencimiento (1-10)', prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: monto1erVtoController,
                    decoration: const InputDecoration(labelText: '2° Vencimiento (11-20)', prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: monto2doVtoController,
                    decoration: const InputDecoration(labelText: '3° Vencimiento (21-31)', prefixText: '\$ '),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: anioController,
                    decoration: const InputDecoration(labelText: 'Año'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _cargarConfig(mesController.value, int.tryParse(v) ?? DateTime.now().year, setStateDialog),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: soloPendientes,
                    builder: (_, value, __) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Solo cuotas no pagadas'),
                        value: value,
                        onChanged: (v) => soloPendientes.value = v ?? true,
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: incluirVencidas,
                    builder: (_, value, __) {
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Actualizar también vencidas'),
                        value: value,
                        onChanged: (v) => incluirVencidas.value = v ?? true,
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Actualizar')),
            ],
          );
        },
      ),
    );

    if (confirmar == true) {
      final montoAlDia = int.tryParse(montoAlDiaController.text) ?? 0;
      final monto1erVto = int.tryParse(monto1erVtoController.text) ?? montoAlDia;
      final monto2doVto = int.tryParse(monto2doVtoController.text) ?? monto1erVto;
      final anio = int.tryParse(anioController.text) ?? DateTime.now().year;
      if (montoAlDia <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
        );
        return;
      }
      await _db.updateMontoCuotasMes(
        anio: anio,
        mes: mesController.value,
        montoAlDia: montoAlDia,
        monto1erVto: monto1erVto,
        monto2doVto: monto2doVto,
        soloPendientes: soloPendientes.value,
        incluirVencidas: incluirVencidas.value,
      );
      // Guardar config del mes para todos los niveles
      for (final nivel in ['Primer Año', 'Segundo Año', 'Tercer Año']) {
        await _db.guardarConfigCuotasPeriodo(ConfigCuotasPeriodo(
          nivel: nivel,
          mes: mesController.value,
          anio: anio,
          montoAlDia: montoAlDia,
          monto1erVto: monto1erVto,
          monto2doVto: monto2doVto,
        ));
      }
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Montos actualizados'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _editarVencimiento(Cuota cuota) async {
    DateTime fechaSeleccionada = cuota.fechaVencimiento;

    final confirmar = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      locale: const Locale('es', 'AR'),
    );

    if (confirmar != null && cuota.id != null) {
      await _db.updateFechaVencimiento(cuota.id!, confirmar);
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fecha de vencimiento actualizada')),
        );
      }
    }
  }

  Future<void> _registrarPagoTotal(Cuota cuota) async {
    final metodoController = TextEditingController(text: 'efectivo');
    final obsController = TextEditingController();
    final reciboController = TextEditingController();
    final detalleController = TextEditingController(text: cuota.concepto);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Importe: ${_formatMoney(cuota.deuda)}', style: TextStyle(color: AppTheme.successColor, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: reciboController,
                decoration: const InputDecoration(
                  labelText: 'N° Recibo *',
                  hintText: 'Ej: 00001',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detalleController,
                decoration: const InputDecoration(
                  labelText: 'Detalle (que cuotas abona)',
                  hintText: 'Ej: Cuota Marzo 2026',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodoController.text,
                decoration: const InputDecoration(labelText: 'Efectivo o Transferencia'),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                ],
                onChanged: (v) => metodoController.text = v ?? 'efectivo',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar Pago'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
          ),
        ],
      ),
    );

    if (confirmar == true && cuota.id != null) {
      final siguienteCuota = await _db.registrarPagoTotal(
        cuota.id!,
        metodoController.text,
        observaciones: obsController.text.isEmpty ? null : obsController.text,
        numRecibo: reciboController.text.isEmpty ? null : reciboController.text,
        detallePago: detalleController.text.isEmpty ? null : detalleController.text,
      );
      await _loadCuotas();
      if (mounted) {
        if (siguienteCuota != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pago adelantado - Siguiente cuota: $siguienteCuota'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pago registrado'), backgroundColor: Colors.green),
          );
        }
      }
    }
  }

  Future<void> _registrarPagoParcial(Cuota cuota) async {
    final montoController = TextEditingController();
    final metodoController = TextEditingController(text: 'efectivo');
    final obsController = TextEditingController();
    final reciboController = TextEditingController();
    final detalleController = TextEditingController(text: 'Pago parcial - ${cuota.concepto}');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago Parcial'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monto total:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(_formatMoney(cuota.montoActual)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ya pagado:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(_formatMoney(cuota.montoPagado), style: TextStyle(color: AppTheme.successColor)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Deuda:', style: TextStyle(color: Colors.grey.shade600)),
                  Text(_formatMoney(cuota.deuda), style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: reciboController,
                decoration: const InputDecoration(
                  labelText: 'N° Recibo *',
                  hintText: 'Ej: 00001',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoController,
                decoration: InputDecoration(
                  labelText: 'Importe a pagar ahora',
                  prefixText: '\$ ',
                  helperText: 'Deuda cuota: ${_formatMoney(cuota.deuda)} (excedente va a siguiente)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detalleController,
                decoration: const InputDecoration(
                  labelText: 'Detalle (que cuotas abona)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodoController.text,
                decoration: const InputDecoration(labelText: 'Efectivo o Transferencia'),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                ],
                onChanged: (v) => metodoController.text = v ?? 'efectivo',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(labelText: 'Observaciones'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.payments),
            label: const Text('Registrar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );

    if (confirmar == true && cuota.id != null) {
      final monto = int.tryParse(montoController.text) ?? 0;
      if (monto > 0) {
        final excedente = monto > cuota.deuda ? monto - cuota.deuda : 0;
        await _db.registrarPagoParcial(
          cuota.id!,
          monto,
          metodoController.text,
          observaciones: obsController.text.isEmpty ? null : obsController.text,
          numRecibo: reciboController.text.isEmpty ? null : reciboController.text,
          detallePago: detalleController.text.isEmpty ? null : detalleController.text,
        );
        await _loadCuotas();
        if (mounted) {
          if (excedente > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Pago registrado - Excedente de ${_formatMoney(excedente)} aplicado a siguiente cuota'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Pago parcial de ${_formatMoney(monto)} registrado'), backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editarMonto(Cuota cuota) async {
    final montoAlDiaController = TextEditingController(text: cuota.montoAlDia.toString());
    final monto1erVtoController = TextEditingController(text: cuota.monto1erVto.toString());
    final monto2doVtoController = TextEditingController(text: cuota.monto2doVto.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Montos de Cuota'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Montos de vencimiento:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: montoAlDiaController,
                decoration: const InputDecoration(
                  labelText: '1° Vencimiento (1-10)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(
                  labelText: '2° Vencimiento (11-20)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(
                  labelText: '3° Vencimiento (21-31)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              Text(
                'Este cambio afectará solo a esta cuota',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmar == true && cuota.id != null) {
      final montoAlDia = int.tryParse(montoAlDiaController.text) ?? cuota.montoAlDia;
      final monto1erVto = int.tryParse(monto1erVtoController.text) ?? cuota.monto1erVto;
      final monto2doVto = int.tryParse(monto2doVtoController.text) ?? cuota.monto2doVto;
      await _db.updateMontoCuota(
        cuota.id!,
        montoAlDia: montoAlDia,
        monto1erVto: monto1erVto,
        monto2doVto: monto2doVto,
      );
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Montos actualizados')),
        );
      }
    }
  }

  Future<void> _editarMontoMes(Cuota cuota) async {
    final montoAlDiaController = TextEditingController(text: cuota.montoAlDia.toString());
    final monto1erVtoController = TextEditingController(text: cuota.monto1erVto.toString());
    final monto2doVtoController = TextEditingController(text: cuota.monto2doVto.toString());
    final mesNombre = Cuota.nombreMes(cuota.mes);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Montos - $mesNombre ${cuota.anio}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esto cambiará los montos de TODAS las cuotas pendientes/vencidas de $mesNombre.',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoAlDiaController,
                decoration: const InputDecoration(labelText: '1° Vencimiento (1-10)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(labelText: '2° Vencimiento (11-20)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(labelText: '3° Vencimiento (21-31)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Aplicar a Todos'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final montoAlDia = int.tryParse(montoAlDiaController.text) ?? cuota.montoAlDia;
      final monto1erVto = int.tryParse(monto1erVtoController.text) ?? cuota.monto1erVto;
      final monto2doVto = int.tryParse(monto2doVtoController.text) ?? cuota.monto2doVto;
      await _db.updateMontoCuotasMes(
        anio: cuota.anio,
        mes: cuota.mes,
        montoAlDia: montoAlDia,
        monto1erVto: monto1erVto,
        monto2doVto: monto2doVto,
      );
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Montos actualizados para $mesNombre')),
        );
      }
    }
  }

  Future<void> _abrirGenerarPDF() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    // Ordenar alfabéticamente por apellido/nombre para el selector
    final alumnosOrdenados = [..._alumnosDisponibles]
      ..sort((a, b) => a.apellido.toLowerCase().compareTo(b.apellido.toLowerCase()));
    final alumnoSeleccionado = ValueNotifier<String?>(alumnosOrdenados.isNotEmpty ? alumnosOrdenados.first.id : null);
    final filtro = ValueNotifier<String>('');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar PDF de Cuotas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona un alumno para generar el detalle de sus cuotas y pagos.'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o DNI',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => filtro.value = v.toLowerCase(),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: filtro,
              builder: (_, filtroValue, __) {
                final filtrados = alumnosOrdenados.where((a) {
                  final texto = '${a.nombreCompleto} ${a.dni}'.toLowerCase();
                  return texto.contains(filtroValue);
                }).toList();
                // Asegurar que el seleccionado siga estando en la lista, si no, tomar el primero
                if (filtrados.isNotEmpty && !filtrados.any((a) => a.id == alumnoSeleccionado.value)) {
                  alumnoSeleccionado.value = filtrados.first.id;
                }
                return ValueListenableBuilder<String?>(
                  valueListenable: alumnoSeleccionado,
                  builder: (_, value, __) {
                    return DropdownButtonFormField<String>(
                      value: value,
                      items: filtrados
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.nombreCompleto} - DNI: ${a.dni}'),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Alumno'),
                      onChanged: (v) => alumnoSeleccionado.value = v,
                    );
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generar PDF'),
          ),
        ],
      ),
    );

    if (confirmar == true && alumnoSeleccionado.value != null) {
      // Obtener alumno y sus cuotas
      final alumno = _alumnosDisponibles.firstWhere((a) => a.id == alumnoSeleccionado.value);
      final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumnoSeleccionado.value).toList();

      if (cuotasAlumno.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El alumno no tiene cuotas registradas'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Generar y mostrar PDF
      final pdfData = await PdfService.generarDetalleCuotas(alumno, cuotasAlumno);

      if (mounted) {
        final nombreSeguro = '${alumno.apellido}_${alumno.nombre}'.replaceAll(' ', '_');
        final anio = DateTime.now().year;
        final fileName = 'EstadoCuenta_${nombreSeguro}_$anio.pdf';

        // Opción imprimir/guardar (el navegador puede cambiar el nombre)
        await Printing.layoutPdf(onLayout: (_) => pdfData, name: fileName);
        // Opción descargar/compartir con nombre fijo
        await Printing.sharePdf(bytes: pdfData, filename: fileName);
      }
    }
  }

  // ========== INGRESAR PAGO ==========
  Future<void> _abrirIngresarPago() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    // Ordenar alfabéticamente
    final alumnosOrdenados = List<Alumno>.from(_alumnosDisponibles)
      ..sort((a, b) => a.apellido.toLowerCase().compareTo(b.apellido.toLowerCase()));

    final filtroAlumnos = ValueNotifier<String>('');
    final alumnoSeleccionado = ValueNotifier<String?>(alumnosOrdenados.isNotEmpty ? alumnosOrdenados.first.id : null);
    final importeController = TextEditingController();
    final reciboController = TextEditingController();
    final detalleController = TextEditingController();
    final metodo = ValueNotifier<String>('efectivo');
    final fechaPago = ValueNotifier<DateTime>(DateTime.now());
    final cuotasSeleccionadas = <String>{};
    final aplicarSaldoFavor = ValueNotifier<bool>(true); // siempre se aplica, solo informamos

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payments, color: Colors.green),
                SizedBox(width: 10),
                Text('Ingresar Pago'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de alumno
                  // Buscador y selector de alumno
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar alumno (nombre o DNI)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => filtroAlumnos.value = v.toLowerCase(),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: filtroAlumnos,
                    builder: (_, filtroValue, __) {
                      final filtrados = alumnosOrdenados.where((a) {
                        final txt = '${a.nombreCompleto} ${a.dni}'.toLowerCase();
                        return txt.contains(filtroValue);
                      }).toList();
                      if (filtrados.isNotEmpty && !filtrados.any((a) => a.id == alumnoSeleccionado.value)) {
                        alumnoSeleccionado.value = filtrados.first.id;
                      }
                      return ValueListenableBuilder<String?>(
                        valueListenable: alumnoSeleccionado,
                        builder: (_, value, __) {
                          final alumno = value != null
                              ? filtrados.where((a) => a.id == value).firstOrNull
                              : null;
                          final saldoFavor = alumno?.saldoFavor ?? 0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: value,
                                isExpanded: true,
                                items: filtrados
                                    .map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(a.nombreCompleto, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                decoration: const InputDecoration(labelText: 'Alumno'),
                                onChanged: (v) => alumnoSeleccionado.value = v,
                              ),
                              if (saldoFavor > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Saldo a favor disponible:', style: TextStyle(fontSize: 13)),
                                      Text(_formatMoney(saldoFavor), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Selección de cuotas a pagar
                  if (alumnoSeleccionado.value != null) ...[
                    Text('Selecciona las cuotas a abonar:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<String?>(
                      valueListenable: alumnoSeleccionado,
                      builder: (_, value, __) {
                        final alumno = value != null ? _alumnos[value] : null;
                        final cuotasAlumno = alumno != null
                            ? _cuotas.where((c) => c.alumnoId == alumno.id && !c.estaPagada).toList()
                            : <Cuota>[];
                        if (cuotasAlumno.isEmpty) {
                          return const Text('No hay cuotas pendientes.', style: TextStyle(fontSize: 12));
                        }
                        final totalSel = _calcularTotalSeleccionado(cuotasSeleccionadas);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...cuotasAlumno.map((c) => CheckboxListTile(
                                  dense: true,
                                  title: Text(c.concepto),
                                  subtitle: Text('Debe: ${_formatMoney(c.deuda)}'),
                                  value: cuotasSeleccionadas.contains(c.id),
                                  onChanged: (checked) {
                                    if (checked == true) {
                                      cuotasSeleccionadas.add(c.id!);
                                    } else {
                                      cuotasSeleccionadas.remove(c.id);
                                    }
                                    setDialogState(() {});
                                  },
                                )),
                            const SizedBox(height: 8),
                            Text('Total seleccionado: ${_formatMoney(totalSel)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reciboController,
                    decoration: const InputDecoration(
                      labelText: 'N° Recibo *',
                      hintText: 'Ej: 00001',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: importeController,
                    decoration: const InputDecoration(
                      labelText: 'Importe a pagar',
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detalleController,
                    decoration: const InputDecoration(
                      labelText: 'Detalle (qué cuotas abona)',
                      hintText: 'Ej: Cuota Marzo 2026',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: fechaPago,
                    builder: (_, value, __) => Row(
                      children: [
                        Expanded(
                          child: Text('Fecha de pago: ${DateFormat('dd/MM/yyyy').format(value)}'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: value,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              fechaPago.value = picked;
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: const Text('Cambiar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Resumen tipo planilla
                  ValueListenableBuilder<String?>(
                    valueListenable: alumnoSeleccionado,
                    builder: (_, value, __) {
                      if (value == null) return const SizedBox.shrink();
                      final alumno = _alumnos[value];
                      if (alumno == null) return const SizedBox.shrink();
                      final cuotasMarcadas = _cuotas.where((c) => cuotasSeleccionadas.contains(c.id)).toList();
                      final cuotaDe = cuotasMarcadas.isNotEmpty ? cuotasMarcadas.map((c) => c.concepto).join(', ') : 'Sin seleccionar';
                      final obs = detalleController.text.isNotEmpty ? detalleController.text : '-';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.3), // Curso
                              1: FlexColumnWidth(2), // Apellido
                              2: FlexColumnWidth(1.2), // Recibo
                              3: FlexColumnWidth(2), // Cuota de
                              4: FlexColumnWidth(1.3), // Importe
                              5: FlexColumnWidth(2), // Observaciones
                            },
                            border: TableBorder.all(color: Colors.grey.shade300),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: const [
                                  Padding(padding: EdgeInsets.all(6), child: Text('Curso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('Apellido, Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('Recibo N°', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('Cuota de', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('Importe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                  Padding(padding: EdgeInsets.all(6), child: Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(alumno.nivelInscripcion, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${alumno.apellido}, ${alumno.nombre}', style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(reciboController.text.isEmpty ? '-' : reciboController.text, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(cuotaDe, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(_formatMoney(int.tryParse(importeController.text) ?? 0), style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(obs, style: const TextStyle(fontSize: 11))),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: aplicarSaldoFavor,
                      builder: (_, value, __) {
                        final alumno = alumnoSeleccionado.value != null ? _alumnos[alumnoSeleccionado.value] : null;
                        final saldoFavor = alumno?.saldoFavor ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Se aplicará el saldo a favor de ${_formatMoney(saldoFavor)} al importe.',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'El saldo se sumará automáticamente. Si no querés usarlo, ponelo en \$0 antes de cobrar.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: metodo,
                    builder: (_, value, __) => DropdownButtonFormField<String>(
                      value: value,
                      decoration: const InputDecoration(labelText: 'Método de pago'),
                      items: const [
                        DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                        DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                      ],
                      onChanged: (v) => metodo.value = v ?? 'efectivo',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              ElevatedButton.icon(
                onPressed: () async {
                  final importe = int.tryParse(importeController.text) ?? 0;
                  if (reciboController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese N° de recibo'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (importe <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese un importe válido'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  if (alumnoSeleccionado.value == null) return;

                  Navigator.pop(context);

                  await _procesarPagoAlumno(
                    alumnoId: alumnoSeleccionado.value!,
                    importe: importe,
                    metodoPago: metodo.value,
                    numRecibo: reciboController.text.isEmpty ? null : reciboController.text,
                    detallePago: detalleController.text.isEmpty ? null : detalleController.text,
                    fechaPago: fechaPago.value,
                    cuotasIds: cuotasSeleccionadas.isEmpty ? null : cuotasSeleccionadas,
                    aplicarSaldoFavor: aplicarSaldoFavor.value,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Registrar'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _procesarPagoAlumno({
    required String alumnoId,
    required int importe,
    required String metodoPago,
    String? numRecibo,
    String? detallePago,
    required DateTime fechaPago,
    Set<String>? cuotasIds,
    bool aplicarSaldoFavor = true,
  }) async {
    // Obtener saldo a favor actual del alumno
    final alumno = _alumnosDisponibles.where((a) => a.id == alumnoId).firstOrNull;
    final saldoFavorActual = (alumno?.saldoFavor ?? 0).toInt();

    // Sumar saldo a favor al importe pagado
    int importeTotal = aplicarSaldoFavor ? importe + saldoFavorActual : importe;
    int saldoUsado = 0;

    // Obtener cuotas pendientes ordenadas por vencimiento
    var cuotasPendientes = _cuotas
        .where((c) => c.alumnoId == alumnoId && !c.estaPagada)
        .toList();
    if (cuotasIds != null && cuotasIds.isNotEmpty) {
      cuotasPendientes = cuotasPendientes.where((c) => cuotasIds.contains(c.id)).toList();
    }
    cuotasPendientes.sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    int importeRestante = importeTotal;

    // Aplicar pago a cada cuota hasta agotar el importe
    for (final cuota in cuotasPendientes) {
      if (importeRestante <= 0) break;

      final deudaCuota = cuota.deuda;
      if (importeRestante >= deudaCuota) {
        // Pagar cuota completa
        await _db.registrarPagoTotal(
          cuota.id!,
          metodoPago,
          observaciones: saldoFavorActual > 0 ? 'Incluye saldo a favor' : null,
          numRecibo: numRecibo,
          detallePago: detallePago,
          fechaPago: fechaPago,
        );
        importeRestante -= deudaCuota;
      } else {
        // Pago parcial
        await _db.registrarPagoParcial(
          cuota.id!,
          importeRestante,
          metodoPago,
          observaciones: 'Pago parcial',
          numRecibo: numRecibo,
          detallePago: detallePago,
          fechaPago: fechaPago,
        );
        importeRestante = 0;
      }
    }

    // Calcular cuánto saldo a favor se usó
    if (saldoFavorActual > 0) {
      saldoUsado = saldoFavorActual - importeRestante.clamp(0, saldoFavorActual);
      if (saldoUsado > 0) {
        // Descontar el saldo usado
        await _db.actualizarSaldoFavor(alumnoId, -saldoUsado);
      }
    }

    // Si sobra dinero, guardarlo como nuevo saldo a favor
    if (importeRestante > 0) {
      await _db.actualizarSaldoFavor(alumnoId, importeRestante);
      if (mounted) {
        String mensaje = 'Pago registrado.';
        if (saldoUsado > 0) mensaje += ' Se usó ${_formatMoney(saldoUsado)} de saldo anterior.';
        mensaje += ' Nuevo saldo a favor: ${_formatMoney(importeRestante)}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.blue, duration: const Duration(seconds: 4)),
        );
      }
    } else {
      if (mounted) {
        String mensaje = 'Pago registrado correctamente';
        if (saldoUsado > 0) mensaje += '. Se usó ${_formatMoney(saldoUsado)} de saldo a favor';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
          );
        }
      }
    await _loadCuotas();
  }

  int _calcularTotalSeleccionado(Set<String> cuotasIds) {
    int total = 0;
    for (final id in cuotasIds) {
      final cuota = _cuotas.where((c) => c.id == id).firstOrNull;
      if (cuota != null) {
        total += cuota.deuda;
      }
    }
    return total;
  }

  Future<void> _abrirPromocionarAlumnos() async {
    final anioSiguiente = DateTime.now().year + 1;
    final anioController = TextEditingController(text: anioSiguiente.toString());
    bool conCuotas = true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upgrade, color: Colors.orange),
            SizedBox(width: 8),
            Text('Promocionar al próximo año'),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Se moverán: 1° → 2° y 2° → 3°.'),
              const SizedBox(height: 8),
              TextField(
                controller: anioController,
                decoration: const InputDecoration(labelText: 'Nuevo ciclo lectivo (año)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: conCuotas,
                onChanged: (v) => setStateDialog(() => conCuotas = v ?? true),
                title: const Text('Generar cuotas del nuevo año (sin duplicar)'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Consejo: ejecutar a fines de diciembre, así en enero ya tienen ciclo y cuotas nuevas.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Promocionar')),
        ],
      ),
    );

    if (confirmar == true) {
      final nuevoAnio = int.tryParse(anioController.text) ?? anioSiguiente;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promocionando alumnos a $nuevoAnio...'), backgroundColor: Colors.blue),
        );
      }
      try {
        final res = await _db.promocionarAlumnos(nuevoAnio);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Promovidos: ${res['promovidos']} • Sin cambio: ${res['sinCambio']} • Cuotas nuevas: ${res['cuotasGeneradas']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadCuotas();
        if (mounted) {
          // Al volver al dashboard, se recalculan stats
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al promocionar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deshacerPromocion() async {
    final anioController = TextEditingController(text: DateTime.now().year.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.undo, color: Colors.red),
            SizedBox(width: 8),
            Text('Deshacer promoción'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se revertirán los niveles (2°→1°, 3°→2°) y se eliminarán las cuotas generadas del año indicado.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Esta acción no se puede deshacer. Solo usar si la promoción fue un error.',
                style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: anioController,
              decoration: const InputDecoration(labelText: 'Año de la promoción a revertir'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final anio = int.tryParse(anioController.text) ?? DateTime.now().year;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revirtiendo promoción del $anio...'), backgroundColor: Colors.orange),
        );
      }
      try {
        final res = await _db.deshacerPromocion(anio);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Revertidos: ${res['revertidos']} • Sin cambio: ${res['sinCambio']} • Cuotas eliminadas: ${res['cuotasEliminadas']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadCuotas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al revertir: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ========== TOTALES POR MES ==========
  Future<void> _abrirTotalesPorMes() async {
    final anio = DateTime.now().year;

    // Agrupar pagos por mes y por método
    final totalesPorMes = <int, int>{};
    final efectivoPorMes = <int, int>{};
    final transferenciaPorMes = <int, int>{};

    for (final cuota in _cuotas) {
      if (cuota.anio == anio && cuota.montoPagado > 0) {
        final mes = cuota.mes;
        totalesPorMes[mes] = (totalesPorMes[mes] ?? 0) + cuota.montoPagado;

        final metodo = cuota.metodoPago?.toLowerCase() ?? '';
        if (metodo.contains('transf')) {
          transferenciaPorMes[mes] = (transferenciaPorMes[mes] ?? 0) + cuota.montoPagado;
        } else {
          efectivoPorMes[mes] = (efectivoPorMes[mes] ?? 0) + cuota.montoPagado;
        }
      }
    }

    final totalAnual = totalesPorMes.values.fold<int>(0, (sum, v) => sum + v);
    final totalEfectivo = efectivoPorMes.values.fold<int>(0, (sum, v) => sum + v);
    final totalTransferencia = transferenciaPorMes.values.fold<int>(0, (sum, v) => sum + v);

    // Asegurar que todos los meses aparezcan aunque estén en 0
    for (int m = 1; m <= 12; m++) {
      totalesPorMes.putIfAbsent(m, () => 0);
      efectivoPorMes.putIfAbsent(m, () => 0);
      transferenciaPorMes.putIfAbsent(m, () => 0);
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bar_chart, color: Colors.orange),
            const SizedBox(width: 10),
            Text('Totales $anio'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total general
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total cobrado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_formatMoney(totalAnual), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.successColor)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Efectivo y Transferencia
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.payments, color: Colors.green, size: 20),
                          const Text('Efectivo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(_formatMoney(totalEfectivo), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.account_balance, color: Colors.blue, size: 20),
                          const Text('Transferencia', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(_formatMoney(totalTransferencia), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              // Detalle por mes
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (int mes = 1; mes <= 12; mes++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    Cuota.nombreMes(mes),
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: totalAnual > 0 && totalesPorMes[mes]! > 0
                                          ? (totalesPorMes[mes]! / totalAnual).clamp(0.05, 1.0)
                                          : 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 75,
                                  child: Text(
                                    _formatMoney(totalesPorMes[mes]!),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            // Desglose efectivo / transferencia por mes
                            Padding(
                              padding: const EdgeInsets.only(left: 70, top: 2),
                              child: Row(
                                children: [
                                  if ((efectivoPorMes[mes] ?? 0) > 0)
                                    Text('Efvo: ${_formatMoney(efectivoPorMes[mes]!)}  ', style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                                  if ((transferenciaPorMes[mes] ?? 0) > 0)
                                    Text('Transf: ${_formatMoney(transferenciaPorMes[mes]!)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                                  if ((efectivoPorMes[mes] ?? 0) == 0 && (transferenciaPorMes[mes] ?? 0) == 0)
                                    const Text('Sin pagos', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (totalesPorMes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No hay pagos registrados este año', textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  // ========== CONFIGURAR MONTOS POR PERÍODO ==========
  Future<void> _abrirConfigVencimientos() async {
    final meses = List.generate(12, (i) => i + 1);
    int mesSel = DateTime.now().month;
    int anioSel = DateTime.now().year;
    final anioController = TextEditingController(text: anioSel.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar montos de un mes'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: mesSel,
                items: meses
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('Mes ${m.toString().padLeft(2, '0')}'),
                        ))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Mes'),
                onChanged: (v) => setStateDialog(() => mesSel = v ?? mesSel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: anioController,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
                onChanged: (v) => setStateDialog(() => anioSel = int.tryParse(v) ?? anioSel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
        ],
      ),
    );

    if (confirmar == true) {
      _abrirAjustarMes(mesInicial: mesSel, anioInicial: anioSel);
    }
  }

  // ========== LIMPIAR CUOTAS ==========
  Future<void> _abrirLimpiarCuotas() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    // Ordenar alfabéticamente
    final alumnosOrdenados = List<Alumno>.from(_alumnosDisponibles)
      ..sort((a, b) => a.apellido.toLowerCase().compareTo(b.apellido.toLowerCase()));

    final alumnoSeleccionado = ValueNotifier<String?>(null);
    final anioController = TextEditingController(text: DateTime.now().year.toString());
    final soloNoPagadas = ValueNotifier<bool>(true);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.red),
            SizedBox(width: 10),
            Text('Limpiar Cuotas'),
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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ATENCIÓN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    SizedBox(height: 4),
                    Text(
                      'Esta acción elimina cuotas de la base de datos. Úsala para limpiar cuotas duplicadas.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String?>(
                valueListenable: alumnoSeleccionado,
                builder: (_, value, __) {
                  final alumno = value != null
                      ? alumnosOrdenados.where((a) => a.id == value).firstOrNull
                      : null;
                  final cuotasAlumno = alumno != null
                      ? _cuotas.where((c) => c.alumnoId == alumno.id).toList()
                      : <Cuota>[];
                  final cuotasPagadas = cuotasAlumno.where((c) => c.estaPagada).length;
                  final cuotasNoPagadas = cuotasAlumno.where((c) => !c.estaPagada).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: value,
                        isExpanded: true,
                        hint: const Text('Selecciona un alumno'),
                        items: alumnosOrdenados.map((a) {
                          final cant = _cuotas.where((c) => c.alumnoId == a.id).length;
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.nombreCompleto} ($cant cuotas)'),
                          );
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Alumno'),
                        onChanged: (v) => alumnoSeleccionado.value = v,
                      ),
                      if (alumno != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total cuotas: ${cuotasAlumno.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Pagadas: $cuotasPagadas', style: TextStyle(color: Colors.green.shade700)),
                              Text('No pagadas: $cuotasNoPagadas', style: TextStyle(color: Colors.orange.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: anioController,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: soloNoPagadas,
                builder: (_, value, __) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Solo borrar cuotas NO PAGADAS'),
                  subtitle: Text(
                    value ? 'Las pagadas se conservan' : 'SE BORRAN TODAS incluidas las pagadas',
                    style: TextStyle(color: value ? Colors.green : Colors.red, fontSize: 12),
                  ),
                  value: value,
                  onChanged: (v) => soloNoPagadas.value = v ?? true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (alumnoSeleccionado.value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selecciona un alumno'), backgroundColor: Colors.orange),
                );
                return;
              }

              final anio = int.tryParse(anioController.text) ?? DateTime.now().year;

              // Confirmar
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar'),
                  content: Text(
                    soloNoPagadas.value
                        ? '¿Borrar las cuotas NO PAGADAS de $anio?'
                        : '¿Borrar TODAS las cuotas de $anio? (incluidas las pagadas)',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Sí, borrar'),
                    ),
                  ],
                ),
              );

              if (confirmar == true) {
                Navigator.pop(context);

                try {
                  if (soloNoPagadas.value) {
                    await _db.eliminarCuotasNoPagadas(alumnoSeleccionado.value!, anio);
                  } else {
                    await _db.eliminarCuotasAlumno(alumnoSeleccionado.value!, anio);
                  }
                  await _loadCuotas();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cuotas eliminadas'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            icon: const Icon(Icons.delete),
            label: const Text('Borrar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
