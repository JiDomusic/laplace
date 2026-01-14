class Alumno {
  final String? id;
  final String nombre;
  final String apellido;
  final String dni;
  final String sexo;
  final DateTime fechaNacimiento;
  final String nacionalidad;

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

  // Foto
  final String? fotoAlumno;

  // Inscripción
  final String nivelInscripcion;
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
    this.fotoAlumno,
    required this.nivelInscripcion,
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
      'foto_alumno': fotoAlumno,
      'nivel_inscripcion': nivelInscripcion,
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
      fotoAlumno: map['foto_alumno'],
      nivelInscripcion: map['nivel_inscripcion'],
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
    String? fotoAlumno,
    String? nivelInscripcion,
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
      fotoAlumno: fotoAlumno ?? this.fotoAlumno,
      nivelInscripcion: nivelInscripcion ?? this.nivelInscripcion,
      estado: estado ?? this.estado,
      observaciones: observaciones ?? this.observaciones,
      codigoInscripcion: codigoInscripcion ?? this.codigoInscripcion,
      fechaInscripcion: fechaInscripcion ?? this.fechaInscripcion,
    );
  }

  String get nombreCompleto => '$apellido, $nombre';

  String get direccionCompleta {
    String dir = '$calle $numero';
    if (piso != null && piso!.isNotEmpty) dir += ', Piso $piso';
    if (departamento != null && departamento!.isNotEmpty) dir += ', Dto. $departamento';
    return '$dir, $localidad ($codigoPostal)';
  }
}
