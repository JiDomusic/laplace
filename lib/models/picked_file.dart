import 'dart:typed_data';

/// Modelo multiplataforma para archivos seleccionados
/// Funciona tanto en web (bytes) como en movil (path)
class SelectedFile {
  final String name;
  final Uint8List bytes;
  final String? path;

  SelectedFile({
    required this.name,
    required this.bytes,
    this.path,
  });

  String get extension => name.split('.').last.toLowerCase();
}
