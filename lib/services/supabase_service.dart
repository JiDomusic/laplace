import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alumno.dart';
import '../models/legajo.dart';
import '../models/cuota.dart';
import '../models/config_vencimientos.dart';
import '../models/config_cuotas_periodo.dart';
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
    final alumnos = await client.from('alumnos').select('id');
    final cuotas = await client
        .from('cuotas')
        .select('estado')
        .or('estado.eq.pendiente,estado.eq.vencida');

    int total = (alumnos as List).length;
    int cuotasPendientes = (cuotas as List).length;

    return {
      'total': total,
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
      estado: map['estado'] ?? 'aprobado',
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

  /// Genera cuotas anuales con los 3 montos de vencimiento
  /// Esta función no se usa actualmente - usar generarCuotasBimestrales
  Future<void> generarCuotasAnuales(
    String alumnoId,
    int montoAlDia,
    int anio, {
    int? monto1erVto,
    int? monto2doVto,
    int? montoInscripcion,
    bool generarInscripcion = true,
  }) async {
    final alumno = await getAlumnoById(alumnoId);
    final bool esPrimero = alumno?.nivelInscripcion == 'Primer Año';

    final bimestres = esPrimero
        ? [
            {'mes': 3, 'nombre': 'Marzo-Abril'},
            {'mes': 5, 'nombre': 'Mayo-Junio'},
            {'mes': 7, 'nombre': 'Julio-Agosto'},
            {'mes': 9, 'nombre': 'Septiembre-Octubre'},
            {'mes': 11, 'nombre': 'Noviembre-Diciembre'},
          ]
        : [
            {'mes': 1, 'nombre': 'Enero-Febrero'},
            {'mes': 3, 'nombre': 'Marzo-Abril'},
            {'mes': 5, 'nombre': 'Mayo-Junio'},
            {'mes': 7, 'nombre': 'Julio-Agosto'},
            {'mes': 9, 'nombre': 'Septiembre-Octubre'},
            {'mes': 11, 'nombre': 'Noviembre-Diciembre'},
          ];

    final m1 = monto1erVto ?? montoAlDia;
    final m2 = monto2doVto ?? m1;

    final cuotas = bimestres
        .map(
          (bim) => {
            'alumno_id': alumnoId,
            'concepto': 'Cuota ${bim['nombre']} $anio',
            'monto_al_dia': montoAlDia,
            'monto_1er_vto': m1,
            'monto_2do_vto': m2,
            'monto_pagado': 0,
            'mes': bim['mes'],
            'anio': anio,
            'fecha_vencimiento': DateTime(anio, bim['mes'] as int, 1).toIso8601String().split('T')[0],
            'estado': 'pendiente',
          },
        )
        .toList();

    // Inscripción única (solo 1.er año y si no existe una previa)
    if (esPrimero && generarInscripcion) {
      final tieneInscripcion = await _tieneCuotaInscripcion(alumnoId);
      if (!tieneInscripcion) {
        final montoInsc = montoInscripcion ?? montoAlDia;
        cuotas.insert(0, {
          'alumno_id': alumnoId,
          'concepto': 'Inscripción $anio',
          'monto_al_dia': montoInsc,
          'monto_1er_vto': montoInsc,
          'monto_2do_vto': montoInsc,
          'monto_pagado': 0,
          'mes': 3,
          'anio': anio,
          'fecha_vencimiento': DateTime(anio, 3, 1).toIso8601String().split('T')[0],
          'estado': 'pendiente',
        });
      }
    }

    await client.from('cuotas').insert(cuotas);
  }

  Future<bool> _tieneCuotaInscripcion(String alumnoId) async {
    final response = await client
        .from('cuotas')
        .select('id')
        .ilike('concepto', '%Inscripción%')
        .eq('alumno_id', alumnoId)
        .limit(1);
    return response.isNotEmpty;
  }

  Future<void> generarCuotaInscripcion(String alumnoId, int monto) async {
    final tieneInscripcion = await _tieneCuotaInscripcion(alumnoId);
    if (tieneInscripcion) {
      throw Exception('El alumno ya tiene una cuota de inscripción');
    }
    final anio = DateTime.now().year;
    // Inscripción tiene un solo monto fijo (sin vencimientos escalonados)
    await client.from('cuotas').insert({
      'alumno_id': alumnoId,
      'concepto': 'Inscripción $anio',
      'monto_al_dia': monto,
      'monto_1er_vto': monto,
      'monto_2do_vto': monto,
      'monto_pagado': 0,
      'mes': 3,
      'anio': anio,
      'fecha_vencimiento': DateTime(anio, 3, 1).toIso8601String().split('T')[0],
      'estado': 'pendiente',
    });
  }

  /// Genera cuotas bimestrales con los 3 montos de vencimiento
  Future<void> generarCuotasBimestrales(
    String alumnoId,
    int montoAlDia,
    int anio, {
    int? monto1erVto,
    int? monto2doVto,
  }) async {
    // Verificar si ya existen cuotas bimestrales para este alumno y año
    final existentes = await client
        .from('cuotas')
        .select('id')
        .eq('alumno_id', alumnoId)
        .eq('anio', anio)
        .not('concepto', 'ilike', '%Inscripción%')
        .limit(1);

    if ((existentes as List).isNotEmpty) {
      throw Exception('Ya existen cuotas bimestrales para este alumno en $anio');
    }

    final alumno = await getAlumnoById(alumnoId);
    final bool esPrimero = alumno?.nivelInscripcion == 'Primer Año';
    final nivel = alumno?.nivelInscripcion ?? '';

    // 1° año: Mar, May, Jul, Sep, Nov (5 bimestres)
    // 2°/3° año: Ene, Mar, May, Jul, Sep, Nov (6 bimestres)
    final bimestresConfig = esPrimero
        ? [
            {'mes': 3, 'nombre': 'Marzo-Abril', 'bimestre': 2},
            {'mes': 5, 'nombre': 'Mayo-Junio', 'bimestre': 3},
            {'mes': 7, 'nombre': 'Julio-Agosto', 'bimestre': 4},
            {'mes': 9, 'nombre': 'Septiembre-Octubre', 'bimestre': 5},
            {'mes': 11, 'nombre': 'Noviembre-Diciembre', 'bimestre': 6},
          ]
        : [
            {'mes': 1, 'nombre': 'Enero-Febrero', 'bimestre': 1},
            {'mes': 3, 'nombre': 'Marzo-Abril', 'bimestre': 2},
            {'mes': 5, 'nombre': 'Mayo-Junio', 'bimestre': 3},
            {'mes': 7, 'nombre': 'Julio-Agosto', 'bimestre': 4},
            {'mes': 9, 'nombre': 'Septiembre-Octubre', 'bimestre': 5},
            {'mes': 11, 'nombre': 'Noviembre-Diciembre', 'bimestre': 6},
          ];

    final cuotas = <Map<String, dynamic>>[];

    for (final bim in bimestresConfig) {
      // Buscar configuración específica para este nivel/bimestre/año
      final config = await getConfigCuotasPeriodo(
        nivel: nivel,
        bimestre: bim['bimestre'] as int,
        anio: anio,
      );

      final montoA = config?.montoAlDia ?? montoAlDia;
      final montoB = config?.monto1erVto ?? monto1erVto ?? montoAlDia;
      final montoC = config?.monto2doVto ?? monto2doVto ?? monto1erVto ?? montoAlDia;

      cuotas.add({
        'alumno_id': alumnoId,
        'concepto': 'Cuota ${bim['nombre']} $anio',
        'monto_al_dia': montoA,
        'monto_1er_vto': montoB,
        'monto_2do_vto': montoC,
        'monto_pagado': 0,
        'mes': bim['mes'],
        'anio': anio,
        'fecha_vencimiento': DateTime(anio, bim['mes'] as int, 1).toIso8601String().split('T')[0],
        'estado': 'pendiente',
      });
    }

    await client.from('cuotas').insert(cuotas);
  }

  Future<void> actualizarSaldoFavor(String alumnoId, num monto) async {
    // Obtener saldo actual
    final alumno = await client.from('alumnos').select('saldo_favor').eq('id', alumnoId).maybeSingle();
    final saldoActual = (alumno?['saldo_favor'] as num?)?.toInt() ?? 0;
    final nuevoSaldo = saldoActual + monto.toInt();

    await client.from('alumnos').update({
      'saldo_favor': nuevoSaldo,
    }).eq('id', alumnoId);
  }

  /// Elimina TODAS las cuotas de un alumno en un año (para limpiar duplicados)
  Future<void> eliminarCuotasAlumno(String alumnoId, int anio) async {
    await client
        .from('cuotas')
        .delete()
        .eq('alumno_id', alumnoId)
        .eq('anio', anio);
  }

  /// Elimina solo las cuotas NO PAGADAS de un alumno en un año
  Future<void> eliminarCuotasNoPagadas(String alumnoId, int anio) async {
    await client
        .from('cuotas')
        .delete()
        .eq('alumno_id', alumnoId)
        .eq('anio', anio)
        .neq('estado', 'pagada');
  }

  /// Elimina un alumno y todas sus cuotas
  Future<void> eliminarAlumno(String alumnoId) async {
    // Primero eliminar sus cuotas
    await client.from('cuotas').delete().eq('alumno_id', alumnoId);
    // Luego eliminar el alumno
    await client.from('alumnos').delete().eq('id', alumnoId);
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

  /// Registra pago total. Devuelve el nombre del siguiente período si es pago adelantado, o null.
  Future<String?> registrarPagoTotal(
    String cuotaId,
    String metodoPago, {
    String? observaciones,
    String? numRecibo,
    String? detallePago,
  }) async {
    final cuotaData = await client.from('cuotas').select().eq('id', cuotaId).maybeSingle();
    if (cuotaData == null) return null;

    final cuota = _cuotaFromSupabase(cuotaData);
    final montoActual = cuota.montoActual;

    // Paga la cuota actual completa
    await client.from('cuotas').update({
      'monto_pagado': montoActual,
      'estado': 'pagada',
      'fecha_pago': DateTime.now().toIso8601String(),
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
      'num_recibo': numRecibo,
      'detalle_pago': (detallePago?.isNotEmpty ?? false)
          ? detallePago
          : 'Pago total ${cuotaData['concepto']} - \$${montoActual} el ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
    }).eq('id', cuotaId);

    // Detectar si es pago adelantado: la cuota aún no venció
    final ahora = DateTime.now();
    if (cuota.fechaVencimiento.isAfter(ahora)) {
      // Buscar la siguiente cuota pendiente
      final siguiente = await client
          .from('cuotas')
          .select()
          .eq('alumno_id', cuota.alumnoId)
          .neq('id', cuotaId)
          .neq('estado', 'pagada')
          .order('fecha_vencimiento', ascending: true)
          .limit(1)
          .maybeSingle();
      if (siguiente != null) {
        return siguiente['concepto'] as String?;
      }
    }
    return null;
  }

  Future<void> registrarPagoParcial(
    String cuotaId,
    int monto,
    String metodoPago, {
    String? observaciones,
    String? numRecibo,
    String? detallePago,
  }) async {
    final cuotaData = await client.from('cuotas').select().eq('id', cuotaId).maybeSingle();
    if (cuotaData == null) return;

    final alumnoId = cuotaData['alumno_id'];
    final cuota = _cuotaFromSupabase(cuotaData);
    final montoActual = cuota.montoActual; // Monto según vencimiento actual
    final montoPagadoActual = cuota.montoPagado;

    int excedente = 0;
    int pagaActual = monto;

    // Si el pago supera la deuda de la cuota actual, distribuir excedente
    final deudaActual = montoActual - montoPagadoActual;
    if (monto > deudaActual) {
      pagaActual = deudaActual;
      excedente = monto - deudaActual;
    }

    final nuevoMontoPagado = montoPagadoActual + pagaActual;
    final estaPagada = nuevoMontoPagado >= montoActual;

    final hoy = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final detalleConExcedente = excedente > 0
        ? 'Pago parcial \$$monto el $hoy - excedente \$$excedente distribuido a sig. cuota'
        : detallePago ?? 'Pago parcial \$$monto el $hoy';

    await client.from('cuotas').update({
      'monto_pagado': nuevoMontoPagado,
      'estado': estaPagada ? 'pagada' : 'parcial',
      'fecha_pago': DateTime.now().toIso8601String(),
      'metodo_pago': metodoPago,
      'observaciones': observaciones,
      'num_recibo': numRecibo,
      'detalle_pago': detalleConExcedente,
    }).eq('id', cuotaId);

    // Distribuir excedente en próximas cuotas pendientes/vencidas en orden de vencimiento
    if (excedente > 0) {
      final siguientes = await client
          .from('cuotas')
          .select()
          .eq('alumno_id', alumnoId)
          .neq('id', cuotaId)
          .neq('estado', 'pagada')
          .order('fecha_vencimiento', ascending: true);

      int restante = excedente;
      for (final c in siguientes) {
        final cuotaSig = _cuotaFromSupabase(c);
        final deuda = cuotaSig.montoActual - cuotaSig.montoPagado;
        if (deuda <= 0) continue;
        final paga = restante >= deuda ? deuda : restante;

        final nuevoPagado = cuotaSig.montoPagado + paga;
        final pagada = nuevoPagado >= cuotaSig.montoActual;
        final fechaHoy = DateFormat('dd/MM/yyyy').format(DateTime.now());
        final detalleSig = 'Excedente de ${cuota.concepto} - \$$paga aplicado el $fechaHoy (pago original: \$$monto)';
        await client.from('cuotas').update({
          'monto_pagado': nuevoPagado,
          'estado': pagada ? 'pagada' : 'parcial',
          'fecha_pago': DateTime.now().toIso8601String(),
          'metodo_pago': metodoPago,
          'detalle_pago': detalleSig,
          'num_recibo': numRecibo,
        }).eq('id', c['id']);

        restante -= paga;
        if (restante <= 0) break;
      }
    }
  }

  /// Actualiza los 3 montos de una cuota específica
  Future<void> updateMontoCuota(
    String cuotaId, {
    required int montoAlDia,
    required int monto1erVto,
    required int monto2doVto,
  }) async {
    await client.from('cuotas').update({
      'monto_al_dia': montoAlDia,
      'monto_1er_vto': monto1erVto,
      'monto_2do_vto': monto2doVto,
    }).eq('id', cuotaId);
  }

  Future<void> updateFechaVencimiento(String cuotaId, DateTime nuevaFecha) async {
    await client
        .from('cuotas')
        .update({'fecha_vencimiento': nuevaFecha.toIso8601String().split('T')[0]})
        .eq('id', cuotaId);
  }

  /// Actualiza los montos de cuotas de un bimestre con los 3 valores
  Future<void> updateMontoCuotasBimestre({
    required int anio,
    required int bimestre,
    required int montoAlDia,
    required int monto1erVto,
    required int monto2doVto,
    bool soloPendientes = true,
    bool incluirVencidas = true,
  }) async {
    final Map<int, List<int>> bimestresMap = {
      1: [1, 2],
      2: [3, 4],
      3: [5, 6],
      4: [7, 8],
      5: [9, 10],
      6: [11, 12],
    };
    final meses = bimestresMap[bimestre] ?? [];
    if (meses.isEmpty) return;

    // Construir lista de estados a actualizar
    List<String> estadosActualizar = [];
    if (!soloPendientes) {
      estadosActualizar = ['pendiente', 'vencida', 'pagada', 'parcial'];
    } else if (incluirVencidas) {
      estadosActualizar = ['pendiente', 'vencida', 'parcial'];
    } else {
      estadosActualizar = ['pendiente', 'parcial'];
    }

    await client
        .from('cuotas')
        .update({
          'monto_al_dia': montoAlDia,
          'monto_1er_vto': monto1erVto,
          'monto_2do_vto': monto2doVto,
        })
        .eq('anio', anio)
        .inFilter('mes', meses)
        .inFilter('estado', estadosActualizar);
  }

  Cuota _cuotaFromSupabase(Map<String, dynamic> map) {
    // Compatibilidad con estructura anterior (monto único)
    final montoAnterior = (map['monto'] as num?)?.toInt();
    final montoAlDia = (map['monto_al_dia'] as num?)?.toInt() ?? montoAnterior ?? 0;
    final monto1erVto = (map['monto_1er_vto'] as num?)?.toInt() ?? montoAlDia;
    final monto2doVto = (map['monto_2do_vto'] as num?)?.toInt() ?? monto1erVto;

    return Cuota(
      id: map['id']?.toString(),
      alumnoId: map['alumno_id']?.toString() ?? '',
      concepto: map['concepto'] ?? '',
      montoAlDia: montoAlDia,
      monto1erVto: monto1erVto,
      monto2doVto: monto2doVto,
      montoPagado: (map['monto_pagado'] as num?)?.toInt() ?? 0,
      mes: map['mes'] ?? 1,
      anio: map['anio'] ?? DateTime.now().year,
      fechaVencimiento: map['fecha_vencimiento'] != null
          ? DateTime.parse(map['fecha_vencimiento'])
          : DateTime.now(),
      fechaPago: map['fecha_pago'] != null ? DateTime.parse(map['fecha_pago']) : null,
      estado: map['estado'] ?? 'aprobado',
      metodoPago: map['metodo_pago'],
      observaciones: map['observaciones'],
      numRecibo: map['num_recibo'],
      detallePago: map['detalle_pago'],
    );
  }

  // ==================== CONFIGURACIÓN VENCIMIENTOS ====================

  // Cache local de configuración
  ConfigVencimientos? _configVencimientos;

  Future<ConfigVencimientos> getConfigVencimientos() async {
    if (_configVencimientos != null) return _configVencimientos!;

    try {
      final response = await client
          .from('configuracion')
          .select()
          .eq('clave', 'vencimientos')
          .maybeSingle();

      if (response != null && response['valor'] != null) {
        _configVencimientos = ConfigVencimientos.fromMap(response['valor'] as Map<String, dynamic>);
      } else {
        _configVencimientos = ConfigVencimientos(); // Valores por defecto
      }
    } catch (e) {
      // Si la tabla no existe, usar valores por defecto
      _configVencimientos = ConfigVencimientos();
    }

    return _configVencimientos!;
  }

  Future<void> guardarConfigVencimientos(ConfigVencimientos config) async {
    _configVencimientos = config;

    try {
      await client.from('configuracion').upsert({
        'clave': 'vencimientos',
        'valor': config.toMap(),
      }, onConflict: 'clave');
    } catch (e) {
      // Si falla, al menos queda en cache local
    }
  }

  /// Calcula el monto real de una cuota según la fecha actual
  /// NOTA: Esta función ahora simplemente devuelve cuota.montoActual
  /// ya que la lógica de vencimientos está en el modelo Cuota
  Future<int> calcularMontoConRecargo(Cuota cuota) async {
    return cuota.montoActual;
  }

  // ==================== CONFIGURACIÓN CUOTAS POR PERÍODO ====================

  /// Cache local de configuraciones por período
  final Map<String, ConfigCuotasPeriodo> _cacheConfigPeriodo = {};

  /// Obtiene la configuración de montos para un nivel/bimestre/año específico
  Future<ConfigCuotasPeriodo?> getConfigCuotasPeriodo({
    required String nivel,
    required int bimestre,
    required int anio,
  }) async {
    final cacheKey = '${nivel}_${bimestre}_$anio';
    if (_cacheConfigPeriodo.containsKey(cacheKey)) {
      return _cacheConfigPeriodo[cacheKey];
    }

    try {
      final response = await client
          .from('config_cuotas_periodo')
          .select()
          .eq('nivel', nivel)
          .eq('bimestre', bimestre)
          .eq('anio', anio)
          .maybeSingle();

      if (response != null) {
        final config = ConfigCuotasPeriodo.fromMap(response);
        _cacheConfigPeriodo[cacheKey] = config;
        return config;
      }
    } catch (e) {
      // Tabla puede no existir todavía
    }
    return null;
  }

  /// Obtiene todas las configuraciones de un año
  Future<List<ConfigCuotasPeriodo>> getAllConfigCuotasPeriodo(int anio) async {
    try {
      final response = await client
          .from('config_cuotas_periodo')
          .select()
          .eq('anio', anio)
          .order('nivel')
          .order('bimestre');

      return (response as List)
          .map((map) => ConfigCuotasPeriodo.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Guarda o actualiza la configuración de montos para un período
  Future<void> guardarConfigCuotasPeriodo(ConfigCuotasPeriodo config) async {
    final cacheKey = '${config.nivel}_${config.bimestre}_${config.anio}';

    try {
      // Buscar si ya existe
      final existente = await client
          .from('config_cuotas_periodo')
          .select('id')
          .eq('nivel', config.nivel)
          .eq('bimestre', config.bimestre)
          .eq('anio', config.anio)
          .maybeSingle();

      final data = {
        'nivel': config.nivel,
        'bimestre': config.bimestre,
        'anio': config.anio,
        'monto_al_dia': config.montoAlDia,
        'monto_1er_vto': config.monto1erVto,
        'monto_2do_vto': config.monto2doVto,
        'dia_fin_rango_a': config.diaFinRangoA,
        'dia_fin_rango_b': config.diaFinRangoB,
      };

      if (existente != null) {
        await client
            .from('config_cuotas_periodo')
            .update(data)
            .eq('id', existente['id']);
      } else {
        await client.from('config_cuotas_periodo').insert(data);
      }

      _cacheConfigPeriodo[cacheKey] = config;
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza los montos de cuotas existentes según la configuración del período
  Future<void> actualizarCuotasConConfigPeriodo({
    required String nivel,
    required int bimestre,
    required int anio,
    bool soloPendientes = true,
  }) async {
    final config = await getConfigCuotasPeriodo(
      nivel: nivel,
      bimestre: bimestre,
      anio: anio,
    );

    if (config == null) return;

    // Mapear bimestre a meses
    final Map<int, List<int>> bimestresMap = {
      1: [1, 2],
      2: [3, 4],
      3: [5, 6],
      4: [7, 8],
      5: [9, 10],
      6: [11, 12],
    };
    final meses = bimestresMap[bimestre] ?? [];
    if (meses.isEmpty) return;

    // Obtener alumnos del nivel
    final alumnos = await client
        .from('alumnos')
        .select('id')
        .eq('nivel_inscripcion', nivel);

    final alumnoIds = (alumnos as List).map((a) => a['id'] as String).toList();
    if (alumnoIds.isEmpty) return;

    // Construir query base
    var query = client
        .from('cuotas')
        .update({
          'monto_al_dia': config.montoAlDia,
          'monto_1er_vto': config.monto1erVto,
          'monto_2do_vto': config.monto2doVto,
        })
        .eq('anio', anio)
        .inFilter('mes', meses)
        .inFilter('alumno_id', alumnoIds);

    if (soloPendientes) {
      await query.inFilter('estado', ['pendiente', 'vencida', 'parcial']);
    } else {
      await query;
    }
  }

  /// Limpia el cache de configuraciones
  void limpiarCacheConfigPeriodo() {
    _cacheConfigPeriodo.clear();
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
