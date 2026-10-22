
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/main.dart';

void main() {
  test('TaskFlow membuat model tugas dengan benar', () {
    const task = Task(
      title: 'Belajar Flutter',
      description: 'Mengerjakan UTS',
      dueDate: '2026-10-21',
    );

    expect(task.title, 'Belajar Flutter');
    expect(task.description, 'Mengerjakan UTS');
    expect(task.isDone, false);
  });

  test('Task dapat dikonversi ke dan dari Map', () {
    const task = Task(
      id: 1,
      title: 'Tes SQLite',
      description: 'Tes penyimpanan',
      dueDate: '2026-10-21',
      isDone: true,
    );

    final restored = Task.fromMap(task.toMap());

    expect(restored.id, 1);
    expect(restored.title, 'Tes SQLite');
    expect(restored.isDone, true);
  });
}
