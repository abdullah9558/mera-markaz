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
    'How much did I spend this month?',
    'Can I afford Rs. 50,000 this month?',
    'What payments are coming up?',
    'Compare this month',
    'Where can I save?',
    'Which category increased most?',
    'Check my budget',
    'Summarize my Udhaar',
    'What is the USD rate?',
  ];
  final _question = TextEditingController();
  int? _conversationId;
  String _conversationTitle = 'New chat';
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
    final chats = await repository.conversations();
    final title = chats
        .where((conversation) => conversation.id == id)
        .map((conversation) => conversation.title)
        .firstOrNull;
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _conversationTitle = title ?? 'New chat';
      _messages = messages;
    });
  }

  Future<void> _newConversation() async {
    final id = await ref
        .read(aiConversationRepositoryProvider)
        .createConversation();
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _conversationTitle = 'New chat';
      _messages = const [];
    });
  }

  Future<void> _openConversation(AiConversation conversation) async {
    final messages = await ref
        .read(aiConversationRepositoryProvider)
        .messages(conversation.id);
    if (!mounted) return;
    setState(() {
      _conversationId = conversation.id;
      _conversationTitle = conversation.title;
      _messages = messages;
    });
  }

  Future<void> _renameConversation() async {
    final id = _conversationId;
    if (id == null) return;
    final controller = TextEditingController(text: _conversationTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.phrase('Rename chat')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Chat title'),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    await ref
        .read(aiConversationRepositoryProvider)
        .renameConversation(id, title);
    if (mounted) setState(() => _conversationTitle = title.trim());
  }

  Future<void> _deleteConversation() async {
    final id = _conversationId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.phrase('Delete chat?')),
        content: Text(
          context.l10n.phrase(
            'This chat and its messages will be permanently deleted from this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.phrase('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(aiConversationRepositoryProvider).deleteConversation(id);
    await _loadConversation();
  }

  Future<void> _showChats() async {
    final repository = ref.read(aiConversationRepositoryProvider);
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: .82,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.phrase('Your chats'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: context.l10n.phrase('New chat'),
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _newConversation();
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: context.l10n.phrase('Search chats'),
                  ),
                  onChanged: (value) => setSheetState(() => query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<AiConversation>>(
                  future: repository.conversations(query: query),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final chats = snapshot.data!;
                    if (chats.isEmpty) {
                      return Center(
                        child: Text(context.l10n.phrase('No chats found')),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ListTile(
                          selected: chat.id == _conversationId,
                          leading: const Icon(
                            Icons.chat_bubble_outline_rounded,
                          ),
                          title: Text(
                            context.l10n.phrase(chat.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatShortDate(chat.updatedAt),
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _openConversation(chat);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      await repository.titleFromFirstMessage(conversation, question);
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
          if (_messages.isEmpty) {
            _conversationTitle = question.length <= 42
                ? question
                : '${question.substring(0, 39).trimRight()}...';
          }
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
                        context.l10n.phrase('Online AI consent was removed.'),
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
        title: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _showChats,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    context.l10n.phrase(_conversationTitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.phrase('New chat'),
            onPressed: _newConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _renameConversation();
              if (value == 'delete') _deleteConversation();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'rename',
                child: Text(context.l10n.phrase('Rename chat')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.l10n.phrase('Delete chat')),
              ),
            ],
          ),
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
