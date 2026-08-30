import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  bool _anonymous = false;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    try {
      await const FeedbackService().submit(
        name: _anonymous ? null : _name.text,
        phone: _anonymous ? null : _phone.text,
        message: _message.text,
      );
      if (!mounted) return;
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.phrase('Thank you. Your feedback has been sent.'),
          ),
        ),
      );
    } on FeedbackSubmissionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.phrase(error.message))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('Send Feedback'))),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.forum_outlined, color: colors.primary, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.phrase('Help us improve Mera Markaz'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.phrase(
                        'Share a suggestion, report a problem, or tell us what you would like to see next.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _anonymous,
                onChanged: (value) => setState(() => _anonymous = value),
                title: Text(context.l10n.phrase('Send anonymously')),
                subtitle: Text(
                  context.l10n.phrase(
                    'Your name and phone number will not be included.',
                  ),
                ),
              ),
              if (!_anonymous) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Name (optional)'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Phone number (optional)'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                minLines: 6,
                maxLines: 10,
                maxLength: 2000,
                textAlign: TextAlign.start,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  floatingLabelAlignment: FloatingLabelAlignment.start,
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    18,
                    20,
                    18,
                    18,
                  ),
                  labelText: context.l10n.phrase('Your message'),
                  hintText: context.l10n.phrase(
                    'Describe your suggestion or the issue you experienced…',
                  ),
                ),
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 10) {
                    return context.l10n.phrase(
                      'Please enter at least 10 characters.',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.phrase(
                  'Do not include passwords, verification codes, card details, CNIC numbers, or other sensitive information.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  context.l10n.phrase(_sending ? 'Sending…' : 'Send Feedback'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
