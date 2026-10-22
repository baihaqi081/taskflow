
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'export_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chrome membutuhkan factory SQLite khusus Web.
  // Android tetap menggunakan factory bawaan sqflite.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  runApp(const TaskFlowApp());
}

class Task {
  final int? id;
  final String title;
  final String description;
  final String dueDate;
  final bool isDone;

  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.isDone = false,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'isDone': isDone ? 1 : 0,
      };

  factory Task.fromMap(Map<String, Object?> map) => Task(
        id: map['id'] as int,
        title: map['title'] as String,
        description: map['description'] as String,
        dueDate: map['dueDate'] as String,
        isDone: (map['isDone'] as int) == 1,
      );
}

class TaskDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    // Web memakai nama database; Android memakai folder database perangkat.
    final String dbPath;
    if (kIsWeb) {
      dbPath = 'taskflow_web.db';
    } else {
      final dbDir = await getDatabasesPath();
      dbPath = p.join(dbDir, 'taskflow.db');
    }

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            isDone INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<List<Task>> getTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'id DESC');
    return rows.map(Task.fromMap).toList();
  }

  static Future<void> save(Task task) async {
    final db = await database;
    final data = task.toMap()..remove('id');

    if (task.id == null) {
      await db.insert('tasks', data);
    } else {
      await db.update(
        'tasks',
        data,
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
  }

  static Future<void> delete(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}

class TaskFlowApp extends StatefulWidget {
  const TaskFlowApp({super.key});

  @override
  State<TaskFlowApp> createState() => _TaskFlowAppState();
}

class _TaskFlowAppState extends State<TaskFlowApp> {
  ThemeMode themeMode = ThemeMode.light;
  String userName = 'Pengguna';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      userName = prefs.getString('userName') ?? 'Pengguna';
      themeMode =
          (prefs.getBool('darkMode') ?? false)
              ? ThemeMode.dark
              : ThemeMode.light;
    });
  }

  Future<void> _savePreferences(String name, bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setBool('darkMode', dark);

    if (!mounted) return;
    setState(() {
      userName = name;
      themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5267D9);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TaskFlow',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F7FB),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: TaskHomePage(
        userName: userName,
        darkMode: themeMode == ThemeMode.dark,
        onPreferencesChanged: _savePreferences,
      ),
    );
  }
}

class TaskHomePage extends StatefulWidget {
  final String userName;
  final bool darkMode;
  final Future<void> Function(String, bool) onPreferencesChanged;

  const TaskHomePage({
    super.key,
    required this.userName,
    required this.darkMode,
    required this.onPreferencesChanged,
  });

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  List<Task> tasks = [];
  bool loading = true;
  String filter = 'Semua';
  String? message;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      loading = true;
      message = null;
    });

    try {
      final result = await TaskDatabase.getTasks();
      if (!mounted) return;
      setState(() {
        tasks = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        message = 'Gagal membaca data: $e';
      });
    }
  }

  List<Task> get visibleTasks {
    if (filter == 'Aktif') {
      return tasks.where((t) => !t.isDone).toList();
    }
    if (filter == 'Selesai') {
      return tasks.where((t) => t.isDone).toList();
    }
    return tasks;
  }

  Future<void> _openForm([Task? task]) async {
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController =
        TextEditingController(text: task?.description ?? '');
    DateTime selectedDate =
        DateTime.tryParse(task?.dueDate ?? '') ?? DateTime.now();

    final result = await showDialog<Task>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task == null ? 'Tambah Tugas' : 'Edit Tugas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Judul tugas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/'
                    '${selectedDate.month.toString().padLeft(2, '0')}/'
                    '${selectedDate.year}',
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(
                  dialogContext,
                  Task(
                    id: task?.id,
                    title: title,
                    description: descController.text.trim(),
                    dueDate: selectedDate.toIso8601String().split('T').first,
                    isDone: task?.isDone ?? false,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descController.dispose();

    if (result == null) return;

    try {
      await TaskDatabase.save(result);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tugas berhasil disimpan')),
        );
      }
    } catch (e) {
      _showError('Gagal menyimpan tugas: $e');
    }
  }

  Future<void> _toggleTask(Task task, bool value) async {
    try {
      await TaskDatabase.save(
        Task(
          id: task.id,
          title: task.title,
          description: task.description,
          dueDate: task.dueDate,
          isDone: value,
        ),
      );
      await _loadTasks();
    } catch (e) {
      _showError('Gagal mengubah status tugas: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas?'),
        content: Text('Tugas "${task.title}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TaskDatabase.delete(task.id!);
      await _loadTasks();
    } catch (e) {
      _showError('Gagal menghapus tugas: $e');
    }
  }

  Future<void> _exportJson() async {
    try {
      final data = tasks.map((task) => task.toMap()).toList();
      final jsonText = const JsonEncoder.withIndent('  ').convert(data);
      final location = await saveJsonExport(jsonText);

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ekspor berhasil'),
          content: SelectableText(location),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Gagal mengekspor data: $e');
    }
  }

  Future<void> _openSettings() async {
    final nameController = TextEditingController(text: widget.userName);
    bool dark = widget.darkMode;

    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Pengaturan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama pengguna',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode gelap'),
                value: dark,
                onChanged: (value) => setDialogState(() => dark = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  (
                    nameController.text.trim().isEmpty
                        ? 'Pengguna'
                        : nameController.text.trim(),
                    dark,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();

    if (result != null) {
      await widget.onPreferencesChanged(result.$1, result.$2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan berhasil disimpan')),
        );
      }
    }
  }

  void _showError(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.isDone).length;
    final active = tasks.length - completed;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TaskFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Ekspor JSON',
            onPressed: _exportJson,
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah tugas'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(
              'Halo, ${widget.userName}!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Rencanakan hari, selesaikan satu per satu.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Progres tugas'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text('$completed dari ${tasks.length} tugas'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text('$active tugas masih perlu diselesaikan'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Semua tugas',
                    value: tasks.length,
                    icon: Icons.list_alt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'Selesai',
                    value: completed,
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Daftar tugas',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Semua', 'Aktif', 'Selesai'].map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: filter == item,
                      onSelected: (_) => setState(() => filter = item),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (message != null)
              Center(child: Text(message!))
            else if (visibleTasks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(Icons.event_note, size: 48),
                      const SizedBox(height: 12),
                      const Text('Belum ada tugas di bagian ini.'),
                      const SizedBox(height: 8),
                      Text(
                        'Tekan tombol Tambah tugas untuk memulai.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...visibleTasks.map(
                (task) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: task.isDone,
                          onChanged: (value) =>
                              _toggleTask(task, value ?? false),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: task.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(task.description),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      task.dueDate,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _openForm(task);
                            if (value == 'delete') _deleteTask(task);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 25),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}
