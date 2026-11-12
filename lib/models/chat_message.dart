import 'package:uuid/uuid.dart';

/// Role of an entry in the on-screen execution transcript.
enum ChatRole { user, agent, system, error }

/// A single line/bubble in the task transcript shown on the home screen
/// and in the overlay panel.
class ChatMessage {
  static const _uuid = Uuid();

  final String id;
  final ChatRole role;
  String text;
  final DateTime time;

  /// Step number (1-based) when this message belongs to the agent loop.
  final int? step;

  /// Render with a Markdown body (used for agent reasoning summaries).
  final bool markdown;

  ChatMessage({
    String? id,
    required this.role,
    required this.text,
    DateTime? time,
    this.step,
    this.markdown = false,
  })  : id = id ?? _uuid.v4(),
        time = time ?? DateTime.now();

  factory ChatMessage.user(String text) =>
      ChatMessage(role: ChatRole.user, text: text);

  factory ChatMessage.agent(String text, {int? step}) =>
      ChatMessage(role: ChatRole.agent, text: text, step: step, markdown: true);

  factory ChatMessage.system(String text) =>
      ChatMessage(role: ChatRole.system, text: text);

  factory ChatMessage.error(String text) =>
      ChatMessage(role: ChatRole.error, text: text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'time': time.toIso8601String(),
        'step': step,
        'markdown': markdown,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id']?.toString(),
        role: ChatRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => ChatRole.system,
        ),
        text: json['text']?.toString() ?? '',
        time: DateTime.tryParse(json['time']?.toString() ?? ''),
        step: json['step'] is int ? json['step'] as int : null,
        markdown: json['markdown'] == true,
      );
}
