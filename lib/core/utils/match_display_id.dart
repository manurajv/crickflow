/// Short numeric match ID shown in live scoring (e.g. 24881400).
class MatchDisplayId {
  MatchDisplayId._();

  static String of(String matchDocumentId) {
    final hash = matchDocumentId.hashCode.abs();
    return (hash % 100000000).toString().padLeft(8, '0');
  }
}
