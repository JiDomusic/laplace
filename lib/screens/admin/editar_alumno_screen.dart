import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/alumno.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class EditarAlumnoScreen extends StatefulWidget {
  final Alumno alumno;

  const EditarAlumnoScreen({super.key, required this.alumno});

  @override
  State<EditarAlumnoScreen> createState() => _EditarAlumnoScreenState();
}

class _EditarAlumnoScreenState extends State<EditarAlumnoScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _db = SupabaseService.instance;
  bool _saving = false;

  // Controllers
  late TextEditingController _nombreCtrl;
  late TextEditingController _apellidoCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _nacionalidadCtrl;
  late TextEditingController _localidadNacCtrl;
  late TextEditingController _provinciaNacCtrl;
  late TextEditingController _calleCtrl;
  late TextEditingController _numeroCtrl;
  late TextEditingController _pisoCtrl;
  late TextEditingController _departamentoCtrl;
  late TextEditingController _localidadCtrl;
  late TextEditingController _codigoPostalCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _celularCtrl;
  late TextEditingController _contactoUrgNombreCtrl;
  late TextEditingController _contactoUrgTelefonoCtrl;
  late TextEditingController _contactoUrgOtroCtrl;
  late TextEditingController _cicloLectivoCtrl;
  late TextEditingController _observacionesCtrl;
  late TextEditingController _observacionesTituloCtrl;

  // Dropdown/state values
  late String _sexo;
  late String _nivelInscripcion;
  late String _contactoUrgVinculo;
  late bool _trabaja;
  late DateTime _fechaNacimiento;

  @override
  void initState() {
    super.initState();
    final a = widget.alumno;
    _nombreCtrl = TextEditingController(text: a.nombre);
    _apellidoCtrl = TextEditingController(text: a.apellido);
    _dniCtrl = TextEditingController(text: a.dni);
    _nacionalidadCtrl = TextEditingController(text: a.nacionalidad);
    _localidadNacCtrl = TextEditingController(text: a.localidadNacimiento ?? '');
    _provinciaNacCtrl = TextEditingController(text: a.provinciaNacimiento ?? '');
    _calleCtrl = TextEditingController(text: a.calle);
    _numeroCtrl = TextEditingController(text: a.numero);
    _pisoCtrl = TextEditingController(text: a.piso ?? '');
    _departamentoCtrl = TextEditingController(text: a.departamento ?? '');
    _localidadCtrl = TextEditingController(text: a.localidad);
    _codigoPostalCtrl = TextEditingController(text: a.codigoPostal);
    _emailCtrl = TextEditingController(text: a.email);
    _telefonoCtrl = TextEditingController(text: a.telefono ?? '');
    _celularCtrl = TextEditingController(text: a.celular);
    _contactoUrgNombreCtrl = TextEditingController(text: a.contactoUrgenciaNombre ?? '');
    _contactoUrgTelefonoCtrl = TextEditingController(text: a.contactoUrgenciaTelefono ?? '');
    _contactoUrgOtroCtrl = TextEditingController(text: a.contactoUrgenciaOtro ?? '');
    _cicloLectivoCtrl = TextEditingController(text: a.cicloLectivo ?? DateTime.now().year.toString());
    _observacionesCtrl = TextEditingController(text: a.observaciones ?? '');
    _observacionesTituloCtrl = TextEditingController(text: a.observacionesTitulo ?? '');

    _sexo = a.sexo;
    _nivelInscripcion = a.nivelInscripcion;
    _contactoUrgVinculo = a.contactoUrgenciaVinculo ?? 'Madre';
    _trabaja = a.trabaja;
    _fechaNacimiento = a.fechaNacimiento;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    _nacionalidadCtrl.dispose();
    _localidadNacCtrl.dispose();
    _provinciaNacCtrl.dispose();
    _calleCtrl.dispose();
    _numeroCtrl.dispose();
    _pisoCtrl.dispose();
    _departamentoCtrl.dispose();
    _localidadCtrl.dispose();
    _codigoPostalCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _celularCtrl.dispose();
    _contactoUrgNombreCtrl.dispose();
    _contactoUrgTelefonoCtrl.dispose();
    _contactoUrgOtroCtrl.dispose();
    _cicloLectivoCtrl.dispose();
    _observacionesCtrl.dispose();
    _observacionesTituloCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // Check DNI uniqueness if changed
      if (_dniCtrl.text != widget.alumno.dni) {
        final existe = await _db.getAlumnoByDni(_dniCtrl.text);
        if (existe != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ya existe un alumno con DNI ${_dniCtrl.text}'), backgroundColor: Colors.red),
            );
          }
          setState(() => _saving = false);
          return;
        }
      }

      // Warn if nivel changed
      if (_nivelInscripcion != widget.alumno.nivelInscripcion) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambio de nivel'),
            content: const Text(
              'Cambiar el nivel de inscripcion puede generar inconsistencias con las cuotas existentes. ¿Continuar?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
            ],
          ),
        );
        if (confirmar != true) {
          setState(() => _saving = false);
          return;
        }
      }

      final updated = widget.alumno.copyWith(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        sexo: _sexo,
        fechaNacimiento: _fechaNacimiento,
        nacionalidad: _nacionalidadCtrl.text.trim(),
        localidadNacimiento: _localidadNacCtrl.text.trim().isNotEmpty ? _localidadNacCtrl.text.trim() : null,
        provinciaNacimiento: _provinciaNacCtrl.text.trim().isNotEmpty ? _provinciaNacCtrl.text.trim() : null,
        calle: _calleCtrl.text.trim(),
        numero: _numeroCtrl.text.trim(),
        piso: _pisoCtrl.text.trim().isNotEmpty ? _pisoCtrl.text.trim() : null,
        departamento: _departamentoCtrl.text.trim().isNotEmpty ? _departamentoCtrl.text.trim() : null,
        localidad: _localidadCtrl.text.trim(),
        codigoPostal: _codigoPostalCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
        celular: _celularCtrl.text.trim(),
        trabaja: _trabaja,
        contactoUrgenciaNombre: _contactoUrgNombreCtrl.text.trim().isNotEmpty ? _contactoUrgNombreCtrl.text.trim() : null,
        contactoUrgenciaTelefono: _contactoUrgTelefonoCtrl.text.trim().isNotEmpty ? _contactoUrgTelefonoCtrl.text.trim() : null,
        contactoUrgenciaVinculo: _contactoUrgVinculo,
        contactoUrgenciaOtro: _contactoUrgOtroCtrl.text.trim().isNotEmpty ? _contactoUrgOtroCtrl.text.trim() : null,
        cicloLectivo: _cicloLectivoCtrl.text.trim(),
        nivelInscripcion: _nivelInscripcion,
        observaciones: _observacionesCtrl.text.trim().isNotEmpty ? _observacionesCtrl.text.trim() : null,
        observacionesTitulo: _observacionesTituloCtrl.text.trim().isNotEmpty ? _observacionesTituloCtrl.text.trim() : null,
      );

      await _db.updateAlumno(widget.alumno.id!, updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alumno actualizado correctamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar: ${widget.alumno.nombreCompleto}'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _guardar,
              tooltip: 'Guardar cambios',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSeccion('Datos Personales', [
                    Row(
                      children: [
                        Expanded(child: _buildField('Nombre', _nombreCtrl, required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Apellido', _apellidoCtrl, required: true)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField('DNI', _dniCtrl, required: true, keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sexo,
                            decoration: const InputDecoration(labelText: 'Sexo', border: OutlineInputBorder()),
                            items: ['Masculino', 'Femenino', 'Otro']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => setState(() => _sexo = v!),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaNacimiento,
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _fechaNacimiento = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de Nacimiento',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_fechaNacimiento)),
                      ),
                    ),
                    _buildField('Nacionalidad', _nacionalidadCtrl, required: true),
                    Row(
                      children: [
                        Expanded(child: _buildField('Localidad de Nacimiento', _localidadNacCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Provincia de Nacimiento', _provinciaNacCtrl)),
                      ],
                    ),
                  ]),
                  _buildSeccion('Domicilio', [
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildField('Calle', _calleCtrl, required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Numero', _numeroCtrl, required: true)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField('Piso', _pisoCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Departamento', _departamentoCtrl)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildField('Localidad', _localidadCtrl, required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Codigo Postal', _codigoPostalCtrl, required: true)),
                      ],
                    ),
                  ]),
                  _buildSeccion('Contacto', [
                    _buildField('Email', _emailCtrl, keyboardType: TextInputType.emailAddress),
                    Row(
                      children: [
                        Expanded(child: _buildField('Celular', _celularCtrl, required: true, keyboardType: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Telefono', _telefonoCtrl, keyboardType: TextInputType.phone)),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('Trabaja'),
                      value: _trabaja,
                      onChanged: (v) => setState(() => _trabaja = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ]),
                  _buildSeccion('Contacto de Urgencia', [
                    Row(
                      children: [
                        Expanded(child: _buildField('Nombre', _contactoUrgNombreCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField('Telefono', _contactoUrgTelefonoCtrl, keyboardType: TextInputType.phone)),
                      ],
                    ),
                    DropdownButtonFormField<String>(
                      value: ['Madre', 'Padre', 'Tutor', 'Otro'].contains(_contactoUrgVinculo) ? _contactoUrgVinculo : 'Otro',
                      decoration: const InputDecoration(labelText: 'Vinculo', border: OutlineInputBorder()),
                      items: ['Madre', 'Padre', 'Tutor', 'Otro']
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => _contactoUrgVinculo = v!),
                    ),
                    if (_contactoUrgVinculo == 'Otro')
                      _buildField('Especifique vinculo', _contactoUrgOtroCtrl),
                  ]),
                  _buildSeccion('Inscripcion', [
                    DropdownButtonFormField<String>(
                      value: _nivelInscripcion,
                      decoration: const InputDecoration(labelText: 'Nivel de Inscripcion', border: OutlineInputBorder()),
                      items: ['Primer Año', 'Segundo Año', 'Tercer Año']
                          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                          .toList(),
                      onChanged: (v) => setState(() => _nivelInscripcion = v!),
                    ),
                    _buildField('Cohorte / Ciclo Lectivo', _cicloLectivoCtrl, keyboardType: TextInputType.number),
                  ]),
                  _buildSeccion('Observaciones', [
                    _buildField('Observaciones generales', _observacionesCtrl, maxLines: 3),
                    _buildField('Observaciones titulo secundario', _observacionesTituloCtrl, maxLines: 2),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _guardar,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 12),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Requerido' : null
          : null,
    );
  }
}
