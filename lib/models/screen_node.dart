/// A flattened accessibility node coming from the native
/// `AgentAccessibilityService.dumpScreen()` call.
class ScreenNode {
  final int index;
  final String text;
  final String contentDescription;
  final String className;
  final String viewId;
  final bool isClickable;
  final bool isEditable;
  final bool isScrollable;
  final bool isCheckable;
  final bool isEnabled;
  final int left;
  final int top;
  final int right;
  final int bottom;
  final int centerX;
  final int centerY;

  const ScreenNode({
    required this.index,
    required this.text,
    required this.contentDescription,
    required this.className,
    required this.viewId,
    required this.isClickable,
    required this.isEditable,
    required this.isScrollable,
    required this.isCheckable,
    required this.isEnabled,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.centerX,
    required this.centerY,
  });

  factory ScreenNode.fromMap(Map<dynamic, dynamic> map) {
    int asInt(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
    bool asBool(Object? v) => v == true || v == 'true';
    String asStr(Object? v) => v?.toString() ?? '';
    return ScreenNode(
      index: asInt(map['index']),
      text: asStr(map['text']),
      contentDescription: asStr(map['contentDescription']),
      className: asStr(map['className']),
      viewId: asStr(map['viewId']),
      isClickable: asBool(map['isClickable']),
      isEditable: asBool(map['isEditable']),
      isScrollable: asBool(map['isScrollable']),
      isCheckable: asBool(map['isCheckable']),
      isEnabled: asBool(map['isEnabled']),
      left: asInt(map['left']),
      top: asInt(map['top']),
      right: asInt(map['right']),
      bottom: asInt(map['bottom']),
      centerX: asInt(map['centerX']),
      centerY: asInt(map['centerY']),
    );
  }

  /// Best human-readable label for this node.
  String get label => text.isNotEmpty ? text : contentDescription;

  bool get hasLabel => label.isNotEmpty;

  bool get isInteractive =>
      isClickable || isEditable || isScrollable || isCheckable;

  /// Short class name without the package prefix, e.g. `EditText`.
  String get shortClass {
    if (className.isEmpty) return 'View';
    final dot = className.lastIndexOf('.');
    return dot >= 0 ? className.substring(dot + 1) : className;
  }

  /// True when the node matches [query] by exact label, case-insensitive
  /// contains on text/contentDescription, or view-id tail.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return false;
    if (text.toLowerCase() == q || contentDescription.toLowerCase() == q) {
      return true;
    }
    if (text.toLowerCase().contains(q) ||
        contentDescription.toLowerCase().contains(q)) {
      return true;
    }
    if (viewId.isNotEmpty && viewId.toLowerCase().endsWith(q)) return true;
    return false;
  }

  @override
  String toString() => 'ScreenNode(#$index "$label" $shortClass @$centerX,$centerY)';
}
