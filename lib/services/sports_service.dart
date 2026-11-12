import 'ai_service.dart';
import 'geny_tools_service.dart';

/// Sports scores & match schedules service.
class SportsService {
  SportsService._();
  static final SportsService instance = SportsService._();

  /// Retrieves live sports scores, match updates, or schedules.
  Future<String> getSportsUpdate(String query) async {
    final clean = query.trim();
    final searchQuery = clean.isNotEmpty
        ? '$clean scores results schedule'
        : 'latest sports scores football cricket nba';

    // 1. Fetch live web news & records
    final rawData = await GenyToolsService.instance.searchWeb(searchQuery);

    // 2. Synthesize with AI for articulate, lively sports commentary
    final synthesized = await AiService.instance.answerWithToolResult(
      userQuestion: query,
      toolResult: rawData,
    );

    return synthesized;
  }
}

