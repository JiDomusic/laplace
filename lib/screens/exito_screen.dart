import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import '../providers/inscripcion_provider.dart';
import '../utils/app_theme.dart';
import '../services/pdf_service.dart';

class ExitoScreen extends StatelessWidget {
  const ExitoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<InscripcionProvider>();
    final alumno = provider.alumnoRegistrado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscripcion Exitosa'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Icono de éxito
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Inscripcion Registrada',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'La inscripcion del alumno ha sido registrada correctamente.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Código de inscripción
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.confirmation_number, color: AppTheme.primaryColor),
                    const SizedBox(height: 8),
                    const Text('Codigo de Inscripcion'),
                    const SizedBox(height: 4),
                    Text(
                      alumno?.codigoInscripcion ?? 'LAP-2026-00001',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Guarda este codigo para futuras consultas',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Resumen
            if (alumno != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen de la Inscripcion',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Divider(),
                      _buildResumenItem('Nombre', alumno.nombreCompleto),
                      _buildResumenItem('DNI', alumno.dni),
                      _buildResumenItem('Nivel', alumno.nivelInscripcion),
                      _buildResumenItem('Email', alumno.email),
                      _buildResumenItem('Celular', alumno.celular),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Recordatorios para admin
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) {
                    final esPrimerAnio = alumno?.nivelInscripcion.toLowerCase().contains('primer') ?? false;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recordatorios',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Divider(),
                        if (esPrimerAnio)
                          _buildRecordatorioItem(
                            Icons.group,
                            'Asignar al alumno a seccion A o B',
                          ),
                        _buildRecordatorioItem(
                          Icons.checklist,
                          'Verificar documentacion y marcar estado: Aprobado o Pendiente',
                        ),
                        _buildRecordatorioItem(
                          Icons.download,
                          'Descargar comprobante para firma del alumno/tutor',
                        ),
                        _buildRecordatorioItem(
                          Icons.badge,
                          'Solicitar copia de DNI del alumno',
                        ),
                        _buildRecordatorioItem(
                          Icons.send,
                          'Enviar comprobante firmado por WhatsApp si corresponde',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Botones
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (alumno != null) {
                      final pdfData = await PdfService.generarComprobante(
                        alumno,
                        totalMonto: null,
                        totalPagado: null,
                        saldoPendiente: null,
                      );
                    await Printing.layoutPdf(onLayout: (_) => pdfData);
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Descargar Comprobante para Firma'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final codigo = alumno?.codigoInscripcion ?? '';
                  final nombre = alumno?.nombreCompleto ?? '';
                  final celular = alumno?.celular ?? '';
                  // Usar el celular del alumno/tutor si está disponible
                  final telefono = celular.isNotEmpty ? celular : '5493413513973';
                  final uri = Uri.parse(
                    'https://wa.me/$telefono?text=Hola,%20le%20informamos%20que%20la%20inscripcion%20de%20$nombre%20(Codigo:%20$codigo)%20ha%20sido%20registrada.%20Adjuntamos%20el%20comprobante%20para%20su%20firma.',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Enviar Comprobante por WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.whatsappColor,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
                provider.reset();
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text('Volver al Inicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRecordatorioItem(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
