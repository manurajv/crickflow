import '../models/ai_ops_enums.dart';
import '../models/managed_ai_ops.dart';

/// Pluggable AI provider contract.
///
/// Implementations (OpenAI, Gemini, Vertex, Claude, local, etc.) must never
/// expose API keys to the admin client. Keys belong in Cloud Functions / Secret
/// Manager. The admin UI only sees recommendations / insights returned here.
abstract class AiProviderAdapter {
  AiProviderId get providerId;

  String get displayName;

  /// Future: generate natural-language insights.
  Future<List<AiInsightCard>> generateInsights({String? organizationId});

  /// Future: score / classify content.
  Future<AiRecommendation?> scoreEntity({
    required AiEntityType entityType,
    required String entityId,
    Map<String, dynamic> context = const {},
  });
}

/// Default adapter — rules engine only, no external network calls.
class RulesEngineAiAdapter implements AiProviderAdapter {
  @override
  AiProviderId get providerId => AiProviderId.none;

  @override
  String get displayName => 'Rules Engine';

  @override
  Future<List<AiInsightCard>> generateInsights({String? organizationId}) async {
    // Heuristic placeholders until a Cloud Function wires a real provider.
    return const [
      AiInsightCard(
        id: 'growth',
        title: 'User growth trends',
        value: 'Rules sample',
        subtitle: 'Wire Cloud Function + provider later',
        trend: '—',
      ),
      AiInsightCard(
        id: 'inactive_orgs',
        title: 'Inactive organizations',
        value: 'Scan pending',
        subtitle: 'Scheduled job architecture ready',
      ),
      AiInsightCard(
        id: 'peak_stream',
        title: 'Peak streaming hours',
        value: 'Future AI',
        subtitle: 'Analytics warehouse integration',
      ),
      AiInsightCard(
        id: 'formats',
        title: 'Popular match formats',
        value: 'Future AI',
        subtitle: 'Derived from match samples',
      ),
      AiInsightCard(
        id: 'cities',
        title: 'Popular cities',
        value: 'Future AI',
        subtitle: 'Geo aggregates later',
      ),
      AiInsightCard(
        id: 'trending',
        title: 'Trending teams / players',
        value: 'Future AI',
        subtitle: 'Recommendation model later',
      ),
    ];
  }

  @override
  Future<AiRecommendation?> scoreEntity({
    required AiEntityType entityType,
    required String entityId,
    Map<String, dynamic> context = const {},
  }) async =>
      null;
}

/// Registry of known providers (metadata only — no credentials).
class AiProviderCatalog {
  static const List<AiModelRegistryEntry> defaultModels = [
    AiModelRegistryEntry(
      id: 'rules',
      provider: AiProviderId.none,
      name: 'Rules Engine',
      version: '1.0',
      status: AiModelStatus.ready,
      capabilities: ['automation_rules', 'recommendations', 'heuristics'],
    ),
    AiModelRegistryEntry(
      id: 'openai',
      provider: AiProviderId.openai,
      name: 'OpenAI',
      status: AiModelStatus.notConfigured,
      capabilities: ['insights', 'moderation', 'spam', 'summaries'],
    ),
    AiModelRegistryEntry(
      id: 'gemini',
      provider: AiProviderId.gemini,
      name: 'Google Gemini',
      status: AiModelStatus.notConfigured,
      capabilities: ['insights', 'vision', 'moderation'],
    ),
    AiModelRegistryEntry(
      id: 'vertex',
      provider: AiProviderId.vertexAi,
      name: 'Vertex AI',
      status: AiModelStatus.notConfigured,
      capabilities: ['batch', 'fraud', 'embeddings'],
    ),
    AiModelRegistryEntry(
      id: 'firebase_ai',
      provider: AiProviderId.firebaseAi,
      name: 'Firebase AI Logic',
      status: AiModelStatus.notConfigured,
      capabilities: ['on_device', 'moderation'],
    ),
    AiModelRegistryEntry(
      id: 'azure',
      provider: AiProviderId.azureOpenAi,
      name: 'Azure OpenAI',
      status: AiModelStatus.notConfigured,
      capabilities: ['enterprise', 'moderation'],
    ),
    AiModelRegistryEntry(
      id: 'claude',
      provider: AiProviderId.anthropic,
      name: 'Anthropic Claude',
      status: AiModelStatus.notConfigured,
      capabilities: ['insights', 'reasoning'],
    ),
    AiModelRegistryEntry(
      id: 'local',
      provider: AiProviderId.local,
      name: 'Local AI Models',
      status: AiModelStatus.notConfigured,
      capabilities: ['offline', 'privacy'],
    ),
  ];

  static AiProviderAdapter resolve(AiProviderId id) {
    // Future: switch to remote adapters via Cloud Functions.
    return RulesEngineAiAdapter();
  }
}
