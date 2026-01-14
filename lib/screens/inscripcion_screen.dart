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
        const Text(
          'Selecciona el nivel al que te vas a inscribir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
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
                    'Ciclo Lectivo 2026',
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
            decoration: const InputDecoration(labelText: 'Email *'),
            initialValue: provider.email,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => provider.email = v,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
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
              DropdownMenuItem(value: 'Padre', child: Text('Padre')),
              DropdownMenuItem(value: 'Madre', child: Text('Madre')),
              DropdownMenuItem(value: 'Hermano/a', child: Text('Hermano/a')),
              DropdownMenuItem(value: 'Esposo/a', child: Text('Esposo/a')),
              DropdownMenuItem(value: 'Hijo/a', child: Text('Hijo/a')),
              DropdownMenuItem(value: 'Tio/a', child: Text('Tio/a')),
              DropdownMenuItem(value: 'Abuelo/a', child: Text('Abuelo/a')),
              DropdownMenuItem(value: 'Primo/a', child: Text('Primo/a')),
              DropdownMenuItem(value: 'Amigo/a', child: Text('Amigo/a')),
              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
            ],
            onChanged: (v) => provider.contactoUrgenciaVinculo = v ?? '',
            validator: (v) => v == null ? 'Requerido' : null,
          ),
        ]),

        // Situación laboral
        _buildSeccion('Situacion Laboral', [
          SwitchListTile(
            title: const Text('¿Actualmente trabajas?'),
            value: provider.trabaja,
            onChanged: (v) => setState(() => provider.trabaja = v),
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
          SwitchListTile(
            title: const Text('¿Naciste fuera de Santa Fe?'),
            value: provider.nacidoFueraSantaFe,
            onChanged: (v) => setState(() => provider.nacidoFueraSantaFe = v),
          ),
          if (provider.nacidoFueraSantaFe)
            _buildFilePicker(
              'Partida de Nacimiento *',
              provider.partidaNacimiento,
              (file) => provider.setPartidaNacimiento(file),
            ),
        ]),

        _buildSeccion('Titulo Secundario', [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Estado del titulo *'),
            value: provider.estadoTitulo.isEmpty ? null : provider.estadoTitulo,
            items: const [
              DropdownMenuItem(value: 'terminado', child: Text('Tengo el titulo')),
              DropdownMenuItem(value: 'en_tramite', child: Text('Esta en tramite')),
              DropdownMenuItem(value: 'debe_materias', child: Text('Debo materias')),
            ],
            onChanged: (v) => setState(() => provider.estadoTitulo = v ?? ''),
          ),
          const SizedBox(height: 16),
          if (provider.estadoTitulo == 'terminado') ...[
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Tipo de legalizacion *'),
              value: provider.tipoLegalizacion,
              items: const [
                DropdownMenuItem(value: 'tribunales', child: Text('Legalizado por Tribunales')),
                DropdownMenuItem(value: 'institucion', child: Text('Legalizado por la institucion')),
                DropdownMenuItem(value: 'digital', child: Text('Titulo Digital')),
              ],
              onChanged: (v) => setState(() => provider.tipoLegalizacion = v),
            ),
            const SizedBox(height: 12),
            _buildFilePicker(
              'Titulo Legalizado *',
              provider.tituloArchivo,
              (file) => provider.setTituloArchivo(file),
            ),
          ],
          if (provider.estadoTitulo == 'en_tramite')
            _buildFilePicker(
              'Constancia de Tramite *',
              provider.tramiteConstancia,
              (file) => provider.setTramiteConstancia(file),
            ),
          if (provider.estadoTitulo == 'debe_materias') ...[
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Materias que adeudas *',
                hintText: 'Ej: Matematica, Historia',
              ),
              maxLines: 2,
              onChanged: (v) => provider.materiasAdeudadas = v,
            ),
            const SizedBox(height: 12),
            _buildFilePicker(
              'Constancia de Materias *',
              provider.materiasConstancia,
              (file) => provider.setMateriasConstancia(file),
            ),
          ],
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
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: provider.fechaNacimiento ?? DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => provider.fechaNacimiento = date);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de Nacimiento *',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          provider.fechaNacimiento != null
              ? DateFormat('dd/MM/yyyy').format(provider.fechaNacimiento!)
              : 'Seleccionar fecha',
        ),
      ),
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
