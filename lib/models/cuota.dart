class Cuota {
  final String? id;
  final String alumnoId;
  final String concepto;
  final double monto;
  final double montoPagado; // Para pagos parciales
  final int mes;
  final int anio;
  final DateTime fechaVencimiento;
  final DateTime? fechaPago;
  final String estado; // pendiente, pagada, vencida, parcial
  final String? metodoPago;
  final String? observaciones;

  Cuota({
    this.id,
    required this.alumnoId,
    required this.concepto,
    required this.monto,
    this.montoPagado = 0,
    required this.mes,
    required this.anio,
    required this.fechaVencimiento,
    this.fechaPago,
    this.estado = 'pendiente',
    this.metodoPago,
    this.observaciones,
  });

  // Calcula la deuda restante
  double get deuda => monto - montoPagado;

  // Verifica si tiene pago parcial
  bool get esParcial => montoPagado > 0 && montoPagado < monto;

  // Verifica si esta pagada completamente
  bool get estaPagada => montoPagado >= monto || estado == 'pagada';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alumno_id': alumnoId,
      'concepto': concepto,
      'monto': monto,
      'monto_pagado': montoPagado,
      'mes': mes,
      'anio': anio,
      'fecha_vencimiento': fechaVencimiento.toIso8601String(),
      'fecha_pago': fechaPago?.toIso8601String(),
      'estado': estado,
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
    };
  }

  factory Cuota.fromMap(Map<String, dynamic> map) {
    return Cuota(
      id: map['id']?.toString(),
      alumnoId: map['alumno_id']?.toString() ?? '',
      concepto: map['concepto'],
      monto: (map['monto'] as num).toDouble(),
      montoPagado: (map['monto_pagado'] as num?)?.toDouble() ?? 0,
      mes: map['mes'],
      anio: map['anio'],
      fechaVencimiento: DateTime.parse(map['fecha_vencimiento']),
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
      estado: map['estado'] ?? 'pendiente',
      metodoPago: map['metodo_pago'],
      observaciones: map['observaciones'],
    );
  }

  Cuota copyWith({
    String? id,
    String? alumnoId,
    String? concepto,
    double? monto,
    double? montoPagado,
    int? mes,
    int? anio,
    DateTime? fechaVencimiento,
    DateTime? fechaPago,
    String? estado,
    String? metodoPago,
    String? observaciones,
  }) {
    return Cuota(
      id: id ?? this.id,
      alumnoId: alumnoId ?? this.alumnoId,
      concepto: concepto ?? this.concepto,
      monto: monto ?? this.monto,
      montoPagado: montoPagado ?? this.montoPagado,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaPago: fechaPago ?? this.fechaPago,
      estado: estado ?? this.estado,
      metodoPago: metodoPago ?? this.metodoPago,
      observaciones: observaciones ?? this.observaciones,
    );
  }

  bool get estaVencida => estado != 'pagada' && fechaVencimiento.isBefore(DateTime.now());

  static String nombreMes(int mes) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return meses[mes];
  }
}
