import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/alumno.dart';
import '../models/cuota.dart';

class PdfService {
  static Future<Uint8List> generarComprobante(
    Alumno alumno, {
    double? totalMonto,
    double? totalPagado,
    double? saldoPendiente,
  }) async {
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

              // Estado de cuotas
              _buildSeccion('ESTADO DE CUOTAS', [
                _buildFila('Monto total asignado', totalMonto != null ? _formatMoney(totalMonto) : 'Pendiente de asignar'),
                _buildFila('Pagado', totalPagado != null ? _formatMoney(totalPagado) : 'Pendiente'),
                _buildFila('Saldo pendiente', saldoPendiente != null ? _formatMoney(saldoPendiente) : 'Pendiente'),
              ]),
              pw.SizedBox(height: 20),

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

  static String _formatMoney(double value) {
    final formatted = value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '\$$formatted';
  }

  /// Genera un PDF con el detalle de cuotas de un alumno
  static Future<Uint8List> generarDetalleCuotas(
    Alumno alumno,
    List<Cuota> cuotas,
  ) async {
    final pdf = pw.Document();

    // Calcular totales
    double totalMonto = 0;
    double totalPagado = 0;
    for (final cuota in cuotas) {
      totalMonto += cuota.monto;
      totalPagado += cuota.montoPagado;
    }
    final totalDeuda = totalMonto - totalPagado;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1A237E'),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'INSTITUTO LAPLACE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'Rosario, Santa Fe',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  ),
                ],
              ),
              pw.Text(
                'DETALLE DE CUOTAS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'Pagina ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 15),

          // Datos del alumno
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        alumno.nombreCompleto,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('DNI: ${alumno.dni}', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Nivel: ${alumno.nivelInscripcion}${alumno.division != null ? ' - ${alumno.division}' : ''}', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Codigo: ${alumno.codigoInscripcion ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('Email: ${alumno.email}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Tel: ${alumno.celular}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // Resumen
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('TOTAL', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(_formatMoney(totalMonto), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('PAGADO', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(_formatMoney(totalPagado), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('ADEUDA', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(_formatMoney(totalDeuda), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: totalDeuda > 0 ? PdfColors.red700 : PdfColors.green700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Tabla de cuotas
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5), // Concepto
              1: const pw.FlexColumnWidth(1.2), // Vencimiento
              2: const pw.FlexColumnWidth(1), // Monto
              3: const pw.FlexColumnWidth(1), // Pagado
              4: const pw.FlexColumnWidth(1), // Deuda
              5: const pw.FlexColumnWidth(1), // Estado
              6: const pw.FlexColumnWidth(1), // Recibo
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1A237E')),
                children: [
                  _buildTableHeader('Concepto'),
                  _buildTableHeader('Vence'),
                  _buildTableHeader('Monto'),
                  _buildTableHeader('Pagado'),
                  _buildTableHeader('Deuda'),
                  _buildTableHeader('Estado'),
                  _buildTableHeader('Recibo'),
                ],
              ),
              // Filas de cuotas
              ...cuotas.map((cuota) {
                final estado = cuota.estaPagada
                    ? 'PAGADA'
                    : cuota.esParcial
                        ? 'PARCIAL'
                        : cuota.estaVencida
                            ? 'VENCIDA'
                            : 'PENDIENTE';
                final estadoColor = cuota.estaPagada
                    ? PdfColors.green700
                    : cuota.estaVencida
                        ? PdfColors.red700
                        : PdfColors.orange700;

                return pw.TableRow(
                  children: [
                    _buildTableCell(cuota.concepto),
                    _buildTableCell(DateFormat('dd/MM/yy').format(cuota.fechaVencimiento)),
                    _buildTableCell(_formatMoney(cuota.monto)),
                    _buildTableCell(_formatMoney(cuota.montoPagado), color: PdfColors.green700),
                    _buildTableCell(_formatMoney(cuota.deuda), color: cuota.deuda > 0 ? PdfColors.red700 : null),
                    _buildTableCell(estado, color: estadoColor),
                    _buildTableCell(cuota.numRecibo ?? '-'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // Detalle de pagos realizados
          if (cuotas.any((c) => c.fechaPago != null)) ...[
            pw.Text(
              'DETALLE DE PAGOS REALIZADOS',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5), // Fecha
                1: const pw.FlexColumnWidth(2.5), // Concepto/Detalle
                2: const pw.FlexColumnWidth(1), // Importe
                3: const pw.FlexColumnWidth(1), // Metodo
                4: const pw.FlexColumnWidth(1), // Recibo
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Fecha', dark: false),
                    _buildTableHeader('Detalle', dark: false),
                    _buildTableHeader('Importe', dark: false),
                    _buildTableHeader('Metodo', dark: false),
                    _buildTableHeader('N° Recibo', dark: false),
                  ],
                ),
                ...cuotas.where((c) => c.fechaPago != null).map((cuota) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(DateFormat('dd/MM/yy').format(cuota.fechaPago!)),
                      _buildTableCell(cuota.detallePago ?? cuota.concepto),
                      _buildTableCell(_formatMoney(cuota.montoPagado)),
                      _buildTableCell(cuota.metodoPago ?? '-'),
                      _buildTableCell(cuota.numRecibo ?? '-'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableHeader(String text, {bool dark = true}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: dark ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, color: color),
      ),
    );
  }
}
