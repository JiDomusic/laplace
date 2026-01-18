class Alumno {
  final String? id;
  final String nombre;
  final String apellido;
  final String dni;
  final String sexo;
  final DateTime fechaNacimiento;
  final String nacionalidad;
  final String? localidadNacimiento;
  final String? provinciaNacimiento;

  // Domicilio
  final String calle;
  final String numero;
  final String? piso;
  final String? departamento;
  final String localidad;
  final String codigoPostal;

  // Contacto
  final String email;
  final String? telefono;
  final String celular;

  // Laboral
  final bool trabaja;
  final String? certificadoTrabajo;

  // Contacto de Urgencia
  final String? contactoUrgenciaNombre;
  final String? contactoUrgenciaTelefono;
  final String? contactoUrgenciaVinculo;
  final String? contactoUrgenciaOtro; // Cuando vínculo es "Otro"

  // Título Secundario
  final String? observacionesTitulo; // Para fecha certificado y materias adeudadas

  // Inscripción
  final String? cicloLectivo;

  // Foto
  final String? fotoAlumno;

  // Inscripción
  final String nivelInscripcion;
  final String? division; // A, B, C - asignado por admin
  final String estado;
  final String? observaciones;
  final String? codigoInscripcion;
  final DateTime? fechaInscripcion;

  Alumno({
    this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.sexo,
    required this.fechaNacimiento,
    required this.nacionalidad,
    this.localidadNacimiento,
    this.provinciaNacimiento,
    required this.calle,
    required this.numero,
    this.piso,
    this.departamento,
    required this.localidad,
    required this.codigoPostal,
    required this.email,
    this.telefono,
    required this.celular,
    this.trabaja = false,
    this.certificadoTrabajo,
    this.contactoUrgenciaNombre,
    this.contactoUrgenciaTelefono,
    this.contactoUrgenciaVinculo,
    this.contactoUrgenciaOtro,
    this.observacionesTitulo,
    this.cicloLectivo,
    this.fotoAlumno,
    required this.nivelInscripcion,
    this.division,
    this.estado = 'pendiente',
    this.observaciones,
    this.codigoInscripcion,
    this.fechaInscripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'sexo': sexo,
      'fecha_nacimiento': fechaNacimiento.toIso8601String(),
      'nacionalidad': nacionalidad,
      'localidad_nacimiento': localidadNacimiento,
      'provincia_nacimiento': provinciaNacimiento,
      'calle': calle,
      'numero': numero,
      'piso': piso,
      'departamento': departamento,
      'localidad': localidad,
      'codigo_postal': codigoPostal,
      'email': email,
      'telefono': telefono,
      'celular': celular,
      'trabaja': trabaja,
      'certificado_trabajo': certificadoTrabajo,
      'contacto_urgencia_nombre': contactoUrgenciaNombre,
      'contacto_urgencia_telefono': contactoUrgenciaTelefono,
      'contacto_urgencia_vinculo': contactoUrgenciaVinculo,
      'contacto_urgencia_otro': contactoUrgenciaOtro,
      'observaciones_titulo': observacionesTitulo,
      'ciclo_lectivo': cicloLectivo,
      'foto_alumno': fotoAlumno,
      'nivel_inscripcion': nivelInscripcion,
      'division': division,
      'estado': estado,
      'observaciones': observaciones,
      'codigo_inscripcion': codigoInscripcion,
      'fecha_inscripcion': fechaInscripcion?.toIso8601String(),
    };
  }

  factory Alumno.fromMap(Map<String, dynamic> map) {
    final trabajaRaw = map['trabaja'];
    return Alumno(
      id: map['id']?.toString(),
      nombre: map['nombre'],
      apellido: map['apellido'],
      dni: map['dni'],
      sexo: map['sexo'],
      fechaNacimiento: DateTime.parse(map['fecha_nacimiento']),
      nacionalidad: map['nacionalidad'],
      localidadNacimiento: map['localidad_nacimiento'],
      provinciaNacimiento: map['provincia_nacimiento'],
      calle: map['calle'],
      numero: map['numero'],
      piso: map['piso'],
      departamento: map['departamento'],
      localidad: map['localidad'],
      codigoPostal: map['codigo_postal'],
      email: map['email'],
      telefono: map['telefono'],
      celular: map['celular'],
      trabaja: trabajaRaw is bool ? trabajaRaw : trabajaRaw == 1,
      certificadoTrabajo: map['certificado_trabajo'],
      contactoUrgenciaNombre: map['contacto_urgencia_nombre'],
      contactoUrgenciaTelefono: map['contacto_urgencia_telefono'],
      contactoUrgenciaVinculo: map['contacto_urgencia_vinculo'],
      contactoUrgenciaOtro: map['contacto_urgencia_otro'],
      observacionesTitulo: map['observaciones_titulo'],
      cicloLectivo: map['ciclo_lectivo'],
      fotoAlumno: map['foto_alumno'],
      nivelInscripcion: map['nivel_inscripcion'],
      division: map['division'],
      estado: map['estado'] ?? 'pendiente',
      observaciones: map['observaciones'],
      codigoInscripcion: map['codigo_inscripcion'],
      fechaInscripcion: map['fecha_inscripcion'] != null
          ? DateTime.parse(map['fecha_inscripcion'])
          : null,
    );
  }

  Alumno copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? dni,
    String? sexo,
    DateTime? fechaNacimiento,
    String? nacionalidad,
    String? localidadNacimiento,
    String? provinciaNacimiento,
    String? calle,
    String? numero,
    String? piso,
    String? departamento,
    String? localidad,
    String? codigoPostal,
    String? email,
    String? telefono,
    String? celular,
    bool? trabaja,
    String? certificadoTrabajo,
    String? contactoUrgenciaNombre,
    String? contactoUrgenciaTelefono,
    String? contactoUrgenciaVinculo,
    String? contactoUrgenciaOtro,
    String? observacionesTitulo,
    String? cicloLectivo,
    String? fotoAlumno,
    String? nivelInscripcion,
    String? division,
    String? estado,
    String? observaciones,
    String? codigoInscripcion,
    DateTime? fechaInscripcion,
  }) {
    return Alumno(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      dni: dni ?? this.dni,
      sexo: sexo ?? this.sexo,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      nacionalidad: nacionalidad ?? this.nacionalidad,
      localidadNacimiento: localidadNacimiento ?? this.localidadNacimiento,
      provinciaNacimiento: provinciaNacimiento ?? this.provinciaNacimiento,
      calle: calle ?? this.calle,
      numero: numero ?? this.numero,
      piso: piso ?? this.piso,
      departamento: departamento ?? this.departamento,
      localidad: localidad ?? this.localidad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      celular: celular ?? this.celular,
      trabaja: trabaja ?? this.trabaja,
      certificadoTrabajo: certificadoTrabajo ?? this.certificadoTrabajo,
      contactoUrgenciaNombre: contactoUrgenciaNombre ?? this.contactoUrgenciaNombre,
      contactoUrgenciaTelefono: contactoUrgenciaTelefono ?? this.contactoUrgenciaTelefono,
      contactoUrgenciaVinculo: contactoUrgenciaVinculo ?? this.contactoUrgenciaVinculo,
      contactoUrgenciaOtro: contactoUrgenciaOtro ?? this.contactoUrgenciaOtro,
      observacionesTitulo: observacionesTitulo ?? this.observacionesTitulo,
      cicloLectivo: cicloLectivo ?? this.cicloLectivo,
      fotoAlumno: fotoAlumno ?? this.fotoAlumno,
      nivelInscripcion: nivelInscripcion ?? this.nivelInscripcion,
      division: division ?? this.division,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      codigoInscripcion: codigoInscripcion ?? this.codigoInscripcion,
      fechaInscripcion: fechaInscripcion ?? this.fechaInscripcion,
    );
  }

  String get nombreCompleto => '$apellido, $nombre';

  String get nivelCompleto {
    if (division != null && division!.isNotEmpty) {
      return '$nivelInscripcion $division';
    }
    return nivelInscripcion;
  }

  String get direccionCompleta {
    String dir = '$calle $numero';
    if (piso != null && piso!.isNotEmpty) dir += ', Piso $piso';
    if (departamento != null && departamento!.isNotEmpty) dir += ', Dto. $departamento';
    return '$dir, $localidad ($codigoPostal)';
  }
}
