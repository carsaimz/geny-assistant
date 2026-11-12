import 'dart:convert';
import 'package:http/http.dart' as http;

class CryptoQuote {
  final String name;
  final String symbol;
  final double priceUsd;
  final double change24h;

  const CryptoQuote({
    required this.name,
    required this.symbol,
    required this.priceUsd,
    required this.change24h,
  });
}

/// Real-time cryptocurrency and financial market tracker.
class FinanceTrackingService {
  FinanceTrackingService._();
  static final FinanceTrackingService instance = FinanceTrackingService._();

  final http.Client _client = http.Client();

  /// Fetches live cryptocurrency quotes via public CoinGecko API.
  Future<List<CryptoQuote>> getTopCryptoQuotes() async {
    final url = Uri.parse(
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana,binancecoin,ripple,dogecoin&vs_currencies=usd&include_24hr_change=true',
    );
    try {
      final resp = await _client.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = <CryptoQuote>[];

        void addIfPresent(String id, String name, String sym) {
          if (data.containsKey(id)) {
            final entry = data[id] as Map<String, dynamic>;
            final price = (entry['usd'] as num?)?.toDouble() ?? 0.0;
            final change = (entry['usd_24h_change'] as num?)?.toDouble() ?? 0.0;
            list.add(CryptoQuote(
              name: name,
              symbol: sym,
              priceUsd: price,
              change24h: change,
            ));
          }
        }

        addIfPresent('bitcoin', 'Bitcoin', 'BTC');
        addIfPresent('ethereum', 'Ethereum', 'ETH');
        addIfPresent('solana', 'Solana', 'SOL');
        addIfPresent('binancecoin', 'BNB', 'BNB');
        addIfPresent('ripple', 'XRP', 'XRP');
        addIfPresent('dogecoin', 'Dogecoin', 'DOGE');

        return list;
      }
    } catch (_) {}
    return [];
  }

  /// Queries quote for a specific coin/asset (e.g., 'bitcoin', 'btc', 'eth', 'sol').
  Future<String> getQuoteForQuery(String query) async {
    final lower = query.toLowerCase().trim();
    final quotes = await getTopCryptoQuotes();

    for (final q in quotes) {
      if (lower.contains(q.name.toLowerCase()) || lower.contains(q.symbol.toLowerCase())) {
        final changeSign = q.change24h >= 0 ? '+' : '';
        final changeStr = '$changeSign${q.change24h.toStringAsFixed(2)}%';
        final priceStr = '\$${q.priceUsd >= 1 ? q.priceUsd.toStringAsFixed(2) : q.priceUsd.toStringAsFixed(4)}';
        return '${q.name} (${q.symbol}) is currently trading at $priceStr USD, up $changeStr in the last 24 hours.';
      }
    }

    if (quotes.isNotEmpty) {
      final btc = quotes.firstWhere(
        (q) => q.symbol == 'BTC',
        orElse: () => quotes.first,
      );
      final priceStr = '\$${btc.priceUsd.toStringAsFixed(0)}';
      return 'Market overview: Bitcoin is currently at $priceStr USD (${btc.change24h >= 0 ? '+' : ''}${btc.change24h.toStringAsFixed(1)}% 24h). How else may I assist your portfolio?';
    }

    return 'Financial markets telemetry is temporarily unreachable.';
  }
}

