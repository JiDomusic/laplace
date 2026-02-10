class Cuota {
  final String? id;
  final String alumnoId;
  final String concepto;
  final int montoAlDia; // Monto si paga en término
  final int monto1erVto; // Monto 1er vencimiento
  final int monto2doVto; // Monto 2do vencimiento (máximo)
  final int montoPagado; // Total pagado (para pagos parciales)
  final int mes;
  final int anio;
  final DateTime fechaVencimiento;
  final DateTime? fechaPago;
  final String estado; // pendiente, pagada, vencida, parcial
  final String? metodoPago;
  final String? observaciones;
  final String? numRecibo;
  final String? detallePago;
  final int diaFinRangoA;
  final int diaFinRangoB;

  Cuota({
    this.id,
    required this.alumnoId,
    required this.concepto,
    required this.montoAlDia,
    required this.monto1erVto,
    required this.monto2doVto,
    this.montoPagado = 0,
    this.diaFinRangoA = 10,
    this.diaFinRangoB = 20,
    required this.mes,
    required this.anio,
    required this.fechaVencimiento,
    this.fechaPago,
    this.estado = 'pendiente',
    this.metodoPago,
    this.observaciones,
    this.numRecibo,
    this.detallePago,
  });

  /// Obtiene el monto que corresponde según el día actual
  int get montoActual {
    final hoy = DateTime.now();
    final finA = diaFinRangoA;
    final finB = diaFinRangoB;

    // Si ya está pagada, devolver el monto al día (base)
    if (estaPagada) return montoAlDia;

    // Si la cuota está vencida (pasó el mes), máximo recargo
    if (fechaVencimiento.isBefore(DateTime(hoy.year, hoy.month, 1))) {
      return monto2doVto;
    }

    // Si estamos en el mes de vencimiento, calcular según día
    if (fechaVencimiento.year == hoy.year && fechaVencimiento.month == hoy.month) {
      if (hoy.day <= finA) {
        return montoAlDia;
      } else if (hoy.day <= finB) {
        return monto1erVto;
      } else {
        return monto2doVto;
      }
    }

    // Cuota futura, sin recargo
    return montoAlDia;
  }

  /// Calcula la deuda restante basada en el monto actual
  int get deuda => montoActual - montoPagado;

  /// Monto base (al día) - para compatibilidad
  int get monto => montoAlDia;

  /// Verifica si tiene pago parcial
  bool get esParcial => montoPagado > 0 && montoPagado < montoActual;

  /// Verifica si está pagada completamente
  bool get estaPagada => montoPagado >= montoAlDia || estado == 'pagada';

  /// Verifica si está vencida
  bool get estaVencida => estado != 'pagada' && fechaVencimiento.isBefore(DateTime.now());

  /// Obtiene el rango actual de vencimiento
  String get rangoActual {
    final hoy = DateTime.now();
    if (fechaVencimiento.isBefore(DateTime(hoy.year, hoy.month, 1))) {
      return 'C';
    }
    if (fechaVencimiento.year == hoy.year && fechaVencimiento.month == hoy.month) {
      if (hoy.day <= 10) return 'A';
      if (hoy.day <= 20) return 'B';
      return 'C';
    }
    return 'A';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alumno_id': alumnoId,
      'concepto': concepto,
      'monto_al_dia': montoAlDia,
      'monto_1er_vto': monto1erVto,
      'monto_2do_vto': monto2doVto,
      'monto_pagado': montoPagado,
      'dia_fin_rango_a': diaFinRangoA,
      'dia_fin_rango_b': diaFinRangoB,
      'mes': mes,
      'anio': anio,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'fecha_pago': fechaPago?.toIso8601String(),
      'estado': estado,
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
      'num_recibo': numRecibo,
      'detalle_pago': detallePago,
    };
  }

  factory Cuota.fromMap(Map<String, dynamic> map) {
    // Compatibilidad con estructura anterior (monto único)
    final montoAnterior = (map['monto'] as num?)?.toInt();
    final montoAlDia = (map['monto_al_dia'] as num?)?.toInt() ?? montoAnterior ?? 0;
    final monto1erVto = (map['monto_1er_vto'] as num?)?.toInt() ?? montoAlDia;
    final monto2doVto = (map['monto_2do_vto'] as num?)?.toInt() ?? monto1erVto;
    final diaFinRangoA = (map['dia_fin_rango_a'] as num?)?.toInt() ?? 10;
    final diaFinRangoB = (map['dia_fin_rango_b'] as num?)?.toInt() ?? 20;

    return Cuota(
      id: map['id']?.toString(),
      alumnoId: map['alumno_id']?.toString() ?? '',
      concepto: map['concepto'] ?? '',
      montoAlDia: montoAlDia,
      monto1erVto: monto1erVto,
      monto2doVto: monto2doVto,
      montoPagado: (map['monto_pagado'] as num?)?.toInt() ?? 0,
      diaFinRangoA: diaFinRangoA,
      diaFinRangoB: diaFinRangoB,
      mes: map['mes'] ?? 1,
      anio: map['anio'] ?? DateTime.now().year,
      fechaVencimiento: map['fecha_vencimiento'] != null
          ? DateTime.parse(map['fecha_vencimiento'])
          : DateTime.now(),
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
      estado: map['estado'] ?? 'pendiente',
      metodoPago: map['metodo_pago'],
      observaciones: map['observaciones'],
      numRecibo: map['num_recibo'],
      detallePago: map['detalle_pago'],
    );
  }

  Cuota copyWith({
    String? id,
    String? alumnoId,
    String? concepto,
    int? montoAlDia,
    int? monto1erVto,
    int? monto2doVto,
    int? montoPagado,
    int? mes,
    int? anio,
    DateTime? fechaVencimiento,
    DateTime? fechaPago,
    String? estado,
    String? metodoPago,
    String? observaciones,
    String? numRecibo,
    String? detallePago,
    int? diaFinRangoA,
    int? diaFinRangoB,
  }) {
    return Cuota(
      id: id ?? this.id,
      alumnoId: alumnoId ?? this.alumnoId,
      concepto: concepto ?? this.concepto,
      montoAlDia: montoAlDia ?? this.montoAlDia,
      monto1erVto: monto1erVto ?? this.monto1erVto,
      monto2doVto: monto2doVto ?? this.monto2doVto,
      montoPagado: montoPagado ?? this.montoPagado,
      diaFinRangoA: diaFinRangoA ?? this.diaFinRangoA,
      diaFinRangoB: diaFinRangoB ?? this.diaFinRangoB,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaPago: fechaPago ?? this.fechaPago,
      estado: estado ?? this.estado,
      metodoPago: metodoPago ?? this.metodoPago,
      observaciones: observaciones ?? this.observaciones,
      numRecibo: numRecibo ?? this.numRecibo,
      detallePago: detallePago ?? this.detallePago,
    );
  }

  static String nombreMes(int mes) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }
}
