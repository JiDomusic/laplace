import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alumno.dart';
import '../models/legajo.dart';
import '../models/cuota.dart';
import '../models/picked_file.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  SupabaseService._init();

  SupabaseClient get client => Supabase.instance.client;

  // ==================== INICIALIZACIÓN ====================

  static Future<void> initialize() async {
    if (SupabaseConfig.supabaseUrl.isEmpty || SupabaseConfig.supabaseAnonKey.isEmpty) {
      throw Exception('Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Pasa --dart-define al compilar.');
    }
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // ==================== ALUMNOS ====================

  Future<String> insertAlumno(Alumno alumno) async {
    final map = alumno.toMap();
    map.remove('id');
    map.remove('codigo_inscripcion');
    map.remove('fecha_inscripcion');
    map['trabaja'] = alumno.trabaja;

    final response = await client
        .from('alumnos')
        .insert(map)
        .select('id, codigo_inscripcion')
        .single();

    return response['id'] as String;
  }

  Future<List<Alumno>> getAllAlumnos() async {
    final response = await client
        .from('alumnos')
        .select()
        .order('fecha_inscripcion', ascending: false);

    return (response as List).map((map) => _alumnoFromSupabase(map)).toList();
  }

  Future<List<Alumno>> getAlumnosByEstado(String estado) async {
    final response = await client
        .from('alumnos')
        .select()
        .eq('estado', estado)
        .order('fecha_inscripcion', ascending: false);

    return (response as List).map((map) => _alumnoFromSupabase(map)).toList();
  }

  Future<Alumno?> getAlumnoById(String id) async {
    final response = await client
        .from('alumnos')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return _alumnoFromSupabase(response);
  }

  Future<Alumno?> getAlumnoByCodigo(String codigo) async {
    final response = await client
        .from('alumnos')
        .select()
        .eq('codigo_inscripcion', codigo)
        .maybeSingle();

    if (response == null) return null;
    return _alumnoFromSupabase(response);
  }

  Future<Alumno?> getAlumnoByDni(String dni) async {
    final response = await client.from('alumnos').select().eq('dni', dni).maybeSingle();
    if (response == null) return null;
    return _alumnoFromSupabase(response);
  }

  Future<void> updateEstadoAlumno(String id, String estado, {String? observaciones}) async {
    final map = {'estado': estado};
    if (observaciones != null) map['observaciones'] = observaciones;

    await client.from('alumnos').update(map).eq('id', id);
  }

  Future<void> updateDivisionAlumno(String id, String? division) async {
    await client.from('alumnos').update({'division': division}).eq('id', id);
  }

  Future<void> deleteAlumno(String id) async {
    await client.from('alumnos').delete().eq('id', id);
  }

  Future<Map<String, int>> getEstadisticas() async {
    final alumnos = await client.from('alumnos').select('estado');
    final cuotas = await client
        .from('cuotas')
        .select('estado')
        .or('estado.eq.pendiente,estado.eq.vencida');

    int total = (alumnos as List).length;
    int pendientes = alumnos.where((a) => a['estado'] == 'pendiente').length;
    int aprobados = alumnos.where((a) => a['estado'] == 'aprobado').length;
    int cuotasPendientes = (cuotas as List).length;

    return {
      'total': total,
      'pendientes': pendientes,
      'aprobados': aprobados,
      'cuotas_pendientes': cuotasPendientes,
    };
  }

  Future<List<Map<String, dynamic>>> getInscripcionesRecientes(int cantidad) async {
    final response = await client
        .from('alumnos')
        .select('id, nombre, apellido, estado, nivel_inscripcion, fecha_inscripcion')
        .order('fecha_inscripcion', ascending: false)
        .limit(cantidad);

    return List<Map<String, dynamic>>.from(response).map((item) {
      return {
        ...item,
        'id': item['id']?.toString(),
      };
    }).toList();
  }

  Alumno _alumnoFromSupabase(Map<String, dynamic> map) {
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
      trabaja: map['trabaja'] is bool
          ? map['trabaja'] as bool
          : (map['trabaja'] == 1),
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

  // ==================== LEGAJO ====================

  Future<void> insertLegajo(String alumnoId, Legajo legajo) async {
    final map = {
      'alumno_id': alumnoId,
      'dni_frente': legajo.dniFrente,
      'dni_dorso': legajo.dniDorso,
      'partida_nacimiento': legajo.partidaNacimiento,
      'nacido_fuera_santa_fe': legajo.nacidoFueraSantaFe,
      'estado_titulo': legajo.estadoTitulo,
      'titulo_archivo': legajo.tituloArchivo,
      'tramite_constancia': legajo.tramiteConstancia,
      'materias_adeudadas': legajo.materiasAdeudadas,
      'materias_constancia': legajo.materiasConstancia,
      'tipo_legalizacion': legajo.tipoLegalizacion,
    };

    await client.from('legajo_documentos').insert(map);
  }

  Future<Legajo?> getLegajoByAlumnoId(String alumnoId) async {
    final response = await client
        .from('legajo_documentos')
        .select()
        .eq('alumno_id', alumnoId)
        .maybeSingle();

    if (response == null) return null;
    return Legajo.fromMap({
      ...response,
      'nacido_fuera_santa_fe': response['nacido_fuera_santa_fe'] is bool
          ? (response['nacido_fuera_santa_fe'] ? 1 : 0)
          : response['nacido_fuera_santa_fe'],
    });
  }

  // ==================== CUOTAS ====================

  Future<void> generarCuotasAnuales(String alumnoId, double monto, int anio) async {
    final meses = {
      3: 'Marzo',
      4: 'Abril',
      5: 'Mayo',
      6: 'Junio',
      7: 'Julio',
      8: 'Agosto',
      9: 'Septiembre',
      10: 'Octubre',
      11: 'Noviembre',
      12: 'Diciembre',
    };

    final cuotas = meses.entries.map((entry) => {
      'alumno_id': alumnoId,
      'concepto': 'Cuota ${entry.value} $anio',
      'monto': monto,
      'mes': entry.key,
      'anio': anio,
      'fecha_vencimiento': DateTime(anio, entry.key, 10).toIso8601String().split('T')[0],
      'estado': 'pendiente',
    }).toList();

    await client.from('cuotas').insert(cuotas);
  }

  Future<List<Cuota>> getAllCuotas() async {
    final response = await client
        .from('cuotas')
        .select()
        .order('fecha_vencimiento', ascending: true);

    return (response as List).map((map) => _cuotaFromSupabase(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCuotasPendientesConAlumno() async {
    final response = await client
        .from('vista_cuotas_pendientes')
        .select()
        .order('fecha_vencimiento', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Cuota>> getCuotasByAlumno(String alumnoId) async {
    final response = await client
        .from('cuotas')
        .select()
        .eq('alumno_id', alumnoId)
        .order('fecha_vencimiento', ascending: true);

    return (response as List).map((map) => _cuotaFromSupabase(map)).toList();
  }

  Future<void> registrarPago(String cuotaId, String metodoPago, {String? observaciones}) async {
    await client.from('cuotas').update({
      'estado': 'pagada',
      'fecha_pago': DateTime.now().toIso8601String().split('T')[0],
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
    }).eq('id', cuotaId);
  }

  Future<void> registrarPagoTotal(String cuotaId, String metodoPago, {String? observaciones, String? numRecibo, String? detallePago}) async {
    final cuota = await client.from('cuotas').select().eq('id', cuotaId).maybeSingle();
    if (cuota == null) return;

    await client.from('cuotas').update({
      'monto_pagado': cuota['monto'],
      'estado': 'pagada',
      'fecha_pago': DateTime.now().toIso8601String(),
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
      'num_recibo': numRecibo,
      'detalle_pago': detallePago,
    }).eq('id', cuotaId);
  }

  Future<void> registrarPagoParcial(String cuotaId, double monto, String metodoPago, {String? observaciones, String? numRecibo, String? detallePago}) async {
    final cuota = await client.from('cuotas').select().eq('id', cuotaId).maybeSingle();
    if (cuota == null) return;

    final montoPagadoActual = (cuota['monto_pagado'] as num?)?.toDouble() ?? 0;
    final montoTotal = (cuota['monto'] as num).toDouble();
    final nuevoMontoPagado = montoPagadoActual + monto;
    final estaPagada = nuevoMontoPagado >= montoTotal;

    await client.from('cuotas').update({
      'monto_pagado': nuevoMontoPagado,
      'estado': estaPagada ? 'pagada' : 'parcial',
      'fecha_pago': estaPagada ? DateTime.now().toIso8601String() : null,
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
      'num_recibo': numRecibo,
      'detalle_pago': detallePago,
    }).eq('id', cuotaId);
  }

  Future<void> updateMontoCuota(String cuotaId, double nuevoMonto) async {
    await client.from('cuotas').update({'monto': nuevoMonto}).eq('id', cuotaId);
  }

  Future<void> updateFechaVencimiento(String cuotaId, DateTime nuevaFecha) async {
    await client
        .from('cuotas')
        .update({'fecha_vencimiento': nuevaFecha.toIso8601String().split('T')[0]})
        .eq('id', cuotaId);
  }

  Future<void> updateMontoCuotasTrimestre({
    required int anio,
    required int trimestre,
    required double nuevoMonto,
    bool soloPendientes = true,
  }) async {
    final Map<int, List<int>> trimestres = {
      1: [3, 4, 5],
      2: [6, 7, 8],
      3: [9, 10, 11],
    };
    final meses = trimestres[trimestre] ?? [];
    if (meses.isEmpty) return;

    final filter = client
        .from('cuotas')
        .update({'monto': nuevoMonto})
        .eq('anio', anio)
        .inFilter('mes', meses);

    if (soloPendientes) {
      filter.neq('estado', 'pagada');
    }

    await filter;
  }

  Cuota _cuotaFromSupabase(Map<String, dynamic> map) {
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
      numRecibo: map['num_recibo'],
      detallePago: map['detalle_pago'],
    );
  }

  // ==================== STORAGE ====================

  /// Sube un archivo usando bytes (funciona en web y movil)
  Future<String> uploadBytes(String bucket, String fileName, Uint8List bytes) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await client.storage.from(bucket).uploadBinary(path, bytes);

    return path;
  }

  Future<String> uploadSelectedFile(String bucket, String fileName, SelectedFile file) async {
    return uploadBytes(bucket, fileName, file.bytes);
  }

  Future<String> uploadFotoAlumno(String dni, SelectedFile file) async {
    return uploadSelectedFile('fotos-alumnos', '${dni}_foto.${file.extension}', file);
  }

  Future<String> uploadDNI(String dni, SelectedFile file, String lado) async {
    return uploadSelectedFile('documentos-dni', '${dni}_$lado.${file.extension}', file);
  }

  Future<String> uploadTitulo(String dni, SelectedFile file) async {
    return uploadSelectedFile('documentos-titulos', '${dni}_titulo.${file.extension}', file);
  }

  Future<String> uploadDocumento(String bucket, String dni, String tipo, SelectedFile file) async {
    return uploadSelectedFile(bucket, '${dni}_$tipo.${file.extension}', file);
  }

  Future<String?> getSignedUrl(String bucket, String? storedPathOrUrl, {int expiresInSeconds = 3600}) async {
    if (storedPathOrUrl == null || storedPathOrUrl.isEmpty) return null;
    try {
      final path = _extractStoragePath(bucket, storedPathOrUrl);
      final dynamic result = await client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
      if (result is String) return result;
      if (result is Map<String, dynamic>) {
        final signedUrl = result['signedUrl'] ?? result['signed_url'];
        return signedUrl is String ? signedUrl : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getSignedFotoAlumno(String? storedPathOrUrl) {
    return getSignedUrl('fotos-alumnos', storedPathOrUrl);
  }

  String _extractStoragePath(String bucket, String stored) {
    // Maneja URL publica o firmada y devuelve solo el path interno del bucket
    final publicPrefix = '/object/public/$bucket/';
    final signedPrefix = '/object/sign/$bucket/';
    if (stored.contains(publicPrefix)) {
      return stored.split(publicPrefix).last;
    }
    if (stored.contains(signedPrefix)) {
      return stored.split(signedPrefix).last;
    }
    // Si ya es un path interno, se devuelve tal cual
    return stored;
  }

  // ==================== GALERIA DE EVENTOS ====================

  Future<String> uploadFotoGaleria(String titulo, SelectedFile file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tituloSanitizado = _sanitizarNombreArchivo(titulo);
    final fileName = '${timestamp}_$tituloSanitizado.${file.extension}';
    return uploadSelectedFile('galeria', fileName, file);
  }

  String _sanitizarNombreArchivo(String nombre) {
    // Reemplazar caracteres especiales
    final reemplazos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U',
      'ñ': 'n', 'Ñ': 'N', 'ü': 'u', 'Ü': 'U',
      ' ': '_',
    };
    var resultado = nombre;
    reemplazos.forEach((key, value) {
      resultado = resultado.replaceAll(key, value);
    });
    // Remover cualquier otro carácter no alfanumérico excepto _ y -
    resultado = resultado.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    return resultado;
  }

  Future<List<Map<String, dynamic>>> getGaleria() async {
    final response = await client
        .from('galeria')
        .select()
        .eq('activo', true)
        .order('fecha_creacion', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> insertFotoGaleria({
    required String titulo,
    required String url,
    String? descripcion,
  }) async {
    await client.from('galeria').insert({
      'titulo': titulo,
      'url_imagen': url,
      'descripcion': descripcion,
      'activo': true,
    });
  }

  Future<void> deleteFotoGaleria(String id) async {
    await client.from('galeria').delete().eq('id', id);
  }

  // ==================== CONFIGURACIÓN ====================

  Future<String?> getConfig(String clave) async {
    final response = await client
        .from('configuracion')
        .select('valor')
        .eq('clave', clave)
        .maybeSingle();

    return response?['valor'] as String?;
  }

  Future<void> setConfig(String clave, String valor) async {
    await client.from('configuracion').upsert({
      'clave': clave,
      'valor': valor,
    });
  }

  // ==================== AUTENTICACIÓN ADMIN ====================

  Future<Map<String, dynamic>?> loginAdmin(String email, String password) async {
    // Intentar login via Supabase Auth si el usuario existe allí
    try {
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      if (authResponse.session != null) {
        // Buscar datos extra en la tabla administradores
        final adminRow = await getAdminByEmail(email);
        if (adminRow != null) {
          await client
              .from('administradores')
              .update({'ultimo_acceso': DateTime.now().toIso8601String()})
              .eq('id', adminRow['id']);
          return adminRow;
        }

        // Si no hay fila en administradores, devolver datos básicos del auth user
        return {
          'id': authResponse.session!.user.id,
          'email': email,
          'nombre': authResponse.session!.user.email ?? email,
          'rol': 'admin',
          'activo': true,
        };
      }
    } catch (_) {
      // Ignorar y probar login por tabla
    }

    // Fallback: login contra tabla administradores (password en texto plano)
    final response = await client
        .from('administradores')
        .select()
        .eq('email', email)
        .eq('password', password)
        .or('activo.is.null,activo.eq.true,activo.eq.1')
        .maybeSingle();

    if (response == null) return null;

    // Actualizar último acceso
    await client
        .from('administradores')
        .update({'ultimo_acceso': DateTime.now().toIso8601String()})
        .eq('id', response['id']);

    return response;
  }

  Future<Map<String, dynamic>?> getAdminByEmail(String email) async {
    final response = await client
        .from('administradores')
        .select()
        .eq('email', email)
        .maybeSingle();
    return response;
  }
}
