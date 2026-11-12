import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TodoPriority { low, medium, high }

class TodoItem {
  final String id;
  final String title;
  final TodoPriority priority;
  final DateTime? dueDate;
  bool isDone;
  final DateTime createdAt;

  TodoItem({
    required this.id,
    required this.title,
    this.priority = TodoPriority.medium,
    this.dueDate,
    this.isDone = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority.name,
        'dueDate': dueDate?.toIso8601String(),
        'isDone': isDone,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String? ?? UniqueKey().toString(),
        title: json['title'] as String? ?? '',
        priority: TodoPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => TodoPriority.medium,
        ),
        dueDate: json['dueDate'] != null
            ? DateTime.tryParse(json['dueDate'].toString())
            : null,
        isDone: json['isDone'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// To-do list & task tracking engine.
class TodoService extends ChangeNotifier {
  TodoService._();
  static final TodoService instance = TodoService._();

  static const _storageKey = 'geny_todos_v1';
  final List<TodoItem> _items = [];
  bool _initialized = false;

  List<TodoItem> get items => List.unmodifiable(_items);
  List<TodoItem> get pendingItems =>
      List.unmodifiable(_items.where((i) => !i.isDone));
  List<TodoItem> get completedItems =>
      List.unmodifiable(_items.where((i) => i.isDone));

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.clear();
          for (final e in decoded) {
            if (e is Map) {
              _items.add(
                TodoItem.fromJson(e.map((k, v) => MapEntry('$k', v))),
              );
            }
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((i) => i.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Adds a new task to the user's to-do list.
  Future<TodoItem> addTodo(String title, {String priority = 'medium'}) {
    final p = priority.toLowerCase() == 'high'
        ? TodoPriority.high
        : (priority.toLowerCase() == 'low'
            ? TodoPriority.low
            : TodoPriority.medium);
    return addTask(title, priority: p);
  }

  Future<TodoItem> addTask(
    String title, {
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueDate,
  }) async {
    await init();
    final item = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      priority: priority,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    _items.insert(0, item);
    await _persist();
    return item;
  }

  /// Toggles task completion state.
  Future<void> toggleDone(String id) async {
    await init();
    final index = _items.indexWhere((i) => i.id == id);
    if (index >= 0) {
      _items[index].isDone = !_items[index].isDone;
      await _persist();
    }
  }

  /// Deletes a task.
  Future<void> deleteTask(String id) async {
    await init();
    _items.removeWhere((i) => i.id == id);
    await _persist();
  }

  /// Clears completed tasks.
  Future<void> clearCompleted() async {
    await init();
    _items.removeWhere((i) => i.isDone);
    await _persist();
  }

  /// Formats pending tasks for articulate voice synthesis.
  String getPendingTasksSpoken() {
    final pending = pendingItems;
    if (pending.isEmpty) {
      return 'You have no pending tasks on your to-do list. All caught up.';
    }
    final count = pending.length;
    final buffer = StringBuffer(
      'You have $count pending ${count == 1 ? 'task' : 'tasks'} on your agenda: ',
    );
    for (var i = 0; i < pending.length; i++) {
      buffer.write(pending[i].title);
      if (i < pending.length - 1) buffer.write(', ');
    }
    buffer.write('.');
    return buffer.toString();
  }
}

