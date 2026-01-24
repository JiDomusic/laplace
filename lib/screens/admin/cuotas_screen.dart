import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/alumno.dart';
import '../../models/cuota.dart';
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

  String _formatMoney(double amount) {
    return '\$${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  // Estadísticas
  Map<String, dynamic> get _estadisticas {
    double totalCobrado = 0;        // Todo lo que ya entró
    double totalPorCobrar = 0;      // Todo lo que falta cobrar
    double totalFacturacion = 0;    // Total que debería entrar

    // Por categoría - mostramos deuda pendiente por estado
    double montoPagadas = 0;        // Monto de cuotas completamente pagadas
    double montoParciales = 0;      // Lo que se cobró de cuotas parciales
    double deudaParciales = 0;      // Lo que falta de cuotas parciales
    double deudaPendientes = 0;     // Deuda de cuotas pendientes (no vencidas)
    double deudaVencidas = 0;       // Deuda de cuotas vencidas
    double cobradoVencidas = 0;     // Pagos parciales en cuotas vencidas

    int cantPagadas = 0;
    int cantParciales = 0;
    int cantPendientes = 0;
    int cantVencidas = 0;

    for (final cuota in _cuotas) {
      totalCobrado += cuota.montoPagado;
      totalPorCobrar += cuota.deuda;
      totalFacturacion += cuota.monto;

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

  @override
  Widget build(BuildContext context) {
    final stats = _estadisticas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de cuotas'),
        actions: [
          // Toggle vista
          IconButton(
            icon: Icon(_vistaCalendario ? Icons.list : Icons.calendar_view_month),
            tooltip: _vistaCalendario ? 'Vista lista' : 'Vista calendario',
            onPressed: () => setState(() => _vistaCalendario = !_vistaCalendario),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCuotas,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'generar':
                  _abrirGenerarCuotas();
                  break;
                case 'ajustar_bimestre':
                  _abrirAjustarBimestre();
                  break;
                case 'generar_pdf':
                  _abrirGenerarPDF();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'generar', child: Row(children: [Icon(Icons.add_card, size: 20), SizedBox(width: 8), Text('Generar cuotas')])),
              const PopupMenuItem(value: 'ajustar_bimestre', child: Row(children: [Icon(Icons.change_circle_outlined, size: 20), SizedBox(width: 8), Text('Ajustar bimestre')])),
              const PopupMenuItem(value: 'generar_pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 20), SizedBox(width: 8), Text('PDF alumno')])),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCuotas,
              child: CustomScrollView(
                slivers: [
                  // Resumen compacto
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: AppTheme.primaryColor.withOpacity(0.05),
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
                          // Búsqueda
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
                          // Filtros en una fila
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

                  // Leyenda de colores (solo en vista calendario)
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
                            const Text('Pagos bimestrales:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                _buildLeyendaItem('✓', AppTheme.successColor, 'Pagada'),
                                _buildLeyendaItem('◐', Colors.orange, 'Pago parcial'),
                                _buildLeyendaItem('○', Colors.grey.shade500, 'Pendiente'),
                                _buildLeyendaItem('!', AppTheme.dangerColor, 'Vencida'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toca una celda para registrar pago. Toca el nombre del alumno para ver/imprimir PDF.',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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

  Widget _buildMiniStat(String label, double value, Color color) {
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
    return Padding(
      padding: const EdgeInsets.only(right: 4),
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
    );
  }

  Widget _buildEstadoChip(String symbol, String estado, Color color) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
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
    // Bimestres con labels más claros
    final bimestres = esPrimerAnio
        ? [{'mes': 0, 'label': 'INSC'}, {'mes': 3, 'label': 'Mar'}, {'mes': 5, 'label': 'May'}, {'mes': 7, 'label': 'Jul'}, {'mes': 9, 'label': 'Sep'}, {'mes': 11, 'label': 'Nov'}]
        : [{'mes': 1, 'label': 'Ene'}, {'mes': 3, 'label': 'Mar'}, {'mes': 5, 'label': 'May'}, {'mes': 7, 'label': 'Jul'}, {'mes': 9, 'label': 'Sep'}, {'mes': 11, 'label': 'Nov'}];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del grupo con cantidad
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppTheme.primaryColor,
          child: Row(
            children: [
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
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildFilaAlumno(Alumno alumno, List<Map<String, dynamic>> bimestres) {
    final cuotasAlumno = _cuotas.where((c) => c.alumnoId == alumno.id).toList();
    double deudaTotal = cuotasAlumno.fold(0, (sum, c) => sum + c.deuda);

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
                Text('Monto: ${_formatMoney(cuota.monto)}'),
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
              Text(_formatMoney(cuota.monto), style: const TextStyle(fontSize: 12)),
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

    final alumnoSeleccionado = ValueNotifier<String?>(_alumnosDisponibles.isNotEmpty ? _alumnosDisponibles.first.id : null);
    final montoController = TextEditingController();
    final anioController = TextEditingController(text: DateTime.now().year.toString());
    final inscripcionController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar cuotas del año'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: alumnoSeleccionado,
              builder: (_, value, __) {
                Alumno? alumno;
                try {
                  alumno = _alumnosDisponibles.firstWhere((a) => a.id == value);
                } catch (_) {}
                final cantBim = alumno?.nivelInscripcion == 'Primer Año' ? '5 bimestres (Mar-Dic)' : '6 bimestres (Ene-Dic)';
                return Text(
                  'Selecciona alumno y define el monto bimestral. Se generarán $cantBim.',
                  style: const TextStyle(fontSize: 13),
                );
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String?>(
              valueListenable: alumnoSeleccionado,
              builder: (_, value, __) {
                return DropdownButtonFormField<String>(
                  value: value,
                  items: _alumnosDisponibles
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.nombreCompleto),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Alumno'),
                  onChanged: (v) => alumnoSeleccionado.value = v,
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoController,
              decoration: const InputDecoration(labelText: 'Monto bimestral', prefixText: '\$ '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String?>(
              valueListenable: alumnoSeleccionado,
              builder: (_, value, __) {
                final esPrimerAnio = _esPrimerAnio(value);
                if (!esPrimerAnio) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: inscripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Monto inscripción (solo 1° año)',
                        prefixText: '\$ ',
                        helperText: 'Se genera una sola vez',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            TextField(
              controller: anioController,
              decoration: const InputDecoration(labelText: 'Año'),
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
      final monto = double.tryParse(montoController.text) ?? 0;
      final anio = int.tryParse(anioController.text) ?? DateTime.now().year;
      if (monto <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
        );
        return;
      }
      final esPrimerAnio = _esPrimerAnio(alumnoSeleccionado.value);
      final montoInsc = esPrimerAnio ? double.tryParse(inscripcionController.text) : null;
      await _db.generarCuotasAnuales(
        alumnoSeleccionado.value!,
        monto,
        anio,
        montoInscripcion: montoInsc,
        generarInscripcion: esPrimerAnio,
      );
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuotas generadas'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _abrirAjustarBimestre() async {
    final montoController = TextEditingController();
    final anioController = TextEditingController(text: DateTime.now().year.toString());
    final bimestreController = ValueNotifier<int>(1);
    final soloPendientes = ValueNotifier<bool>(true);
    final incluirVencidas = ValueNotifier<bool>(true);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar monto bimestral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actualiza el monto de las cuotas de un bimestre (ene-feb, mar-abr, etc).'),
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
            const SizedBox(height: 12),
            TextField(
              controller: montoController,
              decoration: const InputDecoration(labelText: 'Nuevo monto bimestral', prefixText: '\$ '),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Actualizar')),
        ],
      ),
    );

    if (confirmar == true) {
      final monto = double.tryParse(montoController.text) ?? 0;
      final anio = int.tryParse(anioController.text) ?? DateTime.now().year;
      if (monto <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
        );
        return;
      }
      await _db.updateMontoCuotasBimestre(
        anio: anio,
        bimestre: bimestreController.value,
        nuevoMonto: monto,
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
      await _db.registrarPagoTotal(
        cuota.id!,
        metodoController.text,
        observaciones: obsController.text.isEmpty ? null : obsController.text,
        numRecibo: reciboController.text.isEmpty ? null : reciboController.text,
        detallePago: detalleController.text.isEmpty ? null : detalleController.text,
      );
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado'), backgroundColor: Colors.green),
        );
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
                  Text(_formatMoney(cuota.monto)),
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
                  helperText: 'Máximo: ${_formatMoney(cuota.deuda)}',
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
      final monto = double.tryParse(montoController.text) ?? 0;
      if (monto > 0 && monto <= cuota.deuda) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pago parcial de ${_formatMoney(monto)} registrado'), backgroundColor: Colors.orange),
          );
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
    final montoController = TextEditingController(text: cuota.monto.toStringAsFixed(0));

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Monto de Cuota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              decoration: const InputDecoration(
                labelText: 'Nuevo monto',
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text(
              'Este cambio afectara solo a esta cuota',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
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
      final nuevoMonto = double.tryParse(montoController.text) ?? cuota.monto;
      await _db.updateMontoCuota(cuota.id!, nuevoMonto);
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto actualizado')),
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
}
