import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/alumno.dart';
import '../models/cuota.dart';
import '../models/legajo.dart';

class PdfService {
  static const String _carrera = 'Técnico Superior en Seguridad e Higiene en el Trabajo';
  static const String _autorizacion = 'Autorizado a la enseñanza oficial N°9250';

  static Future<Uint8List> generarComprobante(
    Alumno alumno, {
    Legajo? legajo,
    double? totalMonto,
    double? totalPagado,
    double? saldoPendiente,
  }) async {
    final pdf = pw.Document();
    final cicloLectivo = alumno.cicloLectivo ?? DateTime.now().year.toString();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Center(
            child: pw.Text(
              'Instituto de Enseñanza Oficial Laplace',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 10),

          // Título del documento
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#1A237E'), width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'FICHA DE INSCRIPCIÓN',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1A237E'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Ciclo lectivo: ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      cicloLectivo,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text('Código: ', style: const pw.TextStyle(fontSize: 10)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1A237E'),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        alumno.codigoInscripcion ?? 'PENDIENTE',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // Nivel de Inscripción
          _buildSeccion('NIVEL DE INSCRIPCION', [
            pw.Row(
              children: [
                pw.Expanded(child: _buildFila('Nivel', alumno.nivelInscripcion)),
                pw.Expanded(child: _buildFila('Division', alumno.division ?? 'Sin asignar')),
                pw.Expanded(child: _buildFila('Estado', alumno.estado.toUpperCase())),
              ],
            ),
          ]),
          pw.SizedBox(height: 10),

          // Datos Personales
          _buildSeccion('DATOS PERSONALES', [
            pw.Row(
              children: [
                pw.Expanded(flex: 2, child: _buildFila('Apellido y Nombre', alumno.nombreCompleto)),
                pw.Expanded(child: _buildFila('DNI', alumno.dni)),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(child: _buildFila('Sexo', alumno.sexo)),
                pw.Expanded(child: _buildFila('Fecha Nacimiento', DateFormat('dd/MM/yyyy').format(alumno.fechaNacimiento))),
                pw.Expanded(child: _buildFila('Nacionalidad', alumno.nacionalidad)),
              ],
            ),
            if (alumno.localidadNacimiento != null || alumno.provinciaNacimiento != null)
              pw.Row(
                children: [
                  pw.Expanded(child: _buildFila('Localidad Nac.', alumno.localidadNacimiento ?? '-')),
                  pw.Expanded(child: _buildFila('Provincia Nac.', alumno.provinciaNacimiento ?? '-')),
                ],
              ),
          ]),
          pw.SizedBox(height: 10),

          // Domicilio
          _buildSeccion('DOMICILIO', [
            _buildFila('Direccion', alumno.direccionCompleta),
          ]),
          pw.SizedBox(height: 10),

          // Contacto
          _buildSeccion('CONTACTO', [
            pw.Row(
              children: [
                pw.Expanded(child: _buildFila('Email', alumno.email)),
                pw.Expanded(child: _buildFila('Celular', alumno.celular)),
              ],
            ),
            if (alumno.telefono != null && alumno.telefono!.isNotEmpty)
              _buildFila('Telefono Fijo', alumno.telefono!),
          ]),
          pw.SizedBox(height: 10),

          // Situación Laboral
          _buildSeccion('SITUACION LABORAL', [
            _buildFila('¿Trabaja?', alumno.trabaja ? 'SI' : 'NO'),
          ]),
          pw.SizedBox(height: 10),

          // Contacto de Urgencia
          if (alumno.contactoUrgenciaNombre != null && alumno.contactoUrgenciaNombre!.isNotEmpty)
            _buildSeccion('CONTACTO DE URGENCIA', [
              pw.Row(
                children: [
                  pw.Expanded(child: _buildFila('Nombre', alumno.contactoUrgenciaNombre!)),
                  pw.Expanded(child: _buildFila('Telefono', alumno.contactoUrgenciaTelefono ?? '-')),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(child: _buildFila('Vinculo', alumno.contactoUrgenciaVinculo ?? '-')),
                  if (alumno.contactoUrgenciaOtro != null && alumno.contactoUrgenciaOtro!.isNotEmpty)
                    pw.Expanded(child: _buildFila('Detalle', alumno.contactoUrgenciaOtro!)),
                ],
              ),
            ]),
          if (alumno.contactoUrgenciaNombre != null && alumno.contactoUrgenciaNombre!.isNotEmpty)
            pw.SizedBox(height: 10),

          // Documentación / Legajo
          _buildSeccion('DOCUMENTACION', [
            pw.Row(
              children: [
                pw.Expanded(child: _buildFilaCheck('DNI Frente', legajo?.dniFrente != null)),
                pw.Expanded(child: _buildFilaCheck('DNI Dorso', legajo?.dniDorso != null)),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(child: _buildFilaCheck('Partida Nacimiento', legajo?.partidaNacimiento != null)),
                pw.Expanded(child: _buildFila('Estado Titulo', legajo?.estadoTituloTexto ?? 'No especificado')),
              ],
            ),
            if (legajo != null) ...[
              if (legajo.estadoTitulo == 'terminado')
                _buildFilaCheck('Titulo Legalizado/Digital', legajo.tituloArchivo != null),
              if (legajo.estadoTitulo == 'en_tramite')
                _buildFilaCheck('Constancia de Titulo en Tramite', legajo.tramiteConstancia != null),
              if (legajo.estadoTitulo == 'debe_materias') ...[
                _buildFila('Materias Adeudadas', legajo.materiasAdeudadas ?? '-'),
                _buildFilaCheck('Certificado de Estudios Incompletos', legajo.materiasConstancia != null),
              ],
            ],
            if (alumno.observacionesTitulo != null && alumno.observacionesTitulo!.isNotEmpty)
              _buildFila('Observaciones Titulo', alumno.observacionesTitulo!),
          ]),
          pw.SizedBox(height: 10),

          // Estado de cuotas (si hay datos)
          if (totalMonto != null && totalMonto > 0)
            _buildSeccion('ESTADO DE CUOTAS', [
              pw.Row(
                children: [
                  pw.Expanded(child: _buildFila('Monto Total', _formatMoney(totalMonto))),
                  pw.Expanded(child: _buildFila('Pagado', _formatMoney(totalPagado ?? 0))),
                  pw.Expanded(child: _buildFila('Saldo', _formatMoney(saldoPendiente ?? 0))),
                ],
              ),
            ]),
          if (totalMonto != null && totalMonto > 0)
            pw.SizedBox(height: 10),

          // Observaciones
          if (alumno.observaciones != null && alumno.observaciones!.isNotEmpty)
            _buildSeccion('OBSERVACIONES', [
              pw.Text(alumno.observaciones!, style: const pw.TextStyle(fontSize: 10)),
            ]),
          if (alumno.observaciones != null && alumno.observaciones!.isNotEmpty)
            pw.SizedBox(height: 10),

          pw.SizedBox(height: 20),

          // Firmas
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 180, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Firma del Alumno/a', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 180, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Sello y Firma Institucion', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 15),

          // Información final
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                if (alumno.fechaInscripcion != null)
                  pw.Text(
                    'Fecha de Inscripcion: ${DateFormat('dd/MM/yyyy HH:mm').format(alumno.fechaInscripcion!)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Este documento debe ser presentado en el instituto. Tel: 341-3513973',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildFilaCheck(String label, bool completado) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            completado ? '[X] Adjuntado' : '[ ] Pendiente',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: completado ? PdfColors.green700 : PdfColors.orange700,
            ),
          ),
        ],
      ),
    );
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

  static pw.Widget _buildFila(String label, String valor, {bool compacto = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(color: PdfColors.grey700, fontSize: compacto ? 8 : 9),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            valor,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: compacto ? 9 : 10),
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        header: (_) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Center(
            child: pw.Text(
              'Instituto de Enseñanza Oficial Laplace',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
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
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('DNI: ${alumno.dni}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Nivel: ${alumno.nivelInscripcion}${alumno.division != null ? ' - ${alumno.division}' : ''}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Código: ${alumno.codigoInscripcion ?? 'N/A'}', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    pw.Text('Email: ${alumno.email}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Tel: ${alumno.celular}', style: const pw.TextStyle(fontSize: 9)),
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
              0: const pw.FlexColumnWidth(2.2), // Concepto
              1: const pw.FlexColumnWidth(1.1), // Vencimiento
              2: const pw.FlexColumnWidth(0.9), // Monto
              3: const pw.FlexColumnWidth(0.9), // Pagado
              4: const pw.FlexColumnWidth(0.9), // Deuda
              5: const pw.FlexColumnWidth(0.9), // Estado
              6: const pw.FlexColumnWidth(0.9), // Recibo
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

          // Calendario visual de pagos (una fila por alumno)
          _buildCalendarioVisual(alumno, cuotas),

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
                0: const pw.FlexColumnWidth(1.4), // Fecha
                1: const pw.FlexColumnWidth(2.2), // Concepto/Detalle
                2: const pw.FlexColumnWidth(0.9), // Importe
                3: const pw.FlexColumnWidth(0.9), // Metodo
                4: const pw.FlexColumnWidth(0.9), // Recibo
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('Fecha', dark: false),
                    _buildTableHeader('Detalle', dark: false),
                    _buildTableHeader('Importe', dark: false),
                    _buildTableHeader('Método', dark: false),
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
          fontSize: 8,
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
        style: pw.TextStyle(fontSize: 8, color: color),
      ),
    );
  }

  // Calendario visual de cuotas (pagada/parcial/pendiente)
  static pw.Widget _buildCalendarioVisual(Alumno alumno, List<Cuota> cuotas) {
    final esPrimerAnio = alumno.nivelInscripcion == 'Primer Año';
    final meses = esPrimerAnio
        ? <int>[3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        : <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    // Estado por mes
    Map<int, Cuota?> cuotasPorMes = {for (var m in meses) m: null};
    for (final c in cuotas) {
      if (cuotasPorMes.containsKey(c.mes)) {
        cuotasPorMes[c.mes] = c;
      }
    }

    // Inscripción (solo 1.er año)
    Cuota? inscripcion;
    for (final c in cuotas) {
      if (c.concepto.toLowerCase().contains('inscripción')) {
        inscripcion = c;
        break;
      }
    }

    pw.Widget _celdaEstado(Cuota? c) {
      String simbolo = '';
      PdfColor color = PdfColors.grey600;
      if (c != null) {
        if (c.estaPagada) {
          simbolo = '✔';
          color = PdfColors.green700;
        } else if (c.esParcial) {
          simbolo = '•';
          color = PdfColors.orange700;
        } else if (c.estaVencida) {
          simbolo = 'X';
          color = PdfColors.red700;
        } else {
          simbolo = '';
          color = PdfColors.grey600;
        }
      }
      return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        alignment: pw.Alignment.center,
        child: pw.Text(simbolo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
      );
    }

    final headers = <pw.Widget>[
      if (esPrimerAnio) pw.Text('Insc.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ...meses.map((m) => pw.Text(Cuota.nombreMes(m).substring(0, 3), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
    ];

    final estados = <pw.Widget>[
      if (esPrimerAnio) _celdaEstado(inscripcion),
      ...meses.map((m) => _celdaEstado(cuotasPorMes[m])),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Calendario de pagos', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Row(children: headers.map((h) => pw.Expanded(child: h)).toList()),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
          child: pw.Row(children: estados.map((h) => pw.Expanded(child: h)).toList()),
        ),
        pw.SizedBox(height: 6),
        pw.Text('✔ pagada   • parcial   X vencida   (vacío = pendiente)', style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }
}
