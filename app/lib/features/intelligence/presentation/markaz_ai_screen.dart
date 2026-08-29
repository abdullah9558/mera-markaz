import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/ai_conversation_repository.dart';
import '../data/intelligence_provider.dart';
import '../domain/financial_intelligence.dart';
import '../domain/markaz_ai.dart';

class MarkazAiScreen extends ConsumerStatefulWidget {
  const MarkazAiScreen({super.key});
  @override
  ConsumerState<MarkazAiScreen> createState() => _MarkazAiScreenState();
}

class _MarkazAiScreenState extends ConsumerState<MarkazAiScreen> {
  static const _suggestions = [
    'Analyze my spending',
    'Compare this month',
    'Where can I save?',
    'Show my biggest expenses',
    'Check my budget',
    'Summarize my Udhaar',
    'Analyze my fuel spending',
  ];
  final _question = TextEditingController();
  int? _conversationId;
  List<AiChatMessage> _messages = const [];
  bool _sending = false;
  final _aiConsent = AiPrivacyConsent();

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    final repository = ref.read(aiConversationRepositoryProvider);
    final id = await repository.currentConversation();
    final messages = await repository.messages(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _messages = messages;
    });
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? suggested]) async {
    final question = (suggested ?? _question.text).trim();
    if (question.isEmpty || _sending) return;
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    setState(() => _sending = true);
    try {
      final snapshot = await ref.read(intelligenceSnapshotProvider.future);
      final repository = ref.read(aiConversationRepositoryProvider);
      final conversation =
          _conversationId ?? await repository.currentConversation();
      await repository.addMessage(conversation, 'user', question);
      final auth = ref.read(authControllerProvider);
      final user = auth.user;
      final gateway = ref.read(externalAiGatewayProvider);
      final canUseOnlineAi =
          user != null && !user.isGuest && gateway.configured;
      String answer;
      if (canUseOnlineAi && await _requestOnlineAiConsent()) {
        try {
          answer = await gateway.send(
            prompt: question,
            data: safeAiSummary(snapshot),
          );
        } catch (_) {
          answer = const LocalMarkazQueryEngine().answer(
            question,
            snapshot,
            urdu: urdu,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.phrase(
                    'Online AI is unavailable. Showing a local answer instead.',
                  ),
                ),
              ),
            );
          }
        }
      } else {
        answer = const LocalMarkazQueryEngine().answer(
          question,
          snapshot,
          urdu: urdu,
        );
      }
      await repository.addMessage(conversation, 'assistant', answer);
      _question.clear();
      final messages = await repository.messages(conversation);
      if (mounted) {
        setState(() {
          _conversationId = conversation;
          _messages = messages;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _requestOnlineAiConsent() async {
    if (await _aiConsent.granted()) return true;
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_outlined),
        title: Text(context.l10n.phrase('Use online Markaz AI?')),
        content: Text(
          context.l10n.phrase(
            'A limited summary of your financial information will be sent securely to Google Gemini to answer your question. Passwords, authentication tokens, contact details and complete transaction records are not included.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.phrase('Continue locally')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.phrase('Use online AI')),
          ),
        ],
      ),
    );
    final granted = accepted == true;
    if (granted) await _aiConsent.setGranted(true);
    return granted;
  }

  Future<void> _privacyInfo() async {
    final consentGranted = await _aiConsent.granted();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.shield_outlined),
        title: Text(context.l10n.phrase('AI privacy')),
        content: Text(
          context.l10n.phrase(
            consentGranted
                ? 'Online AI is enabled. Only a limited financial summary is sent to Google Gemini. Identity, contact details, notes, receipts and individual transactions are not included.'
                : 'Guests and users who do not provide online-AI consent use the local assistant. No financial data is sent to Google Gemini in local mode.',
          ),
        ),
        actions: [
          if (consentGranted)
            TextButton(
              onPressed: () async {
                await _aiConsent.setGranted(false);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.phrase(
                          'Online AI consent was removed.',
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(context.l10n.phrase('Disable online AI')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.phrase('Done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(markazScoreProvider);
    final insights = ref.watch(financialInsightsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phrase('Markaz AI')),
        actions: [
          IconButton(
            tooltip: context.l10n.phrase('AI privacy'),
            onPressed: _privacyInfo,
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                score.when(
                  data: (value) => _ScoreCard(score: value),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),
                insights.when(
                  data: (values) => _InsightsCard(insights: values),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.phrase('Try asking'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map(
                        (question) => ActionChip(
                          label: Text(context.l10n.phrase(question)),
                          onPressed: () => _ask(question),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                if (_messages.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        context.l10n.phrase(
                          'Ask a question about your locally recorded finances.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._messages.map(
                    (message) => Align(
                      alignment: message.role == 'user'
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 330),
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: message.role == 'user'
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(message.content),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: InputDecoration(
                        hintText: context.l10n.phrase('Ask Markaz AI…'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _ask,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});
  final MarkazScore score;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: CircleAvatar(child: Text('${score.value}')),
      title: Text(
        context.l10n.phrase('Markaz Score'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${score.value} / 100 • ${context.l10n.phrase(score.status)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        Text(
          context.l10n.phrase(
            'This is a personal wellness indicator, not a credit score or financial certification.',
          ),
        ),
        const SizedBox(height: 12),
        for (final factor in score.factors)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              factor.positive ? Icons.check_circle_outline : Icons.info_outline,
            ),
            title: Text(context.l10n.phrase(factor.label)),
            trailing: Text('${factor.points}/${factor.maximum}'),
          ),
        if (score.improvements.isNotEmpty) ...[
          const Divider(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.l10n.phrase('Improve your score'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final item in score.improvements)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.arrow_upward_rounded),
              title: Text(context.l10n.phrase(item)),
            ),
        ],
      ],
    ),
  );
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});
  final List<FinancialInsight> insights;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.phrase('Smart insights'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (insights.isEmpty)
            Text(
              context.l10n.phrase(
                "Keep using Mera Markaz and we'll show insights as your financial history grows.",
              ),
            )
          else
            for (final insight in insights.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  insight.kind == InsightKind.warning
                      ? Icons.warning_amber_rounded
                      : Icons.auto_awesome_outlined,
                ),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ur'
                      ? insight.urduMessage
                      : insight.message,
                ),
              ),
        ],
      ),
    ),
  );
}
