import '../models/task_step.dart';

/// Detects when the agent loop is stuck (same action repeating, or the
/// screen never changing) and proposes corrective fallback actions.
class RecoveryEngine {
  static const _signatureWindow = 3;
  static const _unchangedThreshold = 3;

  final List<String> _recentSignatures = [];
  String? _lastScreenFingerprint;
  int _unchangedScreens = 0;
  int _recoveryCursor = 0;

  void reset() {
    _recentSignatures.clear();
    _lastScreenFingerprint = null;
    _unchangedScreens = 0;
    _recoveryCursor = 0;
  }

  void recordAction(TaskStep step) {
    _recentSignatures.add(step.signature);
    if (_recentSignatures.length > 10) {
      _recentSignatures.removeAt(0);
    }
  }

  /// Records a lightweight fingerprint of the latest screen dump.
  void recordScreen(String formattedDump) {
    if (formattedDump == _lastScreenFingerprint) {
      _unchangedScreens++;
    } else {
      _unchangedScreens = 0;
      _lastScreenFingerprint = formattedDump;
    }
  }

  /// The exact same action (name + params) repeated >= 3 times in a row.
  bool get isRepeatingActions {
    if (_recentSignatures.length < _signatureWindow) return false;
    final tail =
        _recentSignatures.sublist(_recentSignatures.length - _signatureWindow);
    return tail.toSet().length == 1;
  }

  bool get isScreenStuck => _unchangedScreens >= _unchangedThreshold;

  bool get shouldRecover => isRepeatingActions || isScreenStuck;

  /// Rotating recovery strategies: scroll for more content, wait for slow
  /// screens, then back out of a dead end.
  TaskStep suggestRecovery() {
    const strategies = [
      TaskStep(
        action: TaskStep.actionScroll,
        params: {'direction': 'down'},
        reasoning: 'Recovery: screen appears stuck; scrolling for new content.',
      ),
      TaskStep(
        action: TaskStep.actionWait,
        params: {'ms': 2000},
        reasoning: 'Recovery: waiting for the UI to settle.',
      ),
      TaskStep(
        action: TaskStep.actionPressBack,
        params: {},
        reasoning: 'Recovery: backing out of a possible dead end.',
      ),
    ];
    final step = strategies[_recoveryCursor % strategies.length];
    _recoveryCursor++;
    return step;
  }
}
