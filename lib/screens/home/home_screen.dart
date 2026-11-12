import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intl/intl.dart';

import '../../models/task_history_entry.dart';
import '../../services/calendar_reminder_service.dart';
import '../../services/geny_service.dart';
import '../../services/notes_knowledge_service.dart';
import '../../services/proactive_agent_service.dart';
import '../../services/screen_automation_service.dart' hide Size;
import '../../services/settings_service.dart';
import '../../services/task_executor.dart';
import '../../services/todo_service.dart';
import '../../services/voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brain_dump_dialog.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/geny_hud_widget.dart';
import '../../widgets/liquid_glass_mode_switcher.dart';
import '../../widgets/status_chip.dart';
import '../sessions/session_detail_screen.dart';
import '../settings/settings_screen.dart';

/// Main screen: live task transcript, task input with voice, overlay toggle.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _executor = TaskExecutor.instance;
  final _automation = ScreenAutomationService.instance;
  final _voice = VoiceService.instance;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  bool _serviceEnabled = false;
  bool _overlayActive = false;
  bool _listening = false;
  AppMode _mode = AppMode.agent;

  /// True while either an agent task or a chat reply is in flight.
  bool get _busy => _executor.isBusy || _executor.isChatBusy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _executor.addListener(_onExecutorUpdate);
    _mode = SettingsService.instance.appMode;

    // Connect Google Assistant style wake-word trigger to auto-switch into GENY HUD
    GenyService.instance.onWakeWordTriggered = () {
      if (mounted && _mode != AppMode.geny) {
        setState(() => _mode = AppMode.geny);
        SettingsService.instance.setAppMode(AppMode.geny);
        GenyService.instance.speakGreeting(force: true);
      }
    };

    if (_mode == AppMode.geny) {
      GenyService.instance.onEnterGenyMode();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GenyService.instance.speakGreeting();
      });
    }
    if (SettingsService.instance.genyAlwaysOn) {
      GenyService.instance.ensureAlwaysOnRunning();
    }
    _voice.listeningNotifier.addListener(_onVoiceListeningChanged);
    ProactiveAgentService.instance.addListener(_onProactiveUpdate);
    ProactiveAgentService.instance.evaluateProactiveNeeds();
    _refreshStates();
  }

  void _onVoiceListeningChanged() {
    if (mounted && _listening != _voice.listeningNotifier.value) {
      setState(() => _listening = _voice.listeningNotifier.value);
    }
  }

  @override
  void dispose() {
    _voice.listeningNotifier.removeListener(_onVoiceListeningChanged);
    ProactiveAgentService.instance.removeListener(_onProactiveUpdate);
    GenyService.instance.onWakeWordTriggered = null;
    if (!SettingsService.instance.genyAlwaysOn) {
      GenyService.instance.onExitGenyMode();
    }
    WidgetsBinding.instance.removeObserver(this);
    _executor.removeListener(_onExecutorUpdate);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStates();
  }

  Future<void> _refreshStates() async {
    final enabled = await _automation.isServiceEnabled();
    var overlay = false;
    try {
      overlay = await FlutterOverlayWindow.isActive();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _serviceEnabled = enabled;
        _overlayActive = overlay;
      });
    }
  }

  void _onExecutorUpdate() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onProactiveUpdate() {
    if (mounted) setState(() {});
  }

  void _submit(String text) {
    final goal = text.trim();
    if (goal.isEmpty || _busy) return;
    _inputController.clear();
    if (_mode == AppMode.agent) {
      _executor.executeTask(goal);
    } else if (_mode == AppMode.chat) {
      _executor.sendChatMessage(goal);
    } else {
      GenyService.instance.processCommand(goal);
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _voice.stopListening();
      setState(() => _listening = false);
      return;
    }
    final started = await _voice.startListening(
      continuous: false,
      onResult: (words, isFinal, candidates) {
        if (!mounted) return;
        setState(() {
          _inputController.text = words;
          if (isFinal) _listening = false;
        });
      },
    );
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition unavailable — check microphone permission.',
          ),
        ),
      );
    }
    setState(() => _listening = started);
  }

  Future<void> _toggleOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      } else {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (!granted) {
          final ok = await FlutterOverlayWindow.requestPermission() ?? false;
          if (!ok) return;
        }
        await FlutterOverlayWindow.showOverlay(
          height: 120,
          width: 120,
          alignment: OverlayAlignment.centerRight,
          flag: OverlayFlag.defaultFlag,
          overlayTitle: 'Geny',
          overlayContent: 'Agent bubble active',
          enableDrag: true,
          positionGravity: PositionGravity.auto,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Overlay error: $e')));
      }
    }
    await _refreshStates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGeny = _mode == AppMode.geny;

    return LiquidGlassScaffold(
      isGeny: isGeny,
      drawer: _sessionsDrawer(theme),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme:
            isGeny ? const IconThemeData(color: Color(0xFF00E5FF)) : null,
        title: Row(
          children: [
            Text(
              isGeny ? 'GENY' : 'Geny',
              style: isGeny
                  ? const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.8,
                      fontFamily: 'monospace',
                    )
                  : const TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
            ),
            const SizedBox(width: 10),
            ServiceStatusDot(enabled: _serviceEnabled),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _overlayActive
                ? 'Hide floating bubble'
                : 'Show floating bubble',
            onPressed: _toggleOverlay,
            icon: Icon(
              _overlayActive ? Icons.bubble_chart : Icons.bubble_chart_outlined,
              color: isGeny ? const Color(0xFF00E5FF) : null,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined,
                color: isGeny ? const Color(0xFF00E5FF) : null),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          _modeSwitcher(theme),
          if (!_serviceEnabled &&
              (_mode == AppMode.agent || _mode == AppMode.geny))
            _serviceWarning(theme),
          if (_mode != AppMode.geny &&
              ProactiveAgentService.instance.currentSuggestion != null)
            _agentProactiveBanner(theme),
          Expanded(
            child: _mode == AppMode.geny
                ? const GenyHudWidget()
                : Column(
                    children: [
                      if (_executor.isBusy) _activeTaskBar(theme),
                      Expanded(child: _transcript(theme)),
                      _inputBar(theme),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Sessions sidebar (navigation drawer)
  // ------------------------------------------------------------------

  Widget _sessionsDrawer(ThemeData theme) {
    final entries = _executor.historyEntries;
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xEE090E17) : const Color(0xEEFFFFFF),
      elevation: 0,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geny',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chat sessions & task history',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_executor.isBusy)
              ListTile(
                dense: true,
                leading: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                title: Text(
                  _executor.currentGoal ?? 'Running task…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Live session in progress',
                  style: TextStyle(fontSize: 11),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text(
                'New chat',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Clear the live transcript',
                style: TextStyle(fontSize: 11),
              ),
              enabled: !_executor.isBusy,
              onTap: () {
                Navigator.of(context).pop();
                _executor.clearTranscript();
              },
            ),
            const Divider(indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'PRODUCTIVITY SUITE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Tasks & To-Do', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${TodoService.instance.pendingItems.length} pending items',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showTodosSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendar & Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${CalendarReminderService.instance.items.length} scheduled events',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showCalendarSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Notes & Knowledge Base', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${NotesKnowledgeService.instance.notes.length} notes stored',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showNotesSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.alt_route_rounded, color: Color(0xFF00E5FF)),
              title: const Text('Multi-Task Decoupler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Chaotic Brain Dump parallel engine',
                style: TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.65),
                  builder: (_) => const BrainDumpDialog(),
                );
              },
            ),
            const Divider(indent: 12, endIndent: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text(
                'RECENT SESSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Text(
                  'No saved sessions yet.\nRun a task and it will appear here.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            for (final entry in entries) _sessionTile(theme, entry),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(ThemeData theme, TaskHistoryEntry entry) {
    final (icon, color) = switch (entry.status) {
      TaskStatus.success => (Icons.check_circle_outline, Colors.green),
      TaskStatus.failed => (Icons.error_outline, AppTheme.danger),
      TaskStatus.cancelled => (
        Icons.stop_circle_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        entry.goal,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        DateFormat.MMMd().add_Hm().format(entry.startedAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Delete session',
        icon: const Icon(Icons.delete_outline, size: 18),
        onPressed: () => _executor.deleteHistoryEntry(entry.id),
      ),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(entryId: entry.id),
          ),
        );
      },
    );
  }

  Widget _serviceWarning(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: AppTheme.danger.withValues(alpha: 0.14),
        borderColor: AppTheme.danger.withValues(alpha: 0.35),
        onTap: _automation.openAccessibilitySettings,
        child: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.danger,
              size: 22,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accessibility service is off',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.danger,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Tap to open phone settings and enable it',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppTheme.danger,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeTaskBar(ThemeData theme) {
    final maxSteps = SettingsService.instance.maxSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.8,
                    value: maxSteps == 0 ? null : _executor.step / maxSteps,
                  ),
                  Text(
                    '${_executor.step}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _executor.isPaused ? 'Paused' : 'Running task',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _executor.currentGoal ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: _executor.isPaused ? 'Resume' : 'Pause',
              icon: Icon(
                _executor.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              onPressed: () =>
                  _executor.isPaused ? _executor.resume() : _executor.pause(),
            ),
            IconButton(
              tooltip: 'Cancel task',
              icon: const Icon(Icons.stop_rounded, color: AppTheme.danger),
              onPressed: _executor.cancel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcript(ThemeData theme) {
    if (_executor.logs.isEmpty) {
      final isAgent = _mode == AppMode.agent;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.25),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    isAgent ? Icons.smart_toy_rounded : Icons.chat_bubble_rounded,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  isAgent
                      ? 'Autonomous Phone Agent'
                      : 'Private AI Assistant',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isAgent
                      ? '“Open WhatsApp and message Mom”\n'
                            '“Play Closer on YouTube”\n'
                            '“Open Settings and show storage info”'
                      : 'Ask anything — questions, ideas, coding, or writing.\n'
                            'Switch to Agent or GENY mode for autonomous device control.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _suggestionChip('“What’s flying above me?”', () => _submit("What's flying above me?"), theme),
                    _suggestionChip('“Activate air gestures”', () => _submit("Activate air gestures"), theme),
                    _suggestionChip('“Who is on my Wi-Fi?”', () => _submit("Scan devices on my wifi"), theme),
                    _suggestionChip('“Play Closer on YouTube”', () => _submit("Play Closer on YouTube"), theme),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _executor.logs.length,
      itemBuilder: (_, i) => ChatBubble(message: _executor.logs[i]),
    );
  }

  Widget _suggestionChip(String label, VoidCallback onTap, ThemeData theme) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      side: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.25),
        width: 0.8,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onTap,
    );
  }

  Widget _inputBar(ThemeData theme) {
    final isAgent = _mode == AppMode.agent;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        enabled: !_busy,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _submit,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _busy
                              ? (isAgent ? 'Agent is executing…' : 'Thinking…')
                              : (isAgent ? 'Describe a phone task…' : 'Ask anything…'),
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            isAgent ? Icons.smart_toy_outlined : Icons.chat_bubble_outline_rounded,
                            size: 19,
                            color: theme.colorScheme.primary.withValues(alpha: 0.8),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Voice input',
                      onPressed: _busy ? null : _toggleListening,
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none_rounded,
                        color: _listening ? AppTheme.danger : theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            const Color(0xFF4F46E5),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        tooltip: isAgent ? 'Run task' : 'Send',
                        onPressed: _busy ? null : () => _submit(_inputController.text),
                        icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Agent / Chat / GENY mode switcher with Liquid Glass UI.
  Widget _modeSwitcher(ThemeData theme) {
    return LiquidGlassModeSwitcher(
      selectedMode: _mode,
      isBusy: _busy,
      onModeChanged: (mode) {
        final previousMode = _mode;
        setState(() => _mode = mode);
        SettingsService.instance.setAppMode(mode);
        if (mode == AppMode.geny) {
          GenyService.instance.speakGreeting(force: true);
        } else if (previousMode == AppMode.geny) {
          GenyService.instance.onExitGenyMode();
        }
      },
    );
  }

  Widget _agentProactiveBanner(ThemeData theme) {
    final proactive = ProactiveAgentService.instance;
    final suggestion = proactive.currentSuggestion;
    if (suggestion == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: GlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(12),
        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderColor: theme.colorScheme.primary.withValues(alpha: 0.35),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    suggestion.description,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final goal = suggestion.actionGoal;
                proactive.dismissSuggestion();
                _submit(goal);
              },
              child: const Text('Execute', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => proactive.dismissSuggestion(),
            ),
          ],
        ),
      ),
    );
  }

  void _showTodosSheet() {
    final addController = TextEditingController();
    var priority = TodoPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final todoService = TodoService.instance;
            final items = todoService.items;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tasks & To-Do Tracking',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: addController,
                            decoration: const InputDecoration(
                              hintText: 'Add a new task...',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<TodoPriority>(
                          value: priority,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: TodoPriority.low,
                              child: Text('Low', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: TodoPriority.medium,
                              child: Text('Med', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: TodoPriority.high,
                              child: Text('High', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ),
                          ],
                          onChanged: (p) {
                            if (p != null) setModalState(() => priority = p);
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton.filled(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () async {
                            final text = addController.text.trim();
                            if (text.isNotEmpty) {
                              await todoService.addTask(text, priority: priority);
                              addController.clear();
                              setModalState(() {});
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: items.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No tasks created yet.'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return ListTile(
                                  dense: true,
                                  leading: Checkbox(
                                    value: item.isDone,
                                    onChanged: (_) async {
                                      await todoService.toggleDone(item.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                                      color: item.isDone ? Colors.grey : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Priority: ${item.priority.name.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.priority == TodoPriority.high
                                          ? Colors.red
                                          : (item.priority == TodoPriority.medium
                                              ? Colors.orange
                                              : Colors.blueGrey),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await todoService.deleteTask(item.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
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

  void _showCalendarSheet() {
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final calendar = CalendarReminderService.instance;
            final items = calendar.items;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Calendar & Reminders',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              hintText: 'Add reminder (e.g. "Doctor appointment")',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.add_alarm_rounded, size: 20),
                          onPressed: () async {
                            final text = titleController.text.trim();
                            if (text.isNotEmpty) {
                              await calendar.addItem(
                                title: text,
                                dateTime: DateTime.now().add(const Duration(hours: 1)),
                                isReminder: true,
                              );
                              titleController.clear();
                              setModalState(() {});
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open Native Calendar', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          await calendar.openNativeCalendarInsert(
                            title: 'New Schedule',
                            beginTime: DateTime.now().add(const Duration(hours: 1)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.40,
                      ),
                      child: items.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No events scheduled.'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    item.isReminder ? Icons.alarm : Icons.event_note,
                                    size: 20,
                                  ),
                                  title: Text(item.title, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(
                                    DateFormat.yMMMd().add_jm().format(item.dateTime),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await calendar.deleteItem(item.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
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

  void _showNotesSheet() {
    final searchController = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final notesService = NotesKnowledgeService.instance;
            final notes = query.isEmpty
                ? notesService.notes
                : notesService.searchNotes(query);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Notes & Knowledge Base',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search notes & knowledge...',
                              prefixIcon: Icon(Icons.search, size: 18),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              setModalState(() => query = val.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.note_add_outlined, size: 20),
                          tooltip: 'New note',
                          onPressed: () => _createNoteDialog(context, () {
                            setModalState(() {});
                            setState(() {});
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: notes.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No notes found.'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: notes.length,
                              itemBuilder: (context, i) {
                                final note = notes[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    note.title,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () async {
                                      await notesService.deleteNote(note.id);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
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

  void _createNoteDialog(BuildContext context, VoidCallback onSaved) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (content.isNotEmpty) {
                await NotesKnowledgeService.instance.addNote(
                  title: title.isEmpty ? 'Untitled Note' : title,
                  content: content,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                onSaved();
              }
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }
}
