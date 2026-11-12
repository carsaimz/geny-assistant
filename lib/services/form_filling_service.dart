import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ai_service.dart';
import 'conversational_memory_service.dart';
import 'hermes_evolution_service.dart';
import 'personality_service.dart';
import 'screen_automation_service.dart';
import 'voice_service.dart';

/// Autonomous Form Filling Service for G.E.N.Y.
/// Automatically detects form inputs on screen (in any browser, native app, or webview)
/// and populates them using G.E.N.Y.'s accumulated memory (USER.md and ConversationalMemoryService).
class FormFillingService {
  FormFillingService._();
  static final FormFillingService instance = FormFillingService._();

  final ScreenAutomationService _automation = ScreenAutomationService.instance;
  final ConversationalMemoryService _memory = ConversationalMemoryService.instance;
  final HermesEvolutionService _hermes = HermesEvolutionService.instance;

  /// Executes autonomous form filling on the active foreground window.
  Future<String> fillActiveForm() async {
    final ack = PersonalityService.instance.getFormFillAck();
    await VoiceService.instance.speak(ack);

    try {
      // 1. Dump current accessibility tree
      final nodes = await _automation.dumpScreen();
      if (nodes.isEmpty) {
        return 'I was unable to detect any interface elements on the current screen.';
      }

      // 2. Identify editable fields
      final formFields = nodes.where((n) {
        final isEdit = n.isEditable ||
            n.className.toLowerCase().contains('edittext') ||
            n.className.toLowerCase().contains('textinput') ||
            n.className.toLowerCase().contains('autocompletetextview');
        return isEdit;
      }).toList();

      if (formFields.isEmpty) {
        // Fallback: search for input containers or search/text bars
        final fallbackFields = nodes.where((n) {
          final text = '${n.text} ${n.contentDescription}'.toLowerCase();
          return n.isClickable &&
              (text.contains('name') ||
                  text.contains('email') ||
                  text.contains('phone') ||
                  text.contains('address') ||
                  text.contains('enter') ||
                  text.contains('type here'));
        }).toList();

        if (fallbackFields.isEmpty) {
          return 'I could not detect any editable form fields on the current screen.';
        }
        formFields.addAll(fallbackFields);
      }

      // 3. Extract user knowledge base
      final userKnowledge = buildUserKnowledgeMap();

      // 4. Map each field to appropriate user knowledge
      int filledCount = 0;
      for (final field in formFields) {
        final label = '${field.text} ${field.contentDescription} ${field.viewId}'.trim().toLowerCase();
        final matchedValue = _resolveValueForField(label, userKnowledge);

        if (matchedValue != null && matchedValue.isNotEmpty) {
          try {
            await _automation.clickNode(field);
            await Future.delayed(const Duration(milliseconds: 300));
            await _automation.typeText(matchedValue);
            await Future.delayed(const Duration(milliseconds: 250));
            filledCount++;
          } catch (e) {
            debugPrint('[FormFillingService] Error populating field "$label": $e');
          }
        }
      }

      if (filledCount == 0) {
        // If heuristic matching didn't catch specific fields, query LLM for mapping
        filledCount = await _aiAssistedFill(formFields, userKnowledge);
      }

      if (filledCount > 0) {
        return PersonalityService.instance.getFormFillCompletion(filledCount);
      } else {
        return 'I located form fields on your screen, but could not determine matching profile values to populate.';
      }
    } catch (e) {
      debugPrint('[FormFillingService] Fatal error filling form: $e');
      return 'Encountered an exception while filling the form.';
    }
  }

  /// Builds a profile dictionary from USER.md and long-term memory facts.
  Map<String, String> buildUserKnowledgeMap() {
    final map = <String, String>{
      'name': 'Alex Stark',
      'first_name': 'Alex',
      'last_name': 'Stark',
      'email': 'alex.stark@gmail.com',
      'phone': '+1 555-0199',
      'address': '10880 Malibu Point',
      'city': 'Malibu',
      'state': 'California',
      'country': 'United States',
      'zip': '90265',
      'postal_code': '90265',
      'company': 'Stark Industries',
      'job_title': 'Chief Engineer',
    };

    // Extract facts from ConversationalMemoryService
    for (final fact in _memory.facts) {
      final f = fact.fact.toLowerCase();
      if (f.contains('name is')) {
        map['name'] = fact.fact.split('name is').last.trim();
      } else if (f.contains('email is')) {
        map['email'] = fact.fact.split('email is').last.trim();
      } else if (f.contains('phone is') || f.contains('number is')) {
        map['phone'] = fact.fact.split(RegExp(r'(phone|number)\s+is')).last.trim();
      } else if (f.contains('lives in') || f.contains('city is')) {
        map['city'] = fact.fact.split(RegExp(r'(lives in|city is)')).last.trim();
      } else if (f.contains('address is')) {
        map['address'] = fact.fact.split('address is').last.trim();
      }
    }

    // Extract from USER.md
    final userMd = _hermes.userMd;
    final lines = userMd.split('\n');
    for (final line in lines) {
      final clean = line.replaceAll(RegExp(r'^[*\-#\s]+'), '').trim();
      if (clean.toLowerCase().startsWith('name:')) {
        map['name'] = clean.substring(5).trim();
      } else if (clean.toLowerCase().startsWith('email:')) {
        map['email'] = clean.substring(6).trim();
      } else if (clean.toLowerCase().startsWith('phone:')) {
        map['phone'] = clean.substring(6).trim();
      } else if (clean.toLowerCase().startsWith('location:') || clean.toLowerCase().startsWith('city:')) {
        map['city'] = clean.split(':').last.trim();
      }
    }

    return map;
  }

  /// Resolves the corresponding profile value based on the field's label or hint.
  String? _resolveValueForField(String label, Map<String, String> userKnowledge) {
    if (label.contains('first name') || label.contains('given name') || label.contains('fname')) {
      return userKnowledge['first_name'] ?? userKnowledge['name']?.split(' ').first;
    }
    if (label.contains('last name') || label.contains('surname') || label.contains('family name') || label.contains('lname')) {
      return userKnowledge['last_name'] ?? userKnowledge['name']?.split(' ').last;
    }
    if (label.contains('full name') || (label.contains('name') && !label.contains('user') && !label.contains('file'))) {
      return userKnowledge['name'];
    }
    if (label.contains('email') || label.contains('mail')) {
      return userKnowledge['email'];
    }
    if (label.contains('phone') || label.contains('mobile') || label.contains('tel') || label.contains('cell')) {
      return userKnowledge['phone'];
    }
    if (label.contains('address') || label.contains('street')) {
      return userKnowledge['address'];
    }
    if (label.contains('city') || label.contains('town')) {
      return userKnowledge['city'];
    }
    if (label.contains('state') || label.contains('province')) {
      return userKnowledge['state'];
    }
    if (label.contains('zip') || label.contains('postal') || label.contains('pincode') || label.contains('pin code')) {
      return userKnowledge['zip'] ?? userKnowledge['postal_code'];
    }
    if (label.contains('country')) {
      return userKnowledge['country'];
    }
    if (label.contains('company') || label.contains('organization')) {
      return userKnowledge['company'];
    }
    if (label.contains('title') || label.contains('role') || label.contains('occupation')) {
      return userKnowledge['job_title'];
    }
    return null;
  }

  /// AI-assisted fallback when standard label heuristics do not match.
  Future<int> _aiAssistedFill(List<dynamic> fields, Map<String, String> userKnowledge) async {
    try {
      final fieldSummaries = fields.map((f) => {
            'index': f.index,
            'text': f.text,
            'hint': f.contentDescription,
            'id': f.viewId,
          }).toList();

      final prompt = '''
Here are form fields detected on an Android screen:
${jsonEncode(fieldSummaries)}

Here is user profile data:
${jsonEncode(userKnowledge)}

Match each field index to the user profile value that should be typed into it.
Return ONLY valid JSON array in this format:
[{"index": 0, "value": "John"}, {"index": 1, "value": "john@gmail.com"}]
''';

      final response = await AiService.instance.chat(message: prompt);
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return 0;

      final decoded = jsonDecode(jsonMatch.group(0)!);
      if (decoded is! List) return 0;

      int count = 0;
      for (final item in decoded) {
        if (item is Map) {
          final idx = item['index'] as int?;
          final val = item['value']?.toString() ?? '';
          if (idx != null && val.isNotEmpty) {
            final node = fields.cast<dynamic>().firstWhere((f) => f.index == idx, orElse: () => null);
            if (node != null) {
              await _automation.clickNode(node);
              await Future.delayed(const Duration(milliseconds: 300));
              await _automation.typeText(val);
              await Future.delayed(const Duration(milliseconds: 250));
              count++;
            }
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }
}
