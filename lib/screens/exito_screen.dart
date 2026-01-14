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
              'Inscripcion Enviada Exitosamente',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.successColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu solicitud de inscripcion ha sido recibida correctamente.',
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
                        'Resumen de tu Inscripcion',
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

            // Próximos pasos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proximos Pasos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(),
                    _buildPasoItem(1, 'Descarga tu comprobante de inscripcion'),
                    _buildPasoItem(2, 'Presentate en el instituto con el comprobante'),
                    _buildPasoItem(3, 'Envianos tu comprobante de pago por WhatsApp'),
                    _buildPasoItem(4, 'El equipo revisara tu documentacion'),
                    _buildPasoItem(5, 'Recibiras confirmacion por WhatsApp'),
                  ],
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
                label: const Text('Descargar Comprobante PDF'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final codigo = alumno?.codigoInscripcion ?? '';
                  final uri = Uri.parse(
                    'https://wa.me/5493413513973?text=Hola,%20acabo%20de%20completar%20mi%20inscripcion.%20Mi%20codigo%20es:%20$codigo.%20Adjunto%20mi%20comprobante%20de%20pago.',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.chat),
                label: const Text('Contactar por WhatsApp'),
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

  Widget _buildPasoItem(int numero, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$numero',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
