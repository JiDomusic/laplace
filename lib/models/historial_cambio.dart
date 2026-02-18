class HistorialCambio {
  final String? id;
  final String tabla;
  final String registroId;
  final String accion;
  final Map<String, dynamic>? datosAnteriores;
  final Map<String, dynamic>? datosNuevos;
  final String? descripcion;
  final String? usuario;
  final bool revertido;
  final DateTime fecha;

  HistorialCambio({
    this.id,
    required this.tabla,
    required this.registroId,
    required this.accion,
    this.datosAnteriores,
    this.datosNuevos,
    this.descripcion,
    this.usuario,
    this.revertido = false,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();

  factory HistorialCambio.fromMap(Map<String, dynamic> map) {
    return HistorialCambio(
      id: map['id']?.toString(),
      tabla: map['tabla'],
      registroId: map['registro_id'],
      accion: map['accion'],
      datosAnteriores: map['datos_anteriores'] != null
          ? Map<String, dynamic>.from(map['datos_anteriores'])
          : null,
      datosNuevos: map['datos_nuevos'] != null
          ? Map<String, dynamic>.from(map['datos_nuevos'])
          : null,
      descripcion: map['descripcion'],
      usuario: map['usuario'],
      revertido: map['revertido'] ?? false,
      fecha: DateTime.parse(map['fecha']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tabla': tabla,
      'registro_id': registroId,
      'accion': accion,
      'datos_anteriores': datosAnteriores,
      'datos_nuevos': datosNuevos,
      'descripcion': descripcion,
      'usuario': usuario,
      'revertido': revertido,
    };
  }

  String get accionTexto {
    const acciones = {
      'pago_total': 'Pago Total',
      'pago_parcial': 'Pago Parcial',
      'editar_alumno': 'Edicion de Alumno',
      'editar_monto': 'Cambio de Monto',
      'editar_monto_mes': 'Cambio de Montos del Mes',
      'cambiar_division': 'Cambio de Division',
      'promocionar': 'Promocion de Alumnos',
      'eliminar_alumno': 'Eliminacion de Alumno',
    };
    return acciones[accion] ?? accion;
  }
}
