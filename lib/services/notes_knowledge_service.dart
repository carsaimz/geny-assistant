import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteEntry {
  final String id;
  String title;
  String content;
  List<String> tags;
  bool isPinned;
  DateTime updatedAt;
  final DateTime createdAt;

  NoteEntry({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.isPinned = false,
    required this.updatedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'isPinned': isPinned,
        'updatedAt': updatedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteEntry.fromJson(Map<String, dynamic> json) => NoteEntry(
        id: json['id'] as String? ?? UniqueKey().toString(),
        title: json['title'] as String? ?? 'Untitled Note',
        content: json['content'] as String? ?? '',
        tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
        isPinned: json['isPinned'] as bool? ?? false,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Note-taking & searchable personal knowledge base.
class NotesKnowledgeService extends ChangeNotifier {
  NotesKnowledgeService._();
  static final NotesKnowledgeService instance = NotesKnowledgeService._();

  static const _storageKey = 'geny_notes_knowledge_v1';
  final List<NoteEntry> _notes = [];
  bool _initialized = false;

  List<NoteEntry> get notes => List.unmodifiable(_notes);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _notes.clear();
          for (final e in decoded) {
            if (e is Map) {
              _notes.add(
                NoteEntry.fromJson(e.map((k, v) => MapEntry('$k', v))),
              );
            }
          }
        }
      } catch (_) {}
    }
    _sortNotes();
    notifyListeners();
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_notes.map((n) => n.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Adds a new note to the knowledge base.
  Future<NoteEntry> addNote({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPinned = false,
  }) async {
    await init();
    final note = NoteEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Note ${DateTime.now().month}/${DateTime.now().day}' : title.trim(),
      content: content.trim(),
      tags: tags,
      isPinned: isPinned,
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _notes.insert(0, note);
    _sortNotes();
    await _persist();
    return note;
  }

  /// Updates an existing note.
  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPinned,
  }) async {
    await init();
    final index = _notes.indexWhere((n) => n.id == id);
    if (index >= 0) {
      final old = _notes[index];
      _notes[index] = NoteEntry(
        id: old.id,
        title: title?.trim() ?? old.title,
        content: content?.trim() ?? old.content,
        tags: tags ?? old.tags,
        isPinned: isPinned ?? old.isPinned,
        updatedAt: DateTime.now(),
        createdAt: old.createdAt,
      );
      _sortNotes();
      await _persist();
    }
  }

  /// Deletes a note.
  Future<void> deleteNote(String id) async {
    await init();
    _notes.removeWhere((n) => n.id == id);
    await _persist();
  }

  /// Searches notes and knowledge entries by query keywords.
  List<NoteEntry> searchNotes(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return notes;
    return _notes.where((n) {
      final inTitle = n.title.toLowerCase().contains(q);
      final inContent = n.content.toLowerCase().contains(q);
      final inTags = n.tags.any((t) => t.toLowerCase().contains(q));
      return inTitle || inContent || inTags;
    }).toList();
  }

  /// Formats note search result for voice synthesis.
  String searchNotesSpoken(String query) {
    final hits = searchNotes(query);
    if (hits.isEmpty) {
      return 'I searched your personal knowledge base, but found no notes regarding "$query".';
    }
    final top = hits.first;
    return 'From your notes on ${top.title}: ${top.content}';
  }
}

