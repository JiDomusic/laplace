import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../providers/inscripcion_provider.dart';
import '../models/picked_file.dart';
import '../utils/app_theme.dart';

class InscripcionScreen extends StatefulWidget {
  const InscripcionScreen({super.key});

  @override
  State<InscripcionScreen> createState() => _InscripcionScreenState();
}

class _InscripcionScreenState extends State<InscripcionScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscripcion'),
      ),
      body: Consumer<InscripcionProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Indicador de progreso
              _buildProgressIndicator(provider.currentStep),

              // Contenido del paso actual
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: _buildCurrentStep(provider),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    final steps = ['Nivel', 'Datos', 'Documentos', 'Confirmar'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (index) {
          final isActive = index <= currentStep;
          final isCurrent = index == currentStep;

          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
                  ),
                  child: Center(
                    child: isCurrent
                        ? Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : isActive
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppTheme.primaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(InscripcionProvider provider) {
    switch (provider.currentStep) {
      case 0:
        return _buildPaso1Nivel(provider);
      case 1:
        return _buildPaso2Datos(provider);
      case 2:
        return _buildPaso3Documentos(provider);
      case 3:
        return _buildPaso4Confirmar(provider);
      default:
        return const SizedBox();
    }
  }

  // PASO 1: Selección de Nivel
  Widget _buildPaso1Nivel(InscripcionProvider provider) {
    final niveles = ['Primer Año', 'Segundo Año', 'Tercer Año'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado con información de la carrera
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.school, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text(
                    'INSTITUTO SUPERIOR LAPLACE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Autorizado a la enseñanza oficial N°9250',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Divider(height: 24),
              const Text(
                'Carrera: Tecnico Superior en Seguridad e Higiene en el Trabajo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Ciclo lectivo: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue: provider.cicloLectivo,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) => provider.cicloLectivo = v,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Selecciona el nivel al que se inscribe',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...niveles.map((nivel) => _buildNivelCard(nivel, provider)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.nivelSeleccionado != null
                ? () => provider.nextStep()
                : null,
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }

  Widget _buildNivelCard(String nivel, InscripcionProvider provider) {
    final isSelected = provider.nivelSeleccionado == nivel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => provider.setNivel(nivel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: nivel,
                groupValue: provider.nivelSeleccionado,
                onChanged: (value) => provider.setNivel(value!),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nivel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Ciclo lectivo ${provider.cicloLectivo}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PASO 2: Datos Personales
  Widget _buildPaso2Datos(InscripcionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cohorte vs Reinscripción
        _buildSeccion('Tipo de inscripción', [
          Row(
            children: [
              ChoiceChip(
                label: const Text('Cohorte'),
                selected: true,
                onSelected: (_) => provider.setTipoInscripcion('cohorte'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Año cohorte (aaaa)'),
                  initialValue: provider.cicloLectivo,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.cicloLectivo = v,
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),

        // Foto del alumno
        _buildSeccion('Foto del Alumno', [
          _buildImagePicker(
            'Subir foto clara del alumno',
            provider.fotoAlumno,
            (file) => provider.setFotoAlumno(file),
          ),
        ]),

        // Datos personales
        _buildSeccion('Datos Personales', [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nombre *'),
            initialValue: provider.nombre,
            onChanged: (v) => provider.nombre = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Apellido *'),
            initialValue: provider.apellido,
            onChanged: (v) => provider.apellido = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'DNI *'),
                  initialValue: provider.dni,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.dni = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Sexo *'),
                  value: provider.sexo.isEmpty ? null : provider.sexo,
                  items: ['Masculino', 'Femenino', 'Otro']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => provider.sexo = v ?? '',
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDatePicker(provider),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nacionalidad *'),
            initialValue: provider.nacionalidad,
            onChanged: (v) => provider.nacionalidad = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Localidad de Nacimiento *'),
                  initialValue: provider.localidadNacimiento,
                  onChanged: (v) => provider.localidadNacimiento = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Provincia *'),
                  initialValue: provider.provinciaNacimiento,
                  onChanged: (v) => provider.provinciaNacimiento = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
        ]),

        // Domicilio
        _buildSeccion('Domicilio', [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Calle *'),
                  initialValue: provider.calle,
                  onChanged: (v) => provider.calle = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Numero *'),
                  initialValue: provider.numero,
                  onChanged: (v) => provider.numero = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Piso'),
                  initialValue: provider.piso,
                  onChanged: (v) => provider.piso = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Depto'),
                  initialValue: provider.departamento,
                  onChanged: (v) => provider.departamento = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Localidad *'),
                  initialValue: provider.localidad,
                  onChanged: (v) => provider.localidad = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Codigo Postal *'),
                  initialValue: provider.codigoPostal,
                  onChanged: (v) => provider.codigoPostal = v,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
        ]),

        // Contacto
        _buildSeccion('Contacto', [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email'),
            initialValue: provider.email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => provider.email = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Telefono'),
            initialValue: provider.telefono,
            keyboardType: TextInputType.phone,
            onChanged: (v) => provider.telefono = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Celular *'),
            initialValue: provider.celular,
            keyboardType: TextInputType.phone,
            onChanged: (v) => provider.celular = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
        ]),

        // Contacto de Urgencia
        _buildSeccion('Contacto de Urgencia', [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nombre del Contacto *'),
            initialValue: provider.contactoUrgenciaNombre,
            onChanged: (v) => provider.contactoUrgenciaNombre = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Telefono del Contacto *'),
            initialValue: provider.contactoUrgenciaTelefono,
            keyboardType: TextInputType.phone,
            onChanged: (v) => provider.contactoUrgenciaTelefono = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Vinculo con el Alumno *'),
            value: provider.contactoUrgenciaVinculo.isEmpty ? null : provider.contactoUrgenciaVinculo,
            items: const [
              DropdownMenuItem(value: 'Madre', child: Text('Madre')),
              DropdownMenuItem(value: 'Padre', child: Text('Padre')),
              DropdownMenuItem(value: 'Tutora', child: Text('Tutor/a')),
              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => provider.contactoUrgenciaVinculo = v ?? ''),
            validator: (v) => v == null ? 'Requerido' : null,
          ),
          if (provider.contactoUrgenciaVinculo == 'Otro') ...[
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Especificar vinculo *',
                hintText: 'Ej: Hermano, Abuelo, Amigo...',
              ),
              initialValue: provider.contactoUrgenciaOtro,
              onChanged: (v) => provider.contactoUrgenciaOtro = v,
              validator: (v) => provider.contactoUrgenciaVinculo == 'Otro' && v!.isEmpty ? 'Requerido' : null,
            ),
          ],
        ]),

        // Situación laboral
        _buildSeccion('Situacion Laboral', [
          CheckboxListTile(
            title: const Text('¿TRABAJA?'),
            value: provider.trabaja,
            onChanged: (v) => setState(() => provider.trabaja = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (provider.trabaja)
            _buildFilePicker(
              'Certificado de Trabajo',
              provider.certificadoTrabajo,
              (file) => provider.setCertificadoTrabajo(file),
            ),
        ]),

        const SizedBox(height: 24),
        _buildNavigationButtons(provider),
      ],
    );
  }

  // PASO 3: Documentos
  Widget _buildPaso3Documentos(InscripcionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeccion('DNI', [
          _buildFilePicker(
            'DNI Frente *',
            provider.dniFrente,
            (file) => provider.setDniFrente(file),
          ),
          const SizedBox(height: 12),
          _buildFilePicker(
            'DNI Dorso *',
            provider.dniDorso,
            (file) => provider.setDniDorso(file),
          ),
        ]),

        _buildSeccion('Partida de Nacimiento', [
          const Text(
            'ADJUNTAR (+)',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildFilePicker(
            'Agregar Partida de Nacimiento',
            provider.partidaNacimiento,
            (file) => provider.setPartidaNacimiento(file),
          ),
        ]),

        _buildSeccion('Titulo Secundario', [
          const Text(
            'Seleccione una opcion:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          // Opción 1: Título Legalizado o Digital
          CheckboxListTile(
            title: const Text('TITULO LEGALIZADO O DIGITAL'),
            value: provider.estadoTitulo == 'terminado',
            onChanged: (v) => setState(() {
              if (v == true) {
                provider.estadoTitulo = 'terminado';
              } else {
                provider.estadoTitulo = '';
              }
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (provider.estadoTitulo == 'terminado') ...[
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: _buildFilePicker(
                'Adjuntar Titulo *',
                provider.tituloArchivo,
                (file) => provider.setTituloArchivo(file),
              ),
            ),
          ],
          // Opción 2: Constancia de Título en Trámite
          CheckboxListTile(
            title: const Text('CONSTANCIA DE TITULO EN TRAMITE'),
            value: provider.estadoTitulo == 'en_tramite',
            onChanged: (v) => setState(() {
              if (v == true) {
                provider.estadoTitulo = 'en_tramite';
              } else {
                provider.estadoTitulo = '';
              }
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (provider.estadoTitulo == 'en_tramite') ...[
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilePicker(
                    'Adjuntar Constancia *',
                    provider.tramiteConstancia,
                    (file) => provider.setTramiteConstancia(file),
                  ),
                ],
              ),
            ),
          ],
          // Opción 3: Certificado de Estudios Incompletos
          CheckboxListTile(
            title: const Text('CERTIFICADO DE ESTUDIOS INCOMPLETOS'),
            value: provider.estadoTitulo == 'debe_materias',
            onChanged: (v) => setState(() {
              if (v == true) {
                provider.estadoTitulo = 'debe_materias';
              } else {
                provider.estadoTitulo = '';
              }
            }),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          if (provider.estadoTitulo == 'debe_materias') ...[
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilePicker(
                    'Adjuntar Certificado *',
                    provider.materiasConstancia,
                    (file) => provider.setMateriasConstancia(file),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Materias adeudadas *',
                      hintText: 'Ej: Matematica, Historia',
                    ),
                    maxLines: 2,
                    initialValue: provider.materiasAdeudadas,
                    onChanged: (v) => provider.materiasAdeudadas = v,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Campo de observaciones para fecha y notas
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              hintText: 'Fecha del certificado, notas adicionales...',
            ),
            maxLines: 3,
            initialValue: provider.observacionesTitulo,
            onChanged: (v) => provider.observacionesTitulo = v,
          ),
        ]),

        const SizedBox(height: 24),
        _buildNavigationButtons(provider),
      ],
    );
  }

  // PASO 4: Confirmar
  Widget _buildPaso4Confirmar(InscripcionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Colors.blue.shade50,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Revisa que todos los datos sean correctos antes de enviar.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildResumenCard('Nivel', provider.nivelSeleccionado ?? ''),
        _buildResumenCard('Nombre', '${provider.nombre} ${provider.apellido}'),
        _buildResumenCard('DNI', provider.dni),
        _buildResumenCard('Email', provider.email),
        _buildResumenCard('Celular', provider.celular),
        _buildResumenCard('Direccion', '${provider.calle} ${provider.numero}, ${provider.localidad}'),
        _buildResumenCard('Contacto Urgencia', '${provider.contactoUrgenciaNombre} (${provider.contactoUrgenciaVinculo})'),
        _buildResumenCard('Tel. Urgencia', provider.contactoUrgenciaTelefono),
        _buildResumenCard('Tipo de inscripción', provider.tipoInscripcion == 'cohorte' ? 'Cohorte (nuevo)' : 'Ciclo lectivo'),

        const SizedBox(height: 24),

        CheckboxListTile(
          value: true,
          onChanged: (v) {},
          title: const Text(
            'Declaro que todos los datos son verdaderos y los documentos autenticos.',
            style: TextStyle(fontSize: 14),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        const SizedBox(height: 24),

        if (provider.isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => provider.prevStep(),
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await provider.guardarInscripcion();
                        if (success && mounted) {
                          Navigator.pushReplacementNamed(context, '/exito');
                        } else if (provider.error != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.error!)),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Enviar Inscripcion'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildResumenCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDatePicker(InscripcionProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Día (dd) *'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final dia = int.tryParse(v) ?? 0;
              final fecha = provider.fechaNacimiento ?? DateTime(2000);
              if (dia > 0 && dia <= 31) {
                setState(() => provider.fechaNacimiento = DateTime(fecha.year, fecha.month, dia));
              }
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Mes (mm) *'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final mes = int.tryParse(v) ?? 0;
              final fecha = provider.fechaNacimiento ?? DateTime(2000);
              if (mes > 0 && mes <= 12) {
                setState(() => provider.fechaNacimiento = DateTime(fecha.year, mes, fecha.day));
              }
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            decoration: const InputDecoration(labelText: 'Año (aaaa) *'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final anio = int.tryParse(v) ?? 0;
              final fecha = provider.fechaNacimiento ?? DateTime(2000);
              if (anio > 1900 && anio <= DateTime.now().year) {
                setState(() => provider.fechaNacimiento = DateTime(anio, fecha.month, fecha.day));
              }
            },
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(String label, SelectedFile? file, Function(SelectedFile?) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AspectRatio(
              aspectRatio: 3 / 4, // Evita que el card quede demasiado horizontal
              child: InkWell(
                onTap: () async {
                  // Usar FilePicker para imagenes (funciona en web y movil)
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true, // Importante: obtener bytes para web
                  );
                  if (result != null && result.files.single.bytes != null) {
                    final platformFile = result.files.single;
                    onPicked(SelectedFile(
                      name: platformFile.name,
                      bytes: platformFile.bytes!,
                      // No acceder a path en web - causa excepcion
                    ));
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: file != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(file.bytes, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Toca para seleccionar'),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker(String label, SelectedFile? file, Function(SelectedFile?) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
              withData: true, // Importante: obtener bytes para web
            );
            if (result != null && result.files.single.bytes != null) {
              final platformFile = result.files.single;
              onPicked(SelectedFile(
                name: platformFile.name,
                bytes: platformFile.bytes!,
                // No acceder a path en web - causa excepcion
              ));
            }
          },
          icon: Icon(file != null ? Icons.check : Icons.upload_file),
          label: Text(file != null ? 'Archivo seleccionado' : label),
          style: OutlinedButton.styleFrom(
            foregroundColor: file != null ? AppTheme.successColor : null,
          ),
        ),
        if (file != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              file.name,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationButtons(InscripcionProvider provider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => provider.prevStep(),
            child: const Text('Anterior'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                provider.nextStep();
              }
            },
            child: const Text('Continuar'),
          ),
        ),
      ],
    );
  }
}
