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

class _InscripcionesScreenState extends State<InscripcionesScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService.instance;
  List<Alumno> _alumnos = [];
  bool _isLoading = true;
  String _filtroEstado = 'pendiente'; // Por defecto muestra pendientes
  String _busqueda = '';
  late TabController _tabController;

  final List<String> _niveles = ['Primer Año', 'Segundo Año', 'Tercer Año'];
  // Primer Año: divisiones A y B
  // Segundo y Tercer Año: sin divisiones
  final List<String> _divisionesPrimerAnio = ['A', 'B'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _niveles.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadAlumnos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAlumnos() async {
    setState(() => _isLoading = true);
    try {
      final alumnos = _filtroEstado.isEmpty
          ? await _db.getAllAlumnos()
          : await _db.getAlumnosByEstado(_filtroEstado);
      final alumnosConFoto = await Future.wait(alumnos.map((alumno) async {
        final signed = await _db.getSignedFotoAlumno(alumno.fotoAlumno);
        return signed != null ? alumno.copyWith(fotoAlumno: signed) : alumno;
      }));
      setState(() {
        _alumnos = alumnosConFoto;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Alumno> _filtrarAlumnos(String nivel, String? division) {
    var lista = _alumnos;

    // Filtrar por nivel
    lista = lista.where((a) => a.nivelInscripcion == nivel).toList();

    // Filtrar por división
    if (division != null) {
      if (division == 'sin_asignar') {
        lista = lista.where((a) => a.division == null || a.division!.isEmpty).toList();
      } else if (division == 'sin_division') {
        // Para Segundo y Tercer Año - mostrar todos los alumnos del nivel
        // No filtrar por división
      } else {
        lista = lista.where((a) => a.division == division).toList();
      }
    }

    // Filtrar por búsqueda
    if (_busqueda.isNotEmpty) {
      final busqueda = _busqueda.toLowerCase();
      lista = lista.where((a) {
        return a.nombre.toLowerCase().contains(busqueda) ||
            a.apellido.toLowerCase().contains(busqueda) ||
            a.dni.contains(busqueda) ||
            (a.codigoInscripcion?.toLowerCase().contains(busqueda) ?? false);
      }).toList();
    }

    // Ordenar por apellido
    lista.sort((a, b) => a.apellido.compareTo(b.apellido));
    return lista;
  }

  int _contarPorNivel(String nivel) {
    return _alumnos.where((a) => a.nivelInscripcion == nivel).length;
  }

  int _contarPorDivision(String nivel, String? division) {
    return _filtrarAlumnos(nivel, division).length;
  }

  @override
  Widget build(BuildContext context) {
    final pendientesCount = _alumnos.where((a) => a.estado == 'pendiente').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inscripciones Pendientes', style: TextStyle(fontSize: 18)),
            Text(
              '$pendientesCount por revisar',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlumnos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accentColor,
          indicatorWeight: 3,
          tabs: _niveles.map((nivel) {
            final count = _contarPorNivel(nivel);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nivel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner informativo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.warningColor.withOpacity(0.15),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Revisa la documentación y aprueba o rechaza las inscripciones',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Barra de búsqueda y filtros
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, DNI o código...',
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
                  child: TabBarView(
                    controller: _tabController,
                    children: _niveles.map((nivel) {
                      return _buildListaAgrupada(nivel);
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  // Lista agrupada por división para cada año
  Widget _buildListaAgrupada(String nivel) {
    // Primer Año tiene divisiones A y B
    // Segundo y Tercer Año no tienen divisiones
    final List<String> divisiones;
    final Map<String, String> labels;
    final Map<String, Color> colors;

    if (nivel == 'Primer Año') {
      divisiones = ['A', 'B', 'sin_asignar'];
      labels = {'A': 'Division A', 'B': 'Division B', 'sin_asignar': 'Sin Asignar'};
      colors = {
        'A': AppTheme.accentColor,
        'B': AppTheme.successColor,
        'sin_asignar': Colors.grey,
      };
    } else {
      // Segundo y Tercer Año no tienen divisiones
      divisiones = ['sin_division'];
      labels = {'sin_division': 'Alumnos'};
      colors = {'sin_division': AppTheme.primaryColor};
    }

    return RefreshIndicator(
      onRefresh: _loadAlumnos,
      child: CustomScrollView(
        slivers: [
          ...divisiones.map((division) {
            final alumnos = _filtrarAlumnos(nivel, division);
            if (alumnos.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

            final color = colors[division]!;
            final label = labels[division]!;

            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header de la división
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          division == 'sin_asignar' ? Icons.help_outline : Icons.groups,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$nivel - $label',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${alumnos.length} alumnos',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Lista de alumnos de esta división
                  ...alumnos.map((alumno) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAlumnoCard(alumno, divisionColor: color),
                  )),
                ],
              ),
            );
          }),
          // Espacio al final
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String estado) {
    final isSelected = _filtroEstado == estado;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filtroEstado = selected ? estado : '');
          _loadAlumnos();
        },
        selectedColor: AppTheme.accentColor,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppTheme.accentColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildAlumnoCard(Alumno alumno, {Color? divisionColor}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: divisionColor?.withOpacity(0.3) ?? Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(context, '/admin/alumno/${alumno.id}');
          _loadAlumnos(); // Recargar al volver
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: divisionColor ?? AppTheme.primaryColor,
                backgroundImage: (alumno.fotoAlumno != null && alumno.fotoAlumno!.isNotEmpty)
                    ? NetworkImage(alumno.fotoAlumno!)
                    : null,
                child: (alumno.fotoAlumno == null || alumno.fotoAlumno!.isEmpty)
                    ? Text(
                        '${alumno.nombre[0]}${alumno.apellido[0]}'.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'DNI: ${alumno.dni}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Nivel
                        Text(
                          alumno.nivelInscripcion,
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // División badge
                        if (alumno.division != null && alumno.division!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: divisionColor ?? AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              alumno.division!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Acciones
              Column(
                children: [
                  _buildEstadoBadge(alumno.estado),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _abrirWhatsApp(alumno),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.whatsappColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chat, color: AppTheme.whatsappColor, size: 20),
                        ),
                      ),
                      if (alumno.estado == 'pendiente') ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _aprobarInscripcion(alumno),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check, color: AppTheme.successColor, size: 20),
                          ),
                        ),
                      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
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
        title: const Text('Aprobar inscripción'),
        content: Text('¿Aprobar la inscripción de ${alumno.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
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
          const SnackBar(content: Text('Inscripción aprobada')),
        );
      }
    }
  }
}
