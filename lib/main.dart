import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initializeFirebase});

  final Future<void> Function()? initializeFirebase;

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.web : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda Firestore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3157A4),
          surface: const Color(0xFFF7F8FC),
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: FutureBuilder<void>(
        future: (initializeFirebase ?? _initializeFirebase)(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _FirebaseSetupError(error: snapshot.error);
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const StoreDashboard();
        },
      ),
    );
  }
}

class _FirebaseSetupError extends StatelessWidget {
  const _FirebaseSetupError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'No se pudo iniciar Firebase',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configura Firebase para esta plataforma y vuelve a iniciar '
                  'la aplicación. Consulta los pasos en README.md.',
                  textAlign: TextAlign.center,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  SelectableText(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StoreDashboard extends StatefulWidget {
  const StoreDashboard({super.key});

  @override
  State<StoreDashboard> createState() => _StoreDashboardState();
}

class _StoreDashboardState extends State<StoreDashboard> {
  int _selectedIndex = 0;

  static const _collections = <CollectionConfig>[
    CollectionConfig(
      name: 'clientes',
      title: 'Clientes',
      singular: 'cliente',
      icon: Icons.people_alt_outlined,
      fields: [
        FieldConfig('nombre', 'Nombre', FieldType.text),
        FieldConfig('documento', 'Documento', FieldType.text),
        FieldConfig('telefono', 'Teléfono', FieldType.phone),
        FieldConfig('correo', 'Correo electrónico', FieldType.email),
        FieldConfig('estado', 'Estado', FieldType.status),
      ],
    ),
    CollectionConfig(
      name: 'categorias',
      title: 'Categorías',
      singular: 'categoría',
      icon: Icons.category_outlined,
      fields: [
        FieldConfig('nombre', 'Nombre', FieldType.text),
        FieldConfig('descripcion', 'Descripción', FieldType.text),
        FieldConfig('estado', 'Estado', FieldType.status),
      ],
    ),
    CollectionConfig(
      name: 'productos',
      title: 'Productos',
      singular: 'producto',
      icon: Icons.inventory_2_outlined,
      fields: [
        FieldConfig('nombre', 'Nombre', FieldType.text),
        FieldConfig('categoriaId', 'Categoría', FieldType.category),
        FieldConfig('precio', 'Precio', FieldType.decimal),
        FieldConfig('stock', 'Stock', FieldType.integer),
        FieldConfig('estado', 'Estado', FieldType.status),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final config = _collections[_selectedIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de ${config.title.toLowerCase()}'),
        centerTitle: false,
      ),
      body: CollectionPage(config: config),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CollectionPage.showEditor(context, config: config),
        icon: const Icon(Icons.add),
        label: Text('Agregar ${config.singular}'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final item in _collections)
            NavigationDestination(icon: Icon(item.icon), label: item.title),
        ],
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  const CollectionPage({required this.config, super.key});

  final CollectionConfig config;

  static Future<void> showEditor(
    BuildContext context, {
    required CollectionConfig config,
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final formData = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _EntityFormDialog(config: config, initialData: document?.data()),
    );
    if (formData == null || !context.mounted) return;

    try {
      final collection = FirebaseFirestore.instance.collection(config.name);
      if (document == null) {
        await collection.add(formData);
      } else {
        await collection.doc(document.id).update(formData);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              document == null
                  ? '${config.singular} creado correctamente.'
                  : '${config.singular} actualizado correctamente.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar: ${error.message ?? error.code}'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${config.singular}'),
        content: const Text(
          'Esta acción no se puede deshacer. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      if (config.name == 'categorias') {
        final products = await FirebaseFirestore.instance
            .collection('productos')
            .where('categoriaId', isEqualTo: document.id)
            .limit(1)
            .get();
        if (products.docs.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No puedes eliminar esta categoría porque tiene productos asociados.',
                ),
              ),
            );
          }
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection(config.name)
          .doc(document.id)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${config.singular} eliminado correctamente.'),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo eliminar: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(config.name)
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron consultar ${config.title.toLowerCase()}.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data?.docs ?? [];
        if (documents.isEmpty) {
          return _EmptyCollection(config: config);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: documents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = documents[index];
            final data = document.data();
            final estado = data['estado'] as String? ?? 'Sin estado';
            final details = config.fields
                .where(
                  (field) => field.key != 'nombre' && field.key != 'estado',
                )
                .map((field) => '${field.label}: ${data[field.key] ?? '—'}')
                .join('  ·  ');
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                title: Text(
                  data['nombre'] as String? ?? 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (details.isNotEmpty) details,
                      'Estado: $estado',
                    ].join('\n'),
                  ),
                ),
                isThreeLine: details.isNotEmpty,
                trailing: PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  onSelected: (value) {
                    if (value == 'edit') {
                      showEditor(context, config: config, document: document);
                    } else if (value == 'delete') {
                      _deleteDocument(context, document);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.config});

  final CollectionConfig config;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.icon,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no hay ${config.title.toLowerCase()}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Usa “Agregar ${config.singular}” para crear el primer registro.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntityFormDialog extends StatefulWidget {
  const _EntityFormDialog({required this.config, required this.initialData});

  final CollectionConfig config;
  final Map<String, dynamic>? initialData;

  @override
  State<_EntityFormDialog> createState() => _EntityFormDialogState();
}

class _EntityFormDialogState extends State<_EntityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  String _estado = 'Activo';
  String? _categoriaId;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? const <String, dynamic>{};
    _controllers = {
      for (final field in widget.config.fields)
        if (field.type != FieldType.status && field.type != FieldType.category)
          field.key: TextEditingController(
            text: data[field.key]?.toString() ?? '',
          ),
    };
    _estado = data['estado'] as String? ?? 'Activo';
    _categoriaId = data['categoriaId'] as String?;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateField(FieldConfig field, String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty) return 'Este campo es obligatorio.';
    if (field.type == FieldType.email &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Ingresa un correo válido.';
    }
    if (field.type == FieldType.decimal) {
      final number = double.tryParse(value.replaceAll(',', '.'));
      if (number == null || !number.isFinite || number < 0) {
        return 'Ingresa un precio válido (mayor o igual a 0).';
      }
    }
    if (field.type == FieldType.integer) {
      final number = int.tryParse(value);
      if (number == null || number < 0) {
        return 'Ingresa un número entero mayor o igual a 0.';
      }
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final values = <String, dynamic>{};
    for (final field in widget.config.fields) {
      switch (field.type) {
        case FieldType.status:
          values[field.key] = _estado;
        case FieldType.category:
          if (_categoriaId == null) return;
          values[field.key] = _categoriaId;
        case FieldType.decimal:
          values[field.key] = double.parse(
            _controllers[field.key]!.text.trim().replaceAll(',', '.'),
          );
        case FieldType.integer:
          values[field.key] = int.parse(_controllers[field.key]!.text.trim());
        case FieldType.text:
        case FieldType.email:
        case FieldType.phone:
          values[field.key] = _controllers[field.key]!.text.trim();
      }
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;
    return AlertDialog(
      title: Text(
        '${isEditing ? 'Editar' : 'Agregar'} ${widget.config.singular}',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in widget.config.fields) ...[
                  _buildField(field),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _buildField(FieldConfig field) {
    if (field.type == FieldType.status) {
      return DropdownButtonFormField<String>(
        initialValue: _estado,
        decoration: InputDecoration(labelText: field.label),
        items: const [
          DropdownMenuItem(value: 'Activo', child: Text('Activo')),
          DropdownMenuItem(value: 'Inactivo', child: Text('Inactivo')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _estado = value);
        },
      );
    }
    if (field.type == FieldType.category) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('categorias')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'No se pudieron cargar las categorías: ${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          final categories = snapshot.data?.docs ?? [];
          if (categories.isEmpty) {
            return const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Crea primero una categoría para poder asociar el producto.',
              ),
            );
          }
          final validSelection = categories.any(
            (doc) => doc.id == _categoriaId,
          );
          return DropdownButtonFormField<String>(
            initialValue: validSelection ? _categoriaId : null,
            decoration: InputDecoration(labelText: field.label),
            validator: (value) =>
                value == null ? 'Selecciona una categoría.' : null,
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(
                    category.data()['nombre'] as String? ?? 'Sin nombre',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _categoriaId = value),
          );
        },
      );
    }

    final keyboardType = switch (field.type) {
      FieldType.email => TextInputType.emailAddress,
      FieldType.phone => TextInputType.phone,
      FieldType.decimal => const TextInputType.numberWithOptions(decimal: true),
      FieldType.integer => TextInputType.number,
      _ => TextInputType.text,
    };
    return TextFormField(
      controller: _controllers[field.key],
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: field.label),
      validator: (value) => _validateField(field, value),
    );
  }
}

enum FieldType { text, email, phone, decimal, integer, status, category }

class FieldConfig {
  const FieldConfig(this.key, this.label, this.type);

  final String key;
  final String label;
  final FieldType type;
}

class CollectionConfig {
  const CollectionConfig({
    required this.name,
    required this.title,
    required this.singular,
    required this.icon,
    required this.fields,
  });

  final String name;
  final String title;
  final String singular;
  final IconData icon;
  final List<FieldConfig> fields;
}
