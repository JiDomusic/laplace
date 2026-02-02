/// Configuración de vencimientos escalonados
/// - Rango A (1-10): Precio normal
/// - Rango B (11-20): Precio con recargo
/// - Rango C (21-31): Cuota vencida, máximo recargo
class ConfigVencimientos {
  final int diaFinRangoA; // Default: 10
  final int diaFinRangoB; // Default: 20
  final double recargoRangoB; // Porcentaje o monto fijo
  final double recargoRangoC; // Porcentaje o monto fijo
  final bool esRecargoPorcentaje; // true = %, false = monto fijo

  ConfigVencimientos({
    this.diaFinRangoA = 10,
    this.diaFinRangoB = 20,
    this.recargoRangoB = 0,
    this.recargoRangoC = 0,
    this.esRecargoPorcentaje = true,
  });

  /// Calcula el monto final según el día del mes
  double calcularMonto(double montoBase, int diaDelMes) {
    if (diaDelMes <= diaFinRangoA) {
      // Rango A: Sin recargo
      return montoBase;
    } else if (diaDelMes <= diaFinRangoB) {
      // Rango B: Recargo intermedio
      if (esRecargoPorcentaje) {
        return montoBase * (1 + recargoRangoB / 100);
      } else {
        return montoBase + recargoRangoB;
      }
    } else {
      // Rango C: Máximo recargo (vencida)
      if (esRecargoPorcentaje) {
        return montoBase * (1 + recargoRangoC / 100);
      } else {
        return montoBase + recargoRangoC;
      }
    }
  }

  /// Obtiene el rango actual (A, B o C)
  String getRango(int diaDelMes) {
    if (diaDelMes <= diaFinRangoA) return 'A';
    if (diaDelMes <= diaFinRangoB) return 'B';
    return 'C';
  }

  /// Descripción del rango
  String getDescripcionRango(int diaDelMes) {
    final rango = getRango(diaDelMes);
    switch (rango) {
      case 'A':
        return 'En término (1-$diaFinRangoA)';
      case 'B':
        return 'Con recargo (${diaFinRangoA + 1}-$diaFinRangoB)';
      case 'C':
        return 'Vencida (${diaFinRangoB + 1}-31)';
      default:
        return '';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'dia_fin_rango_a': diaFinRangoA,
      'dia_fin_rango_b': diaFinRangoB,
      'recargo_rango_b': recargoRangoB,
      'recargo_rango_c': recargoRangoC,
      'es_recargo_porcentaje': esRecargoPorcentaje,
    };
  }

  factory ConfigVencimientos.fromMap(Map<String, dynamic> map) {
    return ConfigVencimientos(
      diaFinRangoA: map['dia_fin_rango_a'] ?? 10,
      diaFinRangoB: map['dia_fin_rango_b'] ?? 20,
      recargoRangoB: (map['recargo_rango_b'] as num?)?.toDouble() ?? 0,
      recargoRangoC: (map['recargo_rango_c'] as num?)?.toDouble() ?? 0,
      esRecargoPorcentaje: map['es_recargo_porcentaje'] ?? true,
    );
  }

  ConfigVencimientos copyWith({
    int? diaFinRangoA,
    int? diaFinRangoB,
    double? recargoRangoB,
    double? recargoRangoC,
    bool? esRecargoPorcentaje,
  }) {
    return ConfigVencimientos(
      diaFinRangoA: diaFinRangoA ?? this.diaFinRangoA,
      diaFinRangoB: diaFinRangoB ?? this.diaFinRangoB,
      recargoRangoB: recargoRangoB ?? this.recargoRangoB,
      recargoRangoC: recargoRangoC ?? this.recargoRangoC,
      esRecargoPorcentaje: esRecargoPorcentaje ?? this.esRecargoPorcentaje,
    );
  }
}
