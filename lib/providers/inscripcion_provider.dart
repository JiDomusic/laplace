import 'package:flutter/foundation.dart';
import '../models/alumno.dart';
import '../models/legajo.dart';
import '../models/picked_file.dart';
import '../services/supabase_service.dart';

class InscripcionProvider with ChangeNotifier {
  final SupabaseService _db = SupabaseService.instance;

  // Estado del formulario
  int _currentStep = 0;
  String? _nivelSeleccionado;

  // Datos del alumno
  String nombre = '';
  String apellido = '';
  String dni = '';
  String sexo = '';
  DateTime? fechaNacimiento;
  String nacionalidad = 'Argentina';
  String localidadNacimiento = '';
  String provinciaNacimiento = '';
  String calle = '';
  String numero = '';
  String? piso;
  String? departamento;
  String localidad = 'Rosario';
  String codigoPostal = '';
  String email = '';
  String? telefono;
  String celular = '';
  bool trabaja = false;
  String _cicloLectivo = DateTime.now().year.toString();
  String get cicloLectivo => _cicloLectivo;
  set cicloLectivo(String value) {
    _cicloLectivo = value;
    notifyListeners();
  }

  // Contacto de urgencia
  String contactoUrgenciaNombre = '';
  String contactoUrgenciaTelefono = '';
  String contactoUrgenciaVinculo = '';
  String contactoUrgenciaOtro = ''; // Cuando es "Otro"

  // Título secundario
  String observacionesTitulo = ''; // Para fecha y materias adeudadas

  // Archivos (usando SelectedFile para compatibilidad web/movil)
  SelectedFile? fotoAlumno;
  SelectedFile? certificadoTrabajo;
  SelectedFile? dniFrente;
  SelectedFile? dniDorso;
  SelectedFile? partidaNacimiento;
  bool nacidoFueraSantaFe = false;
  String estadoTitulo = '';
  String? tipoLegalizacion;
  SelectedFile? tituloArchivo;
  SelectedFile? tramiteConstancia;
  String? materiasAdeudadas;
  SelectedFile? materiasConstancia;

  // Resultado de inscripción
  Alumno? _alumnoRegistrado;
  bool _isLoading = false;
  String? _error;

  // Getters
  int get currentStep => _currentStep;
  String? get nivelSeleccionado => _nivelSeleccionado;
  Alumno? get alumnoRegistrado => _alumnoRegistrado;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Setters
  void setNivel(String nivel) {
    _nivelSeleccionado = nivel;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void setFotoAlumno(SelectedFile? file) {
    fotoAlumno = file;
    notifyListeners();
  }

  void setCertificadoTrabajo(SelectedFile? file) {
    certificadoTrabajo = file;
    notifyListeners();
  }

  void setDniFrente(SelectedFile? file) {
    dniFrente = file;
    notifyListeners();
  }

  void setDniDorso(SelectedFile? file) {
    dniDorso = file;
    notifyListeners();
  }

  void setPartidaNacimiento(SelectedFile? file) {
    partidaNacimiento = file;
    notifyListeners();
  }

  void setTituloArchivo(SelectedFile? file) {
    tituloArchivo = file;
    notifyListeners();
  }

  void setTramiteConstancia(SelectedFile? file) {
    tramiteConstancia = file;
    notifyListeners();
  }

  void setMateriasConstancia(SelectedFile? file) {
    materiasConstancia = file;
    notifyListeners();
  }

  // Validaciones
  bool validarPaso1() {
    return _nivelSeleccionado != null && _nivelSeleccionado!.isNotEmpty;
  }

  bool validarPaso2() {
    return nombre.isNotEmpty &&
        apellido.isNotEmpty &&
        dni.isNotEmpty &&
        sexo.isNotEmpty &&
        fechaNacimiento != null &&
        calle.isNotEmpty &&
        numero.isNotEmpty &&
        localidad.isNotEmpty &&
        codigoPostal.isNotEmpty &&
        email.isNotEmpty &&
        celular.isNotEmpty &&
        contactoUrgenciaNombre.isNotEmpty &&
        contactoUrgenciaTelefono.isNotEmpty &&
        contactoUrgenciaVinculo.isNotEmpty &&
        fotoAlumno != null;
  }

  bool validarPaso3() {
    if (dniFrente == null || dniDorso == null) return false;
    if (nacidoFueraSantaFe && partidaNacimiento == null) return false;
    if (estadoTitulo.isEmpty) return false;

    switch (estadoTitulo) {
      case 'terminado':
        return tipoLegalizacion != null && tituloArchivo != null;
      case 'en_tramite':
        return tramiteConstancia != null;
      case 'debe_materias':
        return materiasAdeudadas != null &&
            materiasAdeudadas!.isNotEmpty &&
            materiasConstancia != null;
      default:
        return false;
    }
  }

  // Guardar inscripción
  Future<bool> guardarInscripcion() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Validar duplicado por DNI antes de subir archivos
      final existe = await _db.getAlumnoByDni(dni);
      if (existe != null) {
        _error = 'Ya existe un alumno con DNI $dni';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Crear alumno
      // Subir archivos al storage
      String? fotoUrl;
      String? certificadoTrabajoUrl;
      String? dniFrenteUrl;
      String? dniDorsoUrl;
      String? partidaNacimientoUrl;
      String? tituloUrl;
      String? tramiteConstanciaUrl;
      String? materiasConstanciaUrl;

      if (fotoAlumno != null) {
        fotoUrl = await _db.uploadFotoAlumno(dni, fotoAlumno!);
      }
      if (certificadoTrabajo != null) {
        certificadoTrabajoUrl = await _db.uploadDocumento('documentos-certificados', dni, 'certificado', certificadoTrabajo!);
      }
      if (dniFrente != null) {
        dniFrenteUrl = await _db.uploadDNI(dni, dniFrente!, 'frente');
      }
      if (dniDorso != null) {
        dniDorsoUrl = await _db.uploadDNI(dni, dniDorso!, 'dorso');
      }
      if (partidaNacimiento != null) {
        partidaNacimientoUrl = await _db.uploadDocumento('documentos-partidas', dni, 'partida', partidaNacimiento!);
      }
      if (tituloArchivo != null) {
        tituloUrl = await _db.uploadTitulo(dni, tituloArchivo!);
      }
      if (tramiteConstancia != null) {
        tramiteConstanciaUrl = await _db.uploadDocumento('documentos-certificados', dni, 'tramite', tramiteConstancia!);
      }
      if (materiasConstancia != null) {
        materiasConstanciaUrl = await _db.uploadDocumento('documentos-certificados', dni, 'materias', materiasConstancia!);
      }

      // Crear alumno
      final alumno = Alumno(
        nombre: nombre,
        apellido: apellido,
        dni: dni,
        sexo: sexo,
        fechaNacimiento: fechaNacimiento!,
        nacionalidad: nacionalidad,
        localidadNacimiento: localidadNacimiento.isNotEmpty ? localidadNacimiento : null,
        provinciaNacimiento: provinciaNacimiento.isNotEmpty ? provinciaNacimiento : null,
        calle: calle,
        numero: numero,
        piso: piso,
        departamento: departamento,
        localidad: localidad,
        codigoPostal: codigoPostal,
        email: email,
        telefono: telefono,
        celular: celular,
        trabaja: trabaja,
        certificadoTrabajo: certificadoTrabajoUrl,
        contactoUrgenciaNombre: contactoUrgenciaNombre,
        contactoUrgenciaTelefono: contactoUrgenciaTelefono,
        contactoUrgenciaVinculo: contactoUrgenciaVinculo,
        contactoUrgenciaOtro: contactoUrgenciaOtro.isNotEmpty ? contactoUrgenciaOtro : null,
        observacionesTitulo: observacionesTitulo.isNotEmpty ? observacionesTitulo : null,
        cicloLectivo: cicloLectivo,
        fotoAlumno: fotoUrl,
        nivelInscripcion: _nivelSeleccionado!,
      );

      // Insertar en Supabase
      final alumnoId = await _db.insertAlumno(alumno);

      // Crear legajo
      final legajo = Legajo(
        alumnoId: alumnoId,
        dniFrente: dniFrenteUrl,
        dniDorso: dniDorsoUrl,
        partidaNacimiento: partidaNacimientoUrl,
        nacidoFueraSantaFe: nacidoFueraSantaFe,
        estadoTitulo: estadoTitulo,
        tituloArchivo: tituloUrl,
        tramiteConstancia: tramiteConstanciaUrl,
        materiasAdeudadas: materiasAdeudadas,
        materiasConstancia: materiasConstanciaUrl,
        tipoLegalizacion: tipoLegalizacion,
      );

      await _db.insertLegajo(alumnoId, legajo);

      // Obtener alumno con código generado
      _alumnoRegistrado = await _db.getAlumnoById(alumnoId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Resetear formulario
  void reset() {
    _currentStep = 0;
    _nivelSeleccionado = null;
    nombre = '';
    apellido = '';
    dni = '';
    sexo = '';
    fechaNacimiento = null;
    nacionalidad = 'Argentina';
    localidadNacimiento = '';
    provinciaNacimiento = '';
    calle = '';
    numero = '';
    piso = null;
    departamento = null;
    localidad = 'Rosario';
    codigoPostal = '';
    email = '';
    telefono = null;
    celular = '';
    trabaja = false;
    _cicloLectivo = DateTime.now().year.toString();
    contactoUrgenciaNombre = '';
    contactoUrgenciaTelefono = '';
    contactoUrgenciaVinculo = '';
    contactoUrgenciaOtro = '';
    observacionesTitulo = '';
    fotoAlumno = null;
    certificadoTrabajo = null;
    dniFrente = null;
    dniDorso = null;
    partidaNacimiento = null;
    nacidoFueraSantaFe = false;
    estadoTitulo = '';
    tipoLegalizacion = null;
    tituloArchivo = null;
    tramiteConstancia = null;
    materiasAdeudadas = null;
    materiasConstancia = null;
    _alumnoRegistrado = null;
    _error = null;
    notifyListeners();
  }
}
