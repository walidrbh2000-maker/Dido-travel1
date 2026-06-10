import 'package:intl/intl.dart';

/// Helper centralisé pour le formatage des montants en Dinar Algérien (DZD).
///
/// Utilise la locale `fr_FR` (séparateur décimal virgule, espace fine pour
/// les milliers) qui correspond aux habitudes d'affichage algériennes en
/// contexte francophone.
class CurrencyHelper {
  const CurrencyHelper._();

  /// Locale par défaut : français (convention algérienne francophone).
  static const String _kLocale = 'fr_FR';

  /// Symbole monétaire par défaut : Dinar Algérien.
  static const String _kDefaultSymbol = 'DA';

  /// Nombre de décimales standard.
  static const int _kDecimalDigits = 2;

  /// Formate [amount] avec le symbole monétaire et deux décimales.
  ///
  /// Exemple : `format(1500.5)` → `'1 500,50 DA'`
  static String format(double amount, {String symbol = _kDefaultSymbol}) {
    final formatter = NumberFormat.currency(
      locale: _kLocale,
      symbol: symbol,
      decimalDigits: _kDecimalDigits,
    );
    return formatter.format(amount);
  }

  /// Formate [amount] de façon compacte (abréviation `k` pour les milliers).
  ///
  /// Exemple : `formatCompact(15000)` → `'15,0k DA'`
  /// Exemple : `formatCompact(500)`   → `'500,00 DA'`
  static String formatCompact(double amount, {String symbol = _kDefaultSymbol}) {
    if (amount >= 1000) {
      // Utilise la virgule décimale conforme à la locale fr_FR.
      final compacted = (amount / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '${compacted}k $symbol';
    }
    return format(amount, symbol: symbol);
  }
}
