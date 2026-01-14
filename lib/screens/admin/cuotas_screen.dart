import 'package:flutter/material.dart';
import '../../models/alumno.dart';
import '../../models/cuota.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
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
  String _filtroEstado = 'todas';
  List<Alumno> _alumnosDisponibles = [];

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

    if (_filtroEstado != 'todas') {
      resultado = resultado.where((c) => _estadoCuota(c) == _filtroEstado);
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

    return resultado.toList();
  }

  String _estadoCuota(Cuota cuota) {
    if (cuota.estaPagada) return 'pagada';
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
    double totalPendiente = 0;
    double totalPagado = 0;
    double totalDeuda = 0;
    double totalFacturacion = 0;
    int cantPagadas = 0;
    int cantParciales = 0;
    int cantPendientes = 0;
    int cantVencidas = 0;

    for (final cuota in _cuotas) {
      totalPagado += cuota.montoPagado;
      totalDeuda += cuota.deuda;
      totalFacturacion += cuota.monto;

      final estado = _estadoCuota(cuota);
      switch (estado) {
        case 'pagada':
          cantPagadas++;
          break;
        case 'parcial':
          cantParciales++;
          totalPendiente += cuota.deuda;
          break;
        case 'vencida':
          cantVencidas++;
          totalPendiente += cuota.deuda;
          break;
        default:
          cantPendientes++;
          totalPendiente += cuota.deuda;
      }
    }

    return {
      'totalPendiente': totalPendiente,
      'totalPagado': totalPagado,
      'totalDeuda': totalDeuda,
      'cantPagadas': cantPagadas,
      'cantParciales': cantParciales,
      'cantPendientes': cantPendientes,
      'cantVencidas': cantVencidas,
      'totalFacturacion': totalFacturacion,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _estadisticas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Cuotas'),
        actions: [
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
                case 'ajustar_trimestre':
                  _abrirAjustarTrimestre();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'generar',
                child: ListTile(
                  leading: Icon(Icons.add_card),
                  title: Text('Generar cuotas'),
                ),
              ),
              const PopupMenuItem(
                value: 'ajustar_trimestre',
                child: ListTile(
                  leading: Icon(Icons.change_circle_outlined),
                  title: Text('Ajustar monto trimestral'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Estadísticas
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatCard('Pagadas', stats['cantPagadas'], AppTheme.successColor, _formatMoney(stats['totalPagado']), width: 160),
                _buildStatCard('Parciales', stats['cantParciales'], Colors.orange, null, width: 160),
                _buildStatCard('Pendientes', stats['cantPendientes'], AppTheme.warningColor, _formatMoney(stats['totalPendiente']), width: 160),
                _buildStatCard(
                  'Vencidas',
                  stats['cantVencidas'],
                  (stats['totalDeuda'] ?? 0) > 0 ? AppTheme.dangerColor : Colors.grey,
                  _formatMoney(stats['totalDeuda']),
                  width: 160,
                ),
                _buildStatCard(
                  'Facturacion',
                  stats['cantPagadas'] + stats['cantParciales'] + stats['cantPendientes'] + stats['cantVencidas'],
                  AppTheme.primaryColor,
                  _formatMoney(stats['totalFacturacion']),
                  width: 160,
                ),
              ],
            ),
          ),

          // Búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por alumno, DNI o codigo...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _busqueda = v),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFiltroChip('Todas', 'todas'),
                      _buildFiltroChip('Pagadas', 'pagada'),
                      _buildFiltroChip('Parciales', 'parcial'),
                      _buildFiltroChip('Pendientes', 'pendiente'),
                      _buildFiltroChip('Vencidas', 'vencida'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de cuotas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cuotasFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No hay cuotas con este filtro',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCuotas,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cuotasFiltradas.length,
                          itemBuilder: (context, index) {
                            final cuota = _cuotasFiltradas[index];
                            final alumno = _alumnos[cuota.alumnoId];
                            return _buildCuotaCard(cuota, alumno);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, String? subtext, {double? width}) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          if (subtext != null)
            Text(subtext, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }

  Widget _buildFiltroChip(String label, String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) => setState(() => _filtroEstado = selected ? estado : 'todas'),
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildCuotaCard(Cuota cuota, Alumno? alumno) {
    final estado = _estadoCuota(cuota);
    final vencimiento = _formatDate(cuota.fechaVencimiento);
    final nombre = alumno?.nombreCompleto ?? 'Alumno ${cuota.alumnoId}';
    final dni = alumno?.dni ?? '';
    final int cuotasPendAlumno = _contarCuotasPendientes(alumno?.id ?? cuota.alumnoId);
    final bool alertaDeuda = cuotasPendAlumno >= 3;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alertaDeuda ? AppTheme.dangerColor.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: alertaDeuda ? AppTheme.dangerColor.withOpacity(0.4) : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: alumno?.fotoAlumno != null && alumno!.fotoAlumno!.isNotEmpty
                      ? NetworkImage(alumno.fotoAlumno!)
                      : null,
                  child: (alumno?.fotoAlumno == null || alumno!.fotoAlumno!.isEmpty)
                      ? Text(
                          nombre[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('DNI: $dni', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                _buildEstadoBadge(estado),
              ],
            ),

            const Divider(height: 24),

            // Info de cuota
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Vence: $vencimiento', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Monto: ${_formatMoney(cuota.monto)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (cuota.montoPagado > 0)
                      Text('Pagado: ${_formatMoney(cuota.montoPagado)}', style: TextStyle(color: AppTheme.successColor, fontSize: 13)),
                    if (cuota.deuda > 0 && !cuota.estaPagada)
                      Text('Debe: ${_formatMoney(cuota.deuda)}', style: TextStyle(color: AppTheme.dangerColor, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                if (!cuota.estaPagada) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _registrarPagoParcial(cuota),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Pago Parcial'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _registrarPagoTotal(cuota),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Pago Total'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
                if (cuota.estaPagada)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pagada ${cuota.fechaPago != null ? _formatDate(cuota.fechaPago!) : ''}',
                            style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _editarMonto(cuota),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar monto',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editarVencimiento(cuota),
                      icon: const Icon(Icons.event),
                      tooltip: 'Editar vencimiento',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar cuotas anuales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecciona alumno y define el monto mensual. Se generarán cuotas de marzo a noviembre.'),
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
              decoration: const InputDecoration(labelText: 'Monto mensual', prefixText: '\$ '),
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
          const SnackBar(content: Text('Monto invalido'), backgroundColor: Colors.red),
        );
        return;
      }
      await _db.generarCuotasAnuales(alumnoSeleccionado.value!, monto, anio);
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuotas generadas'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _abrirAjustarTrimestre() async {
    final montoController = TextEditingController();
    final anioController = TextEditingController(text: DateTime.now().year.toString());
    final trimestreController = ValueNotifier<int>(1);
    final soloPendientes = ValueNotifier<bool>(true);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajustar monto trimestral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actualiza el monto de las cuotas de un trimestre (mar-may, jun-ago, sep-nov).'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: trimestreController.value,
              decoration: const InputDecoration(labelText: 'Trimestre'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1° Trimestre (Mar-May)')),
                DropdownMenuItem(value: 2, child: Text('2° Trimestre (Jun-Ago)')),
                DropdownMenuItem(value: 3, child: Text('3° Trimestre (Sep-Nov)')),
              ],
              onChanged: (v) => trimestreController.value = v ?? 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montoController,
              decoration: const InputDecoration(labelText: 'Nuevo monto mensual', prefixText: '\$ '),
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
          const SnackBar(content: Text('Monto invalido'), backgroundColor: Colors.red),
        );
        return;
      }
      await _db.updateMontoCuotasTrimestre(
        anio: anio,
        trimestre: trimestreController.value,
        nuevoMonto: monto,
        soloPendientes: soloPendientes.value,
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

  Widget _buildEstadoBadge(String estado) {
    Color color;
    String texto;
    IconData icon;

    switch (estado) {
      case 'vencida':
        color = AppTheme.dangerColor;
        texto = 'Vencida';
        icon = Icons.warning;
        break;
      case 'parcial':
        color = Colors.orange;
        texto = 'Parcial';
        icon = Icons.timelapse;
        break;
      case 'pendiente':
        color = AppTheme.warningColor;
        texto = 'Pendiente';
        icon = Icons.schedule;
        break;
      default:
        color = AppTheme.successColor;
        texto = 'Pagada';
        icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  int _contarCuotasPendientes(String alumnoId) {
    return _cuotas.where((c) => c.alumnoId == alumnoId && !c.estaPagada).length;
  }

  Future<void> _registrarPagoTotal(Cuota cuota) async {
    final metodoController = TextEditingController(text: 'efectivo');
    final obsController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago Total'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cuota.concepto, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Monto a pagar: ${_formatMoney(cuota.deuda)}', style: TextStyle(color: AppTheme.successColor, fontSize: 18)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: metodoController.text,
              decoration: const InputDecoration(labelText: 'Metodo de pago'),
              items: const [
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
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
      );
      await _loadCuotas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago total registrado'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _registrarPagoParcial(Cuota cuota) async {
    final montoController = TextEditingController();
    final metodoController = TextEditingController(text: 'efectivo');
    final obsController = TextEditingController();

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
                controller: montoController,
                decoration: InputDecoration(
                  labelText: 'Monto a pagar ahora',
                  prefixText: '\$ ',
                  helperText: 'Maximo: ${_formatMoney(cuota.deuda)}',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodoController.text,
                decoration: const InputDecoration(labelText: 'Metodo de pago'),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                  DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
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
            const SnackBar(content: Text('Monto invalido'), backgroundColor: Colors.red),
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
}
