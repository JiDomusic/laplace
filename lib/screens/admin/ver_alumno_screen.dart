import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../../models/alumno.dart';
import '../../models/legajo.dart';
import '../../services/supabase_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/app_theme.dart';

class VerAlumnoScreen extends StatefulWidget {
  final String alumnoId;

  const VerAlumnoScreen({super.key, required this.alumnoId});

  @override
  State<VerAlumnoScreen> createState() => _VerAlumnoScreenState();
}

class _VerAlumnoScreenState extends State<VerAlumnoScreen> {
  final SupabaseService _db = SupabaseService.instance;
  Alumno? _alumno;
  Legajo? _legajo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final alumno = await _db.getAlumnoById(widget.alumnoId);
      Legajo? legajo;
      if (alumno != null) {
        legajo = await _db.getLegajoByAlumnoId(alumno.id!);
      }
      setState(() {
        _alumno = alumno;
        _legajo = legajo;
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
        title: Text(_alumno?.nombreCompleto ?? 'Detalle Alumno'),
        actions: [
          if (_alumno != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final pdfData = await PdfService.generarComprobante(_alumno!);
                await Printing.layoutPdf(onLayout: (_) => pdfData);
              },
              tooltip: 'Ver PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alumno == null
              ? const Center(child: Text('Alumno no encontrado'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildSeccion('Nivel de Inscripcion', [
                        _buildInfo('Nivel', _alumno!.nivelInscripcion),
                        _buildInfo('Estado', _alumno!.estado.toUpperCase()),
                      ]),
                      _buildSeccion('Datos Personales', [
                        _buildInfo('DNI', _alumno!.dni),
                        _buildInfo('Sexo', _alumno!.sexo),
                        _buildInfo('Fecha Nacimiento', _formatDate(_alumno!.fechaNacimiento)),
                        _buildInfo('Nacionalidad', _alumno!.nacionalidad),
                      ]),
                      _buildSeccion('Domicilio', [
                        _buildInfo('Direccion', _alumno!.direccionCompleta),
                      ]),
                      _buildSeccion('Contacto', [
                        _buildInfo('Email', _alumno!.email),
                        _buildInfo('Celular', _alumno!.celular),
                        if (_alumno!.telefono != null)
                          _buildInfo('Telefono', _alumno!.telefono!),
                        _buildInfo('Trabaja', _alumno!.trabaja ? 'Si' : 'No'),
                      ]),
                      if (_alumno!.contactoUrgenciaNombre != null)
                        _buildSeccion('Contacto de Urgencia', [
                          _buildInfo('Nombre', _alumno!.contactoUrgenciaNombre!),
                          if (_alumno!.contactoUrgenciaTelefono != null)
                            _buildInfo('Telefono', _alumno!.contactoUrgenciaTelefono!),
                          if (_alumno!.contactoUrgenciaVinculo != null)
                            _buildInfo('Vinculo', _alumno!.contactoUrgenciaVinculo!),
                        ]),
                      if (_legajo != null)
                        _buildSeccion('Documentacion', [
                          _buildInfo('DNI Frente', _legajo!.dniFrente != null ? 'Adjuntado' : 'Pendiente'),
                          _buildInfo('DNI Dorso', _legajo!.dniDorso != null ? 'Adjuntado' : 'Pendiente'),
                          if (_legajo!.nacidoFueraSantaFe)
                            _buildInfo('Partida Nacimiento', _legajo!.partidaNacimiento != null ? 'Adjuntada' : 'Pendiente'),
                          _buildInfo('Estado Titulo', _legajo!.estadoTituloTexto),
                        ]),
                      const SizedBox(height: 24),
                      _buildCambiarEstado(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                '${_alumno!.nombre[0]}${_alumno!.apellido[0]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _alumno!.nombreCompleto,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _alumno!.codigoInscripcion ?? 'Sin codigo',
                    style: const TextStyle(color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildActionButton(
                        Icons.chat,
                        'WhatsApp',
                        AppTheme.whatsappColor,
                        () => _abrirWhatsApp(),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        Icons.email,
                        'Email',
                        AppTheme.primaryColor,
                        () => _enviarEmail(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCambiarEstado() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cambiar Estado',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildEstadoButton('pendiente', 'Pendiente', AppTheme.warningColor),
                _buildEstadoButton('aprobado', 'Aprobar', AppTheme.successColor),
                _buildEstadoButton('rechazado', 'Rechazar', AppTheme.dangerColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoButton(String estado, String label, Color color) {
    final isSelected = _alumno?.estado == estado;
    return ElevatedButton(
      onPressed: isSelected ? null : () => _cambiarEstado(estado),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : color.withOpacity(0.1),
        foregroundColor: isSelected ? Colors.white : color,
        elevation: isSelected ? 2 : 0,
      ),
      child: Text(label),
    );
  }

  Future<void> _cambiarEstado(String estado) async {
    await _db.updateEstadoAlumno(_alumno!.id!, estado);
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $estado')),
      );
    }
  }

  Future<void> _abrirWhatsApp() async {
    final celular = _alumno!.celular.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/54$celular');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _enviarEmail() async {
    final uri = Uri.parse('mailto:${_alumno!.email}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
