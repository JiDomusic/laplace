/// Configuración de montos de cuotas por nivel y período
/// El admin define 3 valores enteros para cada vencimiento
/// Sin cálculos de porcentajes - todo valores fijos
class ConfigCuotasPeriodo {
  final String id;
  final String nivel; // 'Primer Año', 'Segundo Año', 'Tercer Año'
  final int bimestre; // 1-6 (Ene-Feb, Mar-Abr, May-Jun, Jul-Ago, Sep-Oct, Nov-Dic)
  final int anio;
  final int montoAlDia; // Valor si paga en término (Rango A)
  final int monto1erVto; // Valor 1er vencimiento (Rango B)
  final int monto2doVto; // Valor 2do vencimiento (Rango C)
  final int diaFinRangoA; // Último día del rango A (default 10)
  final int diaFinRangoB; // Último día del rango B (default 20)

  ConfigCuotasPeriodo({
    this.id = '',
    required this.nivel,
    required this.bimestre,
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
        return 'En término (1-$diaFinRangoA)';
      case 'B':
        return '1er vencimiento (${diaFinRangoA + 1}-$diaFinRangoB)';
      case 'C':
        return '2do vencimiento (${diaFinRangoB + 1}-31)';
      default:
        return '';
    }
  }

  /// Nombre del bimestre
  static String nombreBimestre(int bimestre) {
    const nombres = {
      1: 'Enero-Febrero',
      2: 'Marzo-Abril',
      3: 'Mayo-Junio',
      4: 'Julio-Agosto',
      5: 'Septiembre-Octubre',
      6: 'Noviembre-Diciembre',
    };
    return nombres[bimestre] ?? '';
  }

  /// Mes de inicio del bimestre
  static int mesInicioBimestre(int bimestre) {
    const meses = {1: 1, 2: 3, 3: 5, 4: 7, 5: 9, 6: 11};
    return meses[bimestre] ?? 1;
  }

  /// Obtiene el bimestre a partir del mes
  static int bimestreDelMes(int mes) {
    if (mes <= 2) return 1;
    if (mes <= 4) return 2;
    if (mes <= 6) return 3;
    if (mes <= 8) return 4;
    if (mes <= 10) return 5;
    return 6;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nivel': nivel,
      'bimestre': bimestre,
      'anio': anio,
      'monto_al_dia': montoAlDia,
      'monto_1er_vto': monto1erVto,
      'monto_2do_vto': monto2doVto,
      'dia_fin_rango_a': diaFinRangoA,
      'dia_fin_rango_b': diaFinRangoB,
    };
  }

  factory ConfigCuotasPeriodo.fromMap(Map<String, dynamic> map) {
    return ConfigCuotasPeriodo(
      id: map['id']?.toString() ?? '',
      nivel: map['nivel'] ?? '',
      bimestre: map['bimestre'] ?? 1,
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
    int? bimestre,
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
      bimestre: bimestre ?? this.bimestre,
      anio: anio ?? this.anio,
      montoAlDia: montoAlDia ?? this.montoAlDia,
      monto1erVto: monto1erVto ?? this.monto1erVto,
      monto2doVto: monto2doVto ?? this.monto2doVto,
      diaFinRangoA: diaFinRangoA ?? this.diaFinRangoA,
      diaFinRangoB: diaFinRangoB ?? this.diaFinRangoB,
    );
  }
}
