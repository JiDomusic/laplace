/// Configuración de montos de cuotas por nivel y mes
/// El admin define 3 valores enteros para cada vencimiento
/// Sin cálculos de porcentajes - todo valores fijos
class ConfigCuotasPeriodo {
  final String id;
  final String nivel; // 'Primer Año', 'Segundo Año', 'Tercer Año'
  final int mes; // 1-12
  final int anio;
  final int montoAlDia; // Valor 1° Vencimiento (Rango A)
  final int monto1erVto; // Valor 2° Vencimiento (Rango B)
  final int monto2doVto; // Valor 3° Vencimiento (Rango C)
  final int diaFinRangoA; // Último día del rango A (default 10)
  final int diaFinRangoB; // Último día del rango B (default 20)

  ConfigCuotasPeriodo({
    this.id = '',
    required this.nivel,
    required this.mes,
    required this.anio,
    required this.montoAlDia,
    required this.monto1erVto,
    required this.monto2doVto,
    this.diaFinRangoA = 10,
    this.diaFinRangoB = 20,
  });

  /// Obtiene el monto correspondiente según el día del mes
  int obtenerMonto(int diaDelMes) {
    if (diaDelMes <= diaFinRangoA) {
      return montoAlDia;
    } else if (diaDelMes <= diaFinRangoB) {
      return monto1erVto;
    } else {
      return monto2doVto;
    }
  }

  /// Obtiene el rango actual (A, B o C)
  String getRango(int diaDelMes) {
    if (diaDelMes <= diaFinRangoA) return 'A';
    if (diaDelMes <= diaFinRangoB) return 'B';
    return 'C';
  }

  /// Descripción del rango para mostrar en UI
  String getDescripcionRango(int diaDelMes) {
    final rango = getRango(diaDelMes);
    switch (rango) {
      case 'A':
        return '1° Vencimiento (1-$diaFinRangoA)';
      case 'B':
        return '2° Vencimiento (${diaFinRangoA + 1}-$diaFinRangoB)';
      case 'C':
        return '3° Vencimiento (${diaFinRangoB + 1}-31)';
      default:
        return '';
    }
  }

  /// Nombre del mes
  static String nombreMes(int mes) {
    const nombres = {
      1: 'Enero', 2: 'Febrero', 3: 'Marzo', 4: 'Abril',
      5: 'Mayo', 6: 'Junio', 7: 'Julio', 8: 'Agosto',
      9: 'Septiembre', 10: 'Octubre', 11: 'Noviembre', 12: 'Diciembre',
    };
    return nombres[mes] ?? '';
  }

  /// Cálculo de bimestre (solo para compatibilidad con DB)
  static int bimestreDesdeMes(int mes) {
    return ((mes - 1) ~/ 2) + 1; // 1-2->1, 3-4->2, ..., 11-12->6
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nivel': nivel,
      'mes': mes,
      'bimestre': bimestreDesdeMes(mes),
      'anio': anio,
      'monto_al_dia': montoAlDia,
      'monto_1er_vto': monto1erVto,
      'monto_2do_vto': monto2doVto,
      'dia_fin_rango_a': diaFinRangoA,
      'dia_fin_rango_b': diaFinRangoB,
    };
  }

  factory ConfigCuotasPeriodo.fromMap(Map<String, dynamic> map) {
    final mes = map['mes'] as int? ??
        (((map['bimestre'] as int? ?? 1) - 1) * 2 + 1);

    return ConfigCuotasPeriodo(
      id: map['id']?.toString() ?? '',
      nivel: map['nivel'] ?? '',
      mes: mes,
      anio: map['anio'] ?? DateTime.now().year,
      montoAlDia: (map['monto_al_dia'] as num?)?.toInt() ?? 0,
      monto1erVto: (map['monto_1er_vto'] as num?)?.toInt() ?? 0,
      monto2doVto: (map['monto_2do_vto'] as num?)?.toInt() ?? 0,
      diaFinRangoA: (map['dia_fin_rango_a'] as num?)?.toInt() ?? 10,
      diaFinRangoB: (map['dia_fin_rango_b'] as num?)?.toInt() ?? 20,
    );
  }

  ConfigCuotasPeriodo copyWith({
    String? id,
    String? nivel,
    int? mes,
    int? anio,
    int? montoAlDia,
    int? monto1erVto,
    int? monto2doVto,
    int? diaFinRangoA,
    int? diaFinRangoB,
  }) {
    return ConfigCuotasPeriodo(
      id: id ?? this.id,
      nivel: nivel ?? this.nivel,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
      montoAlDia: montoAlDia ?? this.montoAlDia,
      monto1erVto: monto1erVto ?? this.monto1erVto,
      monto2doVto: monto2doVto ?? this.monto2doVto,
      diaFinRangoA: diaFinRangoA ?? this.diaFinRangoA,
      diaFinRangoB: diaFinRangoB ?? this.diaFinRangoB,
    );
  }
}
