import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final SupabaseService _db = SupabaseService.instance;
  final AuthService _auth = AuthService.instance;
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      final admins = await _db.getAllAdmins();
      // Ocultar superadmin para usuarios que no sean superadmin
      _admins = admins.where((a) {
        if (_auth.isSuperAdmin) return true;
        return (a['rol'] ?? 'admin') != 'superadmin';
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Usuarios'),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), tooltip: 'Agregar usuario', onPressed: _agregarAdmin),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAdmins),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? const Center(child: Text('No hay usuarios registrados'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _admins.length + 1, // +1 for change password card
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildCambiarPasswordCard();
                    return _buildAdminCard(_admins[index - 1]);
                  },
                ),
    );
  }

  Widget _buildCambiarPasswordCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppTheme.primaryColor,
      child: ListTile(
        leading: const Icon(Icons.lock, color: Colors.white),
        title: const Text('Cambiar mi contraseña', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('Sesion: ${_auth.userEmail}', style: const TextStyle(color: Colors.white70)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: _cambiarMiPassword,
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final esYo = admin['email'] == _auth.userEmail;
    final rol = admin['rol'] ?? 'admin';
    final activo = admin['activo'] ?? true;
    final id = admin['id']?.toString() ?? '';

    Color rolColor;
    switch (rol) {
      case 'superadmin':
        rolColor = Colors.purple;
        break;
      case 'secretaria':
        rolColor = Colors.teal;
        break;
      default:
        rolColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: esYo ? AppTheme.accentColor : AppTheme.primaryColor,
          child: Text(
            (admin['nombre'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(admin['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (esYo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.accentColor, borderRadius: BorderRadius.circular(4)),
                child: const Text('TU', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(child: Text(admin['email'] ?? '')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: rolColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(rol, style: TextStyle(fontSize: 11, color: rolColor, fontWeight: FontWeight.bold)),
            ),
            if (!activo) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Text('INACTIVO', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'editar':
                _editarAdmin(admin);
                break;
              case 'password':
                _cambiarPasswordAdmin(admin);
                break;
              case 'toggleActivo':
                _toggleActivo(id, activo);
                break;
              case 'eliminar':
                if (!esYo) _confirmarEliminar(id, admin['nombre'] ?? '');
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
            const PopupMenuItem(value: 'password', child: ListTile(leading: Icon(Icons.lock), title: Text('Cambiar contraseña'))),
            PopupMenuItem(
              value: 'toggleActivo',
              child: ListTile(
                leading: Icon(activo ? Icons.block : Icons.check_circle),
                title: Text(activo ? 'Desactivar' : 'Activar'),
              ),
            ),
            if (!esYo)
              const PopupMenuItem(
                value: 'eliminar',
                child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Eliminar', style: TextStyle(color: Colors.red))),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarAdmin() async {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String rol = 'admin';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    const DropdownMenuItem(value: 'secretaria', child: Text('Secretaria')),
                    if (_auth.isSuperAdmin) const DropdownMenuItem(value: 'superadmin', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => rol = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
          ],
        ),
      ),
    );

    if (confirmar == true) {
      if (nombreCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todos los campos son obligatorios'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      try {
        await _db.createAdmin(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text.trim(),
          nombre: nombreCtrl.text.trim(),
          rol: rol,
        );
        await _loadAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario creado correctamente'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear usuario: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editarAdmin(Map<String, dynamic> admin) async {
    final nombreCtrl = TextEditingController(text: admin['nombre'] ?? '');
    final emailCtrl = TextEditingController(text: admin['email'] ?? '');
    String rol = admin['rol'] ?? 'admin';
    final id = admin['id']?.toString() ?? '';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ['admin', 'secretaria', 'superadmin'].contains(rol) ? rol : 'admin',
                  decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    const DropdownMenuItem(value: 'secretaria', child: Text('Secretaria')),
                    if (_auth.isSuperAdmin) const DropdownMenuItem(value: 'superadmin', child: Text('Super Admin')),
                  ],
                  onChanged: (v) => setDialogState(() => rol = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (confirmar == true) {
      try {
        await _db.updateAdmin(id, nombre: nombreCtrl.text.trim(), email: emailCtrl.text.trim(), rol: rol);
        await _loadAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario actualizado'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _cambiarMiPassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar mi contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentCtrl, decoration: const InputDecoration(labelText: 'Contraseña actual', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña', border: OutlineInputBorder()), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cambiar')),
        ],
      ),
    );

    if (confirmar == true) {
      if (newCtrl.text != confirmCtrl.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      if (newCtrl.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La contraseña no puede estar vacia'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      final ok = await _auth.changePassword(currentCtrl.text, newCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Contraseña cambiada correctamente' : _auth.error ?? 'Error al cambiar contraseña'),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cambiarPasswordAdmin(Map<String, dynamic> admin) async {
    final newCtrl = TextEditingController();
    final id = admin['id']?.toString() ?? '';
    final email = admin['email']?.toString();
    bool obscure = true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: Text('Cambiar contraseña: ${admin['nombre']}'),
        content: TextField(
          controller: newCtrl,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setDialogState(() => obscure = !obscure),
            ),
          ),
          obscureText: obscure,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cambiar')),
        ],
      )),
    );

    if (confirmar == true && newCtrl.text.trim().isNotEmpty) {
      try {
        await _db.changeAdminPassword(id, newCtrl.text.trim(), email: email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _toggleActivo(String id, bool activo) async {
    try {
      await _db.updateAdmin(id, activo: !activo);
      await _loadAdmins();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmarEliminar(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Seguro que desea eliminar a "$nombre"? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _db.deleteAdmin(id);
        await _loadAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario eliminado'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
