import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/alumno.dart';

class PdfService {
  static Future<Uint8List> generarComprobante(Alumno alumno) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1A237E'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'INSTITUTO LAPLACE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Rosario, Santa Fe - Fundado en 1992',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Título
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#1A237E'), width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'COMPROBANTE DE INSCRIPCION',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1A237E'),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Ciclo Lectivo 2026'),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1A237E'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        alumno.codigoInscripcion ?? 'SIN CODIGO',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Nivel
              _buildSeccion('NIVEL DE INSCRIPCION', [
                pw.Center(
                  child: pw.Text(
                    alumno.nivelInscripcion,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1A237E'),
                    ),
                  ),
                ),
              ]),
              pw.SizedBox(height: 15),

              // Datos Personales
              _buildSeccion('DATOS PERSONALES', [
                _buildFila('Apellido y Nombre', alumno.nombreCompleto),
                _buildFila('DNI', alumno.dni),
                _buildFila('Sexo', alumno.sexo),
                _buildFila('Fecha de Nacimiento', DateFormat('dd/MM/yyyy').format(alumno.fechaNacimiento)),
                _buildFila('Nacionalidad', alumno.nacionalidad),
              ]),
              pw.SizedBox(height: 15),

              // Domicilio
              _buildSeccion('DOMICILIO', [
                _buildFila('Direccion', alumno.direccionCompleta),
              ]),
              pw.SizedBox(height: 15),

              // Contacto
              _buildSeccion('CONTACTO', [
                _buildFila('Email', alumno.email),
                _buildFila('Celular', alumno.celular),
                if (alumno.telefono != null && alumno.telefono!.isNotEmpty)
                  _buildFila('Telefono', alumno.telefono!),
              ]),
              pw.SizedBox(height: 30),

              // Firmas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma del Alumno/a', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Sello y Firma Institucion', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Fecha de Emision: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (alumno.fechaInscripcion != null)
                      pw.Text(
                        'Fecha de Inscripcion: ${DateFormat('dd/MM/yyyy HH:mm').format(alumno.fechaInscripcion!)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Este comprobante debe ser presentado en el instituto. Tel: 341-3513973',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSeccion(String titulo, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              titulo,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              '$label:',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
