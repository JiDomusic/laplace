import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/alumno.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class InscripcionesScreen extends StatefulWidget {
  const InscripcionesScreen({super.key});

  @override
  State<InscripcionesScreen> createState() => _InscripcionesScreenState();
}

class _InscripcionesScreenState extends State<InscripcionesScreen> {
  final SupabaseService _db = SupabaseService.instance;
  List<Alumno> _alumnos = [];
  bool _isLoading = true;
  String _filtroEstado = '';
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _loadAlumnos();
  }

  Future<void> _loadAlumnos() async {
    setState(() => _isLoading = true);
    try {
      final alumnos = _filtroEstado.isEmpty
          ? await _db.getAllAlumnos()
          : await _db.getAlumnosByEstado(_filtroEstado);
      setState(() {
        _alumnos = alumnos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Alumno> get _alumnosFiltrados {
    if (_busqueda.isEmpty) return _alumnos;
    final busqueda = _busqueda.toLowerCase();
    return _alumnos.where((a) {
      return a.nombre.toLowerCase().contains(busqueda) ||
          a.apellido.toLowerCase().contains(busqueda) ||
          a.dni.contains(busqueda) ||
          (a.codigoInscripcion?.toLowerCase().contains(busqueda) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscripciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlumnos,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, DNI o codigo...',
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
                      _buildFiltroChip('Todos', ''),
                      _buildFiltroChip('Pendientes', 'pendiente'),
                      _buildFiltroChip('Aprobados', 'aprobado'),
                      _buildFiltroChip('Rechazados', 'rechazado'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de alumnos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alumnosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No hay inscripciones',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAlumnos,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _alumnosFiltrados.length,
                          itemBuilder: (context, index) {
                            return _buildAlumnoCard(_alumnosFiltrados[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filtroEstado = selected ? estado : '');
          _loadAlumnos();
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        checkmarkColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildAlumnoCard(Alumno alumno) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/admin/alumno/${alumno.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      alumno.nombre[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alumno.nombreCompleto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'DNI: ${alumno.dni}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Estado
                  _buildEstadoBadge(alumno.estado),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alumno.codigoInscripcion ?? 'Sin codigo',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        alumno.nivelInscripcion,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat, color: AppTheme.whatsappColor),
                        onPressed: () => _abrirWhatsApp(alumno),
                        tooltip: 'WhatsApp',
                      ),
                      if (alumno.estado == 'pendiente')
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                          onPressed: () => _aprobarInscripcion(alumno),
                          tooltip: 'Aprobar',
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    String texto;
    switch (estado) {
      case 'pendiente':
        color = AppTheme.warningColor;
        texto = 'Pendiente';
        break;
      case 'aprobado':
        color = AppTheme.successColor;
        texto = 'Aprobado';
        break;
      case 'rechazado':
        color = AppTheme.dangerColor;
        texto = 'Rechazado';
        break;
      default:
        color = Colors.grey;
        texto = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Future<void> _abrirWhatsApp(Alumno alumno) async {
    final celular = alumno.celular.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/54$celular');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _aprobarInscripcion(Alumno alumno) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar Inscripcion'),
        content: Text('¿Aprobar la inscripcion de ${alumno.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.updateEstadoAlumno(alumno.id!, 'aprobado');
      _loadAlumnos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscripcion aprobada')),
        );
      }
    }
  }
}
