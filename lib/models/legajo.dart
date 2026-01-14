class Legajo {
  final String? id;
  final String alumnoId;

  // DNI
  final String? dniFrente;
  final String? dniDorso;

  // Partida
  final String? partidaNacimiento;
  final bool nacidoFueraSantaFe;

  // Título
  final String estadoTitulo; // terminado, en_tramite, debe_materias
  final String? tituloArchivo;
  final String? tramiteConstancia;
  final String? materiasAdeudadas;
  final String? materiasConstancia;
  final String? tipoLegalizacion; // tribunales, institucion, digital

  Legajo({
    this.id,
    required this.alumnoId,
    this.dniFrente,
    this.dniDorso,
    this.partidaNacimiento,
    this.nacidoFueraSantaFe = false,
    required this.estadoTitulo,
    this.tituloArchivo,
    this.tramiteConstancia,
    this.materiasAdeudadas,
    this.materiasConstancia,
    this.tipoLegalizacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'alumno_id': alumnoId,
      'dni_frente': dniFrente,
      'dni_dorso': dniDorso,
      'partida_nacimiento': partidaNacimiento,
      'nacido_fuera_santa_fe': nacidoFueraSantaFe,
      'estado_titulo': estadoTitulo,
      'titulo_archivo': tituloArchivo,
      'tramite_constancia': tramiteConstancia,
      'materias_adeudadas': materiasAdeudadas,
      'materias_constancia': materiasConstancia,
      'tipo_legalizacion': tipoLegalizacion,
    };
  }

  factory Legajo.fromMap(Map<String, dynamic> map) {
    final nacidoRaw = map['nacido_fuera_santa_fe'];
    return Legajo(
      id: map['id']?.toString(),
      alumnoId: map['alumno_id']?.toString() ?? '',
      dniFrente: map['dni_frente'],
      dniDorso: map['dni_dorso'],
      partidaNacimiento: map['partida_nacimiento'],
      nacidoFueraSantaFe: nacidoRaw is bool ? nacidoRaw : nacidoRaw == 1,
      estadoTitulo: map['estado_titulo'],
      tituloArchivo: map['titulo_archivo'],
      tramiteConstancia: map['tramite_constancia'],
      materiasAdeudadas: map['materias_adeudadas'],
      materiasConstancia: map['materias_constancia'],
      tipoLegalizacion: map['tipo_legalizacion'],
    );
  }

  String get estadoTituloTexto {
    switch (estadoTitulo) {
      case 'terminado':
        return 'Título Secundario Completo';
      case 'en_tramite':
        return 'Título en Trámite';
      case 'debe_materias':
        return 'Adeuda Materias';
      default:
        return estadoTitulo;
    }
  }
}
