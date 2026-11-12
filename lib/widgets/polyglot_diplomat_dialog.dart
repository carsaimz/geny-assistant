import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/polyglot_diplomat_service.dart';
import '../services/voice_service.dart';

/// 🌐 Polyglot Diplomat Live Voice Translation Dialog
class PolyglotDiplomatDialog extends StatefulWidget {
  const PolyglotDiplomatDialog({super.key});

  @override
  State<PolyglotDiplomatDialog> createState() => _PolyglotDiplomatDialogState();
}

class _PolyglotDiplomatDialogState extends State<PolyglotDiplomatDialog> {
  final PolyglotDiplomatService _service = PolyglotDiplomatService.instance;
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _startVoiceTranslation() {
    setState(() => _isListening = true);
    HapticFeedback.mediumImpact();

    VoiceService.instance.startListening(
      manual: true,
      onResult: (text, isFinal, candidates) async {
        setState(() => _isListening = false);
        if (text.trim().isNotEmpty) {
          _textController.text = text;
          await _service.translate(text: text);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          height: 520,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1522).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cyan.withValues(alpha: 0.40), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: cyan.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              return Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyan.withValues(alpha: 0.15),
                          border: Border.all(color: cyan.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.translate, color: cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'POLYGLOT DIPLOMAT',
                              style: TextStyle(
                                color: cyan,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'LIVE TWO-WAY VOICE TRANSLATOR',
                              style: TextStyle(
                                color: Colors.white54,
                                fontFamily: 'monospace',
                                fontSize: 9.0,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Language Selector Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cyan.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _langDropdown(_service.sourceLanguage, (val) {
                          if (val != null) _service.sourceLanguage = val;
                        }),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: cyan),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _service.swapLanguages();
                          },
                        ),
                        _langDropdown(_service.targetLanguage, (val) {
                          if (val != null) _service.targetLanguage = val;
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Conversation Transcript
                  Expanded(
                    child: _service.history.isEmpty
                        ? Center(
                            child: Text(
                              'Speak or type below to initiate live translation between ${_service.sourceLanguage} and ${_service.targetLanguage}.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _service.history.length,
                            itemBuilder: (context, idx) {
                              final msg = _service.history[idx];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cyan.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${msg.sourceLanguage} ➔ ${msg.targetLanguage}',
                                          style: const TextStyle(
                                            color: cyan,
                                            fontFamily: 'monospace',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.volume_up, size: 16, color: cyan),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _service.speakText(
                                            msg.translatedText,
                                            language: msg.targetLanguage,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg.originalText,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      msg.translatedText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Input controls
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type phrase in ${_service.sourceLanguage}...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: cyan.withValues(alpha: 0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _service.translate(text: val);
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mic Button
                      GestureDetector(
                        onTap: _startVoiceTranslation,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? Colors.redAccent : cyan.withValues(alpha: 0.25),
                            border: Border.all(color: _isListening ? Colors.red : cyan),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _langDropdown(String current, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: current,
      dropdownColor: const Color(0xFF0D1D2D),
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00E5FF)),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      items: PolyglotDiplomatService.supportedLanguages.map((lang) {
        return DropdownMenuItem(value: lang, child: Text(lang));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
