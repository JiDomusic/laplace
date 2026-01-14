import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/supabase_service.dart';
import '../../models/picked_file.dart';
import '../../utils/app_theme.dart';

class GaleriaScreen extends StatefulWidget {
  const GaleriaScreen({super.key});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  final SupabaseService _db = SupabaseService.instance;
  List<Map<String, dynamic>> _fotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGaleria();
  }

  Future<void> _loadGaleria() async {
    try {
      final fotos = await _db.getGaleria();
      setState(() {
        _fotos = fotos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar galeria: $e')),
        );
      }
    }
  }

  Future<void> _agregarFoto() async {
    final tituloController = TextEditingController();
    final descripcionController = TextEditingController();
    SelectedFile? selectedFile;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva Foto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo del evento *',
                    hintText: 'Ej: Acto de fin de año 2025',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripcion (opcional)',
                    hintText: 'Descripcion breve del evento',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    if (result != null && result.files.single.bytes != null) {
                      final platformFile = result.files.single;
                      setDialogState(() {
                        selectedFile = SelectedFile(
                          name: platformFile.name,
                          bytes: platformFile.bytes!,
                        );
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: selectedFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(selectedFile!.bytes, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Seleccionar imagen'),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedFile != null && tituloController.text.isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Subir'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedFile != null && tituloController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final url = await _db.uploadFotoGaleria(tituloController.text, selectedFile!);
        await _db.insertFotoGaleria(
          titulo: tituloController.text,
          url: url,
          descripcion: descripcionController.text.isNotEmpty ? descripcionController.text : null,
        );
        await _loadGaleria();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto agregada correctamente')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir foto: $e')),
          );
        }
      }
    }
  }

  Future<void> _eliminarFoto(Map<String, dynamic> foto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: Text('Seguro que deseas eliminar "${foto['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.deleteFotoGaleria(foto['id'].toString());
        await _loadGaleria();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto eliminada')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  void _verFoto(Map<String, dynamic> foto) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(foto['titulo'] ?? 'Foto'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Image.network(
              foto['url_imagen'],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            ),
            if (foto['descripcion'] != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(foto['descripcion']),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeria de Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadGaleria();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarFoto,
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No hay fotos en la galeria',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _agregarFoto,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar primera foto'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGaleria,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: _fotos.length,
                    itemBuilder: (context, index) {
                      final foto = _fotos[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _verFoto(foto),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                foto['url_imagen'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 48),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.7),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Text(
                                    foto['titulo'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: PopupMenuButton<String>(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'eliminar') {
                                      _eliminarFoto(foto);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: AppTheme.dangerColor),
                                          SizedBox(width: 8),
                                          Text('Eliminar'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
