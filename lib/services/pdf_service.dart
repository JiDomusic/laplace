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
    num? totalMonto,
    num? totalPagado,
    num? saldoPendiente,
  }) async {
    final pdf = pw.Document();
    final cicloLectivo = alumno.cicloLectivo ?? DateTime.now().year.toString();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Encabezado institucional
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Instituto Laplace', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_carrera, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_autorizacion, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),

            // Título y código
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1A237E'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FICHA DE INSCRIPCIÓN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Row(
                    children: [
                      pw.Text('Ciclo $cicloLectivo  |  ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(3)),
                        child: pw.Text(alumno.codigoInscripcion ?? 'PEND.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A237E'))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Nivel de inscripción (compacto)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                children: [
                  pw.Expanded(child: _buildFilaCompacta('Nivel', alumno.nivelInscripcion)),
                  pw.Expanded(child: _buildFilaCompacta('Cohorte', alumno.cicloLectivo ?? DateTime.now().year.toString())),
                  if (alumno.division != null) pw.Expanded(child: _buildFilaCompacta('División', alumno.division!)),
                  pw.Expanded(child: _buildFilaCompacta('Estado', alumno.estado.toUpperCase())),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Datos personales (2 filas compactas)
            _buildSeccionCompacta('DATOS PERSONALES', [
              pw.Row(children: [
                pw.Expanded(flex: 2, child: _buildFilaCompacta('Apellido y Nombre', alumno.nombreCompleto)),
                pw.Expanded(child: _buildFilaCompacta('DNI', alumno.dni)),
              ]),
              pw.Row(children: [
                pw.Expanded(child: _buildFilaCompacta('Sexo', alumno.sexo)),
                pw.Expanded(child: _buildFilaCompacta('Nacimiento', DateFormat('dd/MM/yyyy').format(alumno.fechaNacimiento))),
                pw.Expanded(child: _buildFilaCompacta('Nacionalidad', alumno.nacionalidad)),
              ]),
            ]),
            pw.SizedBox(height: 6),

            // Domicilio y contacto en una fila
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildSeccionCompacta('DOMICILIO', [
                    pw.Text(alumno.direccionCompleta, style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSeccionCompacta('CONTACTO', [
                    pw.Text('Email: ${alumno.email}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Cel: ${alumno.celular}', style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Situación laboral y urgencia en una fila
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildSeccionCompacta('SITUACIÓN LABORAL', [
                    pw.Text(alumno.trabaja ? 'Trabaja: SÍ' : 'Trabaja: NO', style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
                pw.SizedBox(width: 8),
                if (alumno.contactoUrgenciaNombre != null && alumno.contactoUrgenciaNombre!.isNotEmpty)
                  pw.Expanded(
                    child: _buildSeccionCompacta('CONTACTO URGENCIA', [
                      pw.Text('${alumno.contactoUrgenciaNombre}', style: const pw.TextStyle(fontSize: 8)),
                      if (alumno.contactoUrgenciaTelefono != null)
                        pw.Text('Tel: ${alumno.contactoUrgenciaTelefono}', style: const pw.TextStyle(fontSize: 8)),
                    ]),
                  )
                else
                  pw.Expanded(child: pw.SizedBox()),
              ],
            ),
            pw.SizedBox(height: 6),

            // Documentación
            _buildSeccionCompacta('DOCUMENTACIÓN', [
              pw.Row(children: [
                pw.Expanded(child: _buildCheckCompacto('DNI Frente', legajo?.dniFrente != null)),
                pw.Expanded(child: _buildCheckCompacto('DNI Dorso', legajo?.dniDorso != null)),
                pw.Expanded(child: _buildCheckCompacto('Partida Nac.', legajo?.partidaNacimiento != null)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Expanded(flex: 2, child: _buildFilaCompacta('Estado Título', legajo?.estadoTituloTexto ?? 'No especificado')),
                if (legajo?.estadoTitulo == 'terminado')
                  pw.Expanded(child: _buildCheckCompacto('Título adjunto', legajo?.tituloArchivo != null)),
                if (legajo?.estadoTitulo == 'en_tramite')
                  pw.Expanded(child: _buildCheckCompacto('Constancia trámite', legajo?.tramiteConstancia != null)),
              ]),
              if (legajo?.estadoTitulo == 'debe_materias' && legajo?.materiasAdeudadas != null)
                pw.Text('Materias adeudadas: ${legajo!.materiasAdeudadas}', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.SizedBox(height: 6),

            // Estado de cuotas (si hay)
            if (totalMonto != null && totalMonto > 0) ...[
              _buildSeccionCompacta('ESTADO DE CUOTAS', [
                pw.Row(children: [
                  pw.Expanded(child: _buildFilaCompacta('Total', _formatMoney(totalMonto))),
                  pw.Expanded(child: _buildFilaCompacta('Pagado', _formatMoney(totalPagado ?? 0))),
                  pw.Expanded(child: _buildFilaCompacta('Saldo', _formatMoney(saldoPendiente ?? 0))),
                ]),
              ]),
              pw.SizedBox(height: 6),
            ],

            // Observaciones (solo si hay)
            if (alumno.observaciones != null && alumno.observaciones!.isNotEmpty) ...[
              _buildSeccionCompacta('OBSERVACIONES', [
                pw.Text(alumno.observaciones!, style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.SizedBox(height: 6),
            ],

            // Espacio flexible
            pw.Spacer(),

            // Firmas
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 3),
                  pw.Text('Firma del Alumno/a', style: const pw.TextStyle(fontSize: 8)),
                ]),
                pw.Column(children: [
                  pw.Container(width: 160, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 3),
                  pw.Text('Sello y Firma Institución', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ],
            ),
            pw.SizedBox(height: 10),

            // Pie
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (alumno.fechaInscripcion != null)
                  pw.Text('Inscripción: ${DateFormat('dd/MM/yyyy').format(alumno.fechaInscripcion!)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text('Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSeccionCompacta(String titulo, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(4), topRight: pw.Radius.circular(4)),
            ),
            child: pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children)),
        ],
      ),
    );
  }

  static pw.Widget _buildFilaCompacta(String label, String valor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
        pw.Text(valor, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _buildCheckCompacto(String label, bool ok) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 10, height: 10,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(2)),
          child: ok ? pw.Center(child: pw.Text('✓', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green700))) : null,
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  static String _formatMoney(num value) {
    final formatted = value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return '\$$formatted';
  }

  /// Genera un PDF compacto con el detalle de cuotas de un alumno (1 hoja)
  static Future<Uint8List> generarDetalleCuotas(
    Alumno alumno,
    List<Cuota> cuotas, {
    int diaFinA = 10,
    int diaFinB = 20,
  }) async {
    final pdf = pw.Document();

    // Mostrar solo cuotas con pago (total o parcial) para no listar deudas
    final cuotasPagadas = cuotas.where((c) => c.montoPagado > 0 || c.estaPagada || c.esParcial).toList();

    // Calcular total pagado (enteros)
    final totalPagado = cuotasPagadas.fold<int>(0, (sum, c) => sum + c.montoPagado);

    // Ordenar cuotas por fecha de vencimiento
    final cuotasOrdenadas = List<Cuota>.from(cuotasPagadas)
      ..sort((a, b) {
        // Ordenar primero por fecha de pago (más reciente arriba); si no hay, por vencimiento.
        final fpA = a.fechaPago;
        final fpB = b.fechaPago;
        if (fpA != null && fpB != null) {
          return fpB.compareTo(fpA);
        } else if (fpA != null) {
          return -1;
        } else if (fpB != null) {
          return 1;
        }
        return a.fechaVencimiento.compareTo(b.fechaVencimiento);
      });

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Encabezado
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('INSTITUTO SUPERIOR LAPLACE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_carrera, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(_autorizacion, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 6),

            // Título y datos del alumno en una fila
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ESTADO DE CUENTA', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(alumno.nombreCompleto, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('DNI: ${alumno.dni}  |  ${alumno.nivelInscripcion}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PAGADO', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      pw.Text(
                        _formatMoney(totalPagado),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),

            // Resumen compacto
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('Pagado: ${_formatMoney(totalPagado)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  pw.Text('Cuotas con pago: ${cuotasPagadas.length}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Resumen del último pago como comprobante
            if (cuotasPagadas.any((c) => c.fechaPago != null)) ...[
              () {
                final pagosOrdenados = List<Cuota>.from(cuotasPagadas.where((c) => c.fechaPago != null))
                  ..sort((a, b) => b.fechaPago!.compareTo(a.fechaPago!));
                final ultimo = pagosOrdenados.first;
                final detalle = (ultimo.detallePago ?? '').isNotEmpty ? ultimo.detallePago! : (ultimo.esParcial ? 'Pago parcial' : 'Pago total');
                return pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Comprobante del último pago', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(ultimo.fechaPago!)}', style: const pw.TextStyle(fontSize: 9)),
                        if (ultimo.numRecibo != null && ultimo.numRecibo!.isNotEmpty)
                          pw.Text('Recibo: ${ultimo.numRecibo}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                      pw.SizedBox(height: 4),
                      pw.Text('Alumno: ${alumno.nombreCompleto}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Curso: ${alumno.nivelInscripcion}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Cuota: ${ultimo.concepto}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Importe: ${_formatMoney(ultimo.montoPagado)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Observaciones: $detalle', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                );
              }(),
              pw.SizedBox(height: 10),
            ],

            // Calendario visual compacto sólo con pagos
            _buildCalendarioCompacto(alumno, cuotasOrdenadas),
            pw.SizedBox(height: 10),

            // Tabla de cuotas compacta
            pw.Text('DETALLE DE PAGOS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (cuotasPagadas.isNotEmpty)
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1), // Fecha pago
                  1: const pw.FlexColumnWidth(1), // Importe
                  2: const pw.FlexColumnWidth(1), // Estado
                  3: const pw.FlexColumnWidth(3), // Detalle
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1A237E')),
                    children: [
                      _buildTableHeaderCompact('Fecha pago'),
                      _buildTableHeaderCompact('Importe'),
                      _buildTableHeaderCompact('Estado'),
                      _buildTableHeaderCompact('Detalle'),
                    ],
                  ),
                  ...cuotasOrdenadas.map((cuota) {
                    final estado = cuota.estaPagada ? 'PAGADA' : 'PARCIAL';
                    final estadoColor = cuota.estaPagada ? PdfColors.green700 : PdfColors.orange700;
                    final fechaPago = cuota.fechaPago != null
                        ? DateFormat('dd/MM/yy').format(cuota.fechaPago!)
                        : DateFormat('dd/MM/yy').format(cuota.fechaVencimiento);
                    final detalle = (cuota.detallePago ?? '').isNotEmpty
                        ? cuota.detallePago!
                        : cuota.esParcial
                            ? 'Pago parcial ${_formatMoney(cuota.montoPagado)}'
                            : 'Pago total ${cuota.concepto}';
                    return pw.TableRow(
                      children: [
                        _buildTableCellCompact(fechaPago),
                        _buildTableCellCompact(_formatMoney(cuota.montoPagado), color: PdfColors.green700),
                        _buildTableCellCompact(estado, color: estadoColor),
                        _buildTableCellCompact(detalle),
                      ],
                    );
                  }),
                ],
              )
            else
              pw.Text('No hay pagos registrados.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),

            // Espacio flexible para empujar pagos al final si hay espacio
            pw.Spacer(),

            // Detalle de pagos realizados (compacto)
            if (cuotasOrdenadas.any((c) => c.fechaPago != null)) ...[
              pw.Text('PAGOS REALIZADOS (con distribución de excedentes si aplica)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1), // Fecha
                  1: const pw.FlexColumnWidth(3), // Detalle
                  2: const pw.FlexColumnWidth(1), // Importe
                  3: const pw.FlexColumnWidth(0.8), // Método
                  4: const pw.FlexColumnWidth(0.8), // Recibo
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeaderCompact('Fecha', dark: false),
                      _buildTableHeaderCompact('Detalle', dark: false),
                      _buildTableHeaderCompact('Importe', dark: false),
                      _buildTableHeaderCompact('Forma', dark: false),
                      _buildTableHeaderCompact('Recibo', dark: false),
                    ],
                  ),
                  ...cuotasOrdenadas.where((c) => c.fechaPago != null).map((cuota) {
                    // Generar detalle descriptivo si no hay detalle_pago guardado
                    String detalle;
                    if (cuota.detallePago != null && cuota.detallePago!.isNotEmpty) {
                      detalle = cuota.detallePago!;
                    } else if (cuota.estaPagada) {
                      detalle = 'Pago total - ${cuota.concepto}';
                    } else if (cuota.esParcial) {
                      detalle = 'Pago parcial - ${cuota.concepto} (${_formatMoney(cuota.montoPagado)} de ${_formatMoney(cuota.montoActual)})';
                    } else {
                      detalle = cuota.concepto;
                    }
                    return pw.TableRow(
                      children: [
                        _buildTableCellCompact(DateFormat('dd/MM/yy').format(cuota.fechaPago!)),
                        _buildTableCellCompact(detalle),
                        _buildTableCellCompact(_formatMoney(cuota.montoPagado)),
                        _buildTableCellCompact(_metodoPagoCorto(cuota.metodoPago)),
                        _buildTableCellCompact(cuota.numRecibo ?? ''),
                      ],
                    );
                  }),
                ],
              ),
            ],
            pw.SizedBox(height: 8),

            // Pie
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Emitido: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text('INSTITUTO SUPERIOR LAPLACE - Sistema de Gestión', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static String _metodoPagoCorto(String? metodo) {
    if (metodo == null) return '';
    if (metodo.toLowerCase().contains('efect')) return 'Efvo.';
    if (metodo.toLowerCase().contains('transf')) return 'Transf.';
    return metodo;
  }

  static pw.Widget _buildTableHeaderCompact(String text, {bool dark = true}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: dark ? PdfColors.white : PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildTableCellCompact(String text, {PdfColor? color}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 7, color: color)),
    );
  }

  static pw.Widget _buildCalendarioCompacto(Alumno alumno, List<Cuota> cuotas) {
    final esPrimerAnio = alumno.nivelInscripcion == 'Primer Año';
    final meses = const [
      {'mes': 1, 'label': 'Ene'},
      {'mes': 2, 'label': 'Feb'},
      {'mes': 3, 'label': 'Mar'},
      {'mes': 4, 'label': 'Abr'},
      {'mes': 5, 'label': 'May'},
      {'mes': 6, 'label': 'Jun'},
      {'mes': 7, 'label': 'Jul'},
      {'mes': 8, 'label': 'Ago'},
      {'mes': 9, 'label': 'Sep'},
      {'mes': 10, 'label': 'Oct'},
      {'mes': 11, 'label': 'Nov'},
      {'mes': 12, 'label': 'Dic'},
    ];

    final cuotasPorMes = <int, Cuota?>{for (final m in meses) m['mes'] as int: null};
    Cuota? inscripcion;
    for (final c in cuotas) {
      if (c.concepto.toLowerCase().contains('inscripción')) {
        inscripcion = c;
      } else {
        cuotasPorMes[c.mes] = c;
      }
    }

    PdfColor colorEstado(Cuota? c) {
      if (c == null) return PdfColors.grey300;
      if (c.estaPagada) return PdfColors.green400;
      if (c.esParcial) return PdfColors.orange400;
      if (c.estaVencida) return PdfColors.red400;
      return PdfColors.grey300;
    }

    final celdas = <pw.Widget>[];
    if (esPrimerAnio) {
      celdas.add(pw.Container(
        width: 22,
        height: 16,
        margin: const pw.EdgeInsets.all(1),
        decoration: pw.BoxDecoration(color: colorEstado(inscripcion), borderRadius: pw.BorderRadius.circular(2)),
        alignment: pw.Alignment.center,
        child: pw.Text('Insc', style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ));
    }
    for (final m in meses) {
      final mesNum = m['mes'] as int;
      final cuota = cuotasPorMes[mesNum];
      celdas.add(pw.Container(
        width: 22,
        height: 16,
        margin: const pw.EdgeInsets.all(1),
        decoration: pw.BoxDecoration(color: colorEstado(cuota), borderRadius: pw.BorderRadius.circular(2)),
        alignment: pw.Alignment.center,
        child: pw.Text(m['label'] as String, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ));
    }

    return pw.Wrap(
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        pw.Text('Cuotas: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ...celdas,
        pw.SizedBox(width: 6),
        pw.Container(width: 8, height: 8, color: PdfColors.green400),
        pw.Text(' Pagada ', style: const pw.TextStyle(fontSize: 6)),
        pw.Container(width: 8, height: 8, color: PdfColors.orange400),
        pw.Text(' Parcial ', style: const pw.TextStyle(fontSize: 6)),
        pw.Container(width: 8, height: 8, color: PdfColors.red400),
        pw.Text(' Vencida ', style: const pw.TextStyle(fontSize: 6)),
        pw.Container(width: 8, height: 8, color: PdfColors.grey300),
        pw.Text(' Pend.', style: const pw.TextStyle(fontSize: 6)),
      ],
    );
  }
}
