import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/alumno.dart';
import '../../models/cuota.dart';
import '../../models/config_vencimientos.dart';
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
      final cuotas = await _db.getAllCuotas();
      for (final cuota in cuotas) {
        if (!_alumnos.containsKey(cuota.alumnoId)) {
          final alumno = await _db.getAlumnoById(cuota.alumnoId);
          if (alumno != null) {
            final signed = await _db.getSignedFotoAlumno(alumno.fotoAlumno);
            _alumnos[cuota.alumnoId] = signed != null ? alumno.copyWith(fotoAlumno: signed) : alumno;
          }
        }
      }
      _alumnosDisponibles = await _db.getAllAlumnos();
      setState(() {
        _cuotas = cuotas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Cuota> get _cuotasFiltradas {
    Iterable<Cuota> resultado = _cuotas;

    if (_filtroEstado.isNotEmpty) {
      resultado = resultado.where((c) => _estadoCuota(c) == _filtroEstado);
    }

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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMoney(num amount) {
    return '\$${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // Estadísticas
  Map<String, dynamic> get _estadisticas {
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

    for (final cuota in _cuotas) {
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
                          ],
                        ),
                      ),
                    ),

                  // Contenido principal
                  if (_vistaCalendario)
                    _buildVistaCalendario()
                  else
                    _buildVistaLista(),
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
                          titulo: 'Cuotas Bimestrales',
                          subtitulo: '1° año: Mar-Dic  •  2°/3° año: Ene-Dic',
                          onTap: _abrirGenerarBimestrales,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildAccionMini(
                                icon: Icons.tune,
                                label: 'Ajustar montos',
                                onTap: _abrirAjustarBimestre,
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
    final bimestres = esPrimerAnio
        ? [{'mes': 0, 'label': 'INSC'}, {'mes': 3, 'label': 'Mar'}, {'mes': 5, 'label': 'May'}, {'mes': 7, 'label': 'Jul'}, {'mes': 9, 'label': 'Sep'}, {'mes': 11, 'label': 'Nov'}]
        : [{'mes': 1, 'label': 'Ene'}, {'mes': 3, 'label': 'Mar'}, {'mes': 5, 'label': 'May'}, {'mes': 7, 'label': 'Jul'}, {'mes': 9, 'label': 'Sep'}, {'mes': 11, 'label': 'Nov'}];

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
          // Header de bimestres
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const SizedBox(width: 130, child: Padding(padding: EdgeInsets.only(left: 8), child: Text('ALUMNO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)))),
                ...bimestres.map((b) => SizedBox(
                  width: 38,
                  child: Center(child: Text(b['label'] as String, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                )),
                const SizedBox(width: 55, child: Center(child: Text('DEUDA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)))),
              ],
            ),
          ),
          // Filas de alumnos
          ...alumnos.map((alumno) => _buildFilaAlumno(alumno, bimestres)),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildFilaAlumno(Alumno alumno, List<Map<String, dynamic>> bimestres) {
    final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumno.id).toList();
    int deudaTotal = cuotasAlumno.fold(0, (sum, c) => sum + c.deuda);

    // Filtrar por estado si hay filtro
    if (_filtroEstado.isNotEmpty) {
      final tieneEstado = cuotasAlumno.any((c) => _estadoCuota(c) == _filtroEstado);
      if (!tieneEstado) return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => _mostrarDetallePago(alumno),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          color: deudaTotal > 0 ? AppTheme.dangerColor.withOpacity(0.03) : null,
        ),
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
            // Celdas de bimestres
            ...bimestres.map((b) {
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
              width: 50,
              child: Center(
                child: Text(
                  deudaTotal > 0 ? _formatMoney(deudaTotal) : '-',
                  style: TextStyle(fontSize: 10, color: deudaTotal > 0 ? AppTheme.dangerColor : Colors.grey, fontWeight: deudaTotal > 0 ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ),
          ],
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
        width: 36, height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(cuota == null ? 0.3 : 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text(symbol, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }

  String _filtroDivision = '';

  void _mostrarOpcionesCuota(Cuota cuota, Alumno alumno) {
    if (cuota.estaPagada) {
      // Solo mostrar info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${cuota.concepto} - Pagada'), duration: const Duration(seconds: 1)),
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
            Text('${alumno.nombreCompleto}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(cuota.concepto, style: TextStyle(color: Colors.grey.shade600)),
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
          ],
        ),
      ),
    );
  }

  void _mostrarDetallePago(Alumno alumno) async {
    final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumno.id).toList()
      ..sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    if (cuotasAlumno.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este alumno no tiene cuotas generadas')),
      );
      return;
    }

    final pdfData = await PdfService.generarDetalleCuotas(alumno, cuotasAlumno);
    if (mounted) {
      await Printing.layoutPdf(onLayout: (_) => pdfData, name: 'Cuotas_${alumno.apellido}.pdf');
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

  Future<void> _abrirGenerarBimestrales() async {
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
        title: const Text('Cuotas Bimestrales'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text('Bimestres por nivel:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('• 1° Año: Mar, May, Jul, Sep, Nov (5 cuotas)', style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
                    Text('• 2°/3° Año: Ene, Mar, May, Jul, Sep, Nov (6 cuotas)', style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
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
                                ? 'Se generarán 5 cuotas (Mar-Nov)'
                                : 'Se generarán 6 cuotas (Ene-Nov)',
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
                  labelText: 'Al día (1-10)',
                  prefixText: '\$ ',
                  hintText: 'Ej: 15000',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(
                  labelText: '1er Vto (11-20)',
                  prefixText: '\$ ',
                  hintText: 'Ej: 16500',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(
                  labelText: '2do Vto (21-31)',
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
        await _db.generarCuotasBimestrales(
          alumnoSeleccionado.value!,
          montoAlDia,
          anio,
          monto1erVto: monto1erVto,
          monto2doVto: monto2doVto,
        );
        await _loadCuotas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuotas bimestrales generadas'), backgroundColor: Colors.green),
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

  Future<void> _abrirAjustarBimestre() async {
    final montoAlDiaController = TextEditingController();
    final monto1erVtoController = TextEditingController();
    final monto2doVtoController = TextEditingController();
    final anioController = TextEditingController(text: DateTime.now().year.toString());
    final bimestreController = ValueNotifier<int>(1);
    final soloPendientes = ValueNotifier<bool>(true);
    final incluirVencidas = ValueNotifier<bool>(true);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar monto bimestral'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Actualiza los montos de las cuotas de un bimestre.'),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: bimestreController,
                builder: (_, value, __) {
                  return DropdownButtonFormField<int>(
                    value: value,
                    decoration: const InputDecoration(labelText: 'Bimestre'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1° Bimestre (Ene-Feb)')),
                      DropdownMenuItem(value: 2, child: Text('2° Bimestre (Mar-Abr)')),
                      DropdownMenuItem(value: 3, child: Text('3° Bimestre (May-Jun)')),
                      DropdownMenuItem(value: 4, child: Text('4° Bimestre (Jul-Ago)')),
                      DropdownMenuItem(value: 5, child: Text('5° Bimestre (Sep-Oct)')),
                      DropdownMenuItem(value: 6, child: Text('6° Bimestre (Nov-Dic)')),
                    ],
                    onChanged: (v) => bimestreController.value = v ?? 1,
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Montos de vencimiento (enteros):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: montoAlDiaController,
                decoration: const InputDecoration(labelText: 'Al día (1-10)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(labelText: '1er Vto (11-20)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(labelText: '2do Vto (21-31)', prefixText: '\$ '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: anioController,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
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
      await _db.updateMontoCuotasBimestre(
        anio: anio,
        bimestre: bimestreController.value,
        montoAlDia: montoAlDia,
        monto1erVto: monto1erVto,
        monto2doVto: monto2doVto,
        soloPendientes: soloPendientes.value,
        incluirVencidas: incluirVencidas.value,
      );
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

  bool _esPrimerAnio(String? alumnoId) {
    if (alumnoId == null) return false;
    try {
      final alumno = _alumnosDisponibles.firstWhere((a) => a.id == alumnoId);
      return alumno.nivelInscripcion == 'Primer Año';
    } catch (_) {
      return false;
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
                  labelText: 'Al día (1-10)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto1erVtoController,
                decoration: const InputDecoration(
                  labelText: '1er Vto (11-20)',
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto2doVtoController,
                decoration: const InputDecoration(
                  labelText: '2do Vto (21-31)',
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

  Future<void> _abrirGenerarPDF() async {
    if (_alumnosDisponibles.isEmpty) {
      await _loadCuotas();
    }

    final alumnoSeleccionado = ValueNotifier<String?>(_alumnosDisponibles.isNotEmpty ? _alumnosDisponibles.first.id : null);

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
            ValueListenableBuilder<String?>(
              valueListenable: alumnoSeleccionado,
              builder: (_, value, __) {
                return DropdownButtonFormField<String>(
                  value: value,
                  items: _alumnosDisponibles
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
        await Printing.layoutPdf(
          onLayout: (_) => pdfData,
          name: 'Cuotas_${alumno.apellido}_${alumno.nombre}.pdf',
        );
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

    final alumnoSeleccionado = ValueNotifier<String?>(alumnosOrdenados.isNotEmpty ? alumnosOrdenados.first.id : null);
    final importeController = TextEditingController();
    final reciboController = TextEditingController();
    final detalleController = TextEditingController();
    final metodo = ValueNotifier<String>('efectivo');

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
                  ValueListenableBuilder<String?>(
                    valueListenable: alumnoSeleccionado,
                    builder: (_, value, __) {
                      final alumno = value != null
                          ? alumnosOrdenados.where((a) => a.id == value).firstOrNull
                          : null;
                      final cuotasAlumno = alumno != null
                          ? _cuotas.where((c) => c.alumnoId == alumno.id && !c.estaPagada).toList()
                          : <Cuota>[];
                      final deudaTotal = cuotasAlumno.fold<int>(0, (sum, c) => sum + c.deuda);
                      final saldoFavor = alumno?.saldoFavor ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: value,
                            isExpanded: true,
                            items: alumnosOrdenados.map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.nombreCompleto, overflow: TextOverflow.ellipsis),
                            )).toList(),
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Deuda total:', style: TextStyle(fontSize: 13)),
                                      Text(_formatMoney(deudaTotal), style: TextStyle(fontWeight: FontWeight.bold, color: deudaTotal > 0 ? AppTheme.dangerColor : AppTheme.successColor)),
                                    ],
                                  ),
                                  if (saldoFavor > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Saldo a favor:', style: TextStyle(fontSize: 13)),
                                        Text(_formatMoney(saldoFavor), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                      ],
                                    ),
                                  ],
                                  if (cuotasAlumno.isNotEmpty) ...[
                                    const Divider(height: 16),
                                    Text('Cuotas pendientes:', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    const SizedBox(height: 4),
                                    ...cuotasAlumno.take(4).map((c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(c.concepto, style: const TextStyle(fontSize: 12)),
                                          Text(_formatMoney(c.deuda), style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )),
                                    if (cuotasAlumno.length > 4)
                                      Text('... y ${cuotasAlumno.length - 4} más', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
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
                    controller: reciboController,
                    decoration: const InputDecoration(
                      labelText: 'N° Recibo *',
                      hintText: 'Ej: 00001',
                    ),
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
  }) async {
    // Obtener saldo a favor actual del alumno
    final alumno = _alumnosDisponibles.where((a) => a.id == alumnoId).firstOrNull;
    final saldoFavorActual = (alumno?.saldoFavor ?? 0).toInt();

    // Sumar saldo a favor al importe pagado
    int importeTotal = importe + saldoFavorActual;
    int saldoUsado = 0;

    // Obtener cuotas pendientes ordenadas por vencimiento
    final cuotasPendientes = _cuotas
        .where((c) => c.alumnoId == alumnoId && !c.estaPagada)
        .toList()
      ..sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

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
                      if (totalesPorMes.containsKey(mes))
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
                                        widthFactor: totalAnual > 0 ? (totalesPorMes[mes]! / totalAnual).clamp(0.05, 1.0) : 0,
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
    // Esta función ahora muestra información sobre el nuevo sistema de montos
    // Los montos se configuran directamente en "Ajustar Bimestre" o al generar cuotas
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 10),
            Text('Sistema de Cuotas'),
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nuevo sistema de vencimientos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('Cada cuota tiene 3 montos enteros:', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 4),
                    Text('• Al día (1-10): Pago en término', style: TextStyle(fontSize: 12)),
                    Text('• 1er Vto (11-20): Primer vencimiento', style: TextStyle(fontSize: 12)),
                    Text('• 2do Vto (21-31): Segundo vencimiento', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Cómo configurar los montos?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 8),
                    Text('1. Al generar cuotas: Define los 3 montos', style: TextStyle(fontSize: 12)),
                    Text('2. Ajustar Bimestre: Actualiza montos existentes', style: TextStyle(fontSize: 12)),
                    Text('3. Editar cuota individual: Click en el monto', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ejemplo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('2° Año - Enero/Febrero:', style: TextStyle(fontSize: 12)),
                    Text('  Al día: \$15.000', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    Text('  1er Vto: \$16.500', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                    Text('  2do Vto: \$18.000', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
