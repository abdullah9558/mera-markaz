import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

enum LegalDocument { privacy, terms }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});
  final LegalDocument document;
  @override
  Widget build(BuildContext context) {
    final privacy = document == LegalDocument.privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.phrase(
            privacy ? 'Privacy Policy' : 'Terms & Conditions',
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.phrase(
              privacy
                  ? 'MeraMarkaz Privacy Policy'
                  : 'MeraMarkaz Terms & Conditions',
            ),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(context.l10n.phrase('Effective: 23 August 2026')),
          SizedBox(height: 20),
          if (privacy) ...[
            Text(
              context.l10n.phrase('Local-first data'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'Your expenses, income, Udhaar records and saved calculations are stored locally on your device by default. You may use an account or continue offline. Account login may process your name, email address, provider identifier and basic provider profile. MeraMarkaz does not require CNIC, card details, contacts, SMS, call logs or location for its core features.',
              ),
            ),
            SizedBox(height: 18),
            Text(
              context.l10n.phrase('Optional services'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'Online Markaz AI is optional. After you provide separate consent, a limited financial summary may be processed by Google Gemini to provide personalized financial assistance. Passwords, authentication tokens, contact details, notes, receipts and complete transaction records are excluded. Guest mode and local answers do not send financial information to Gemini.',
              ),
            ),
            SizedBox(height: 18),
            Text(
              context.l10n.phrase('AI limitations'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'Gemini responses are generated for informational purposes and may be incomplete or inaccurate. They are not financial, tax, legal or religious advice.',
              ),
            ),
            SizedBox(height: 18),
            Text(
              context.l10n.phrase('Your controls'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'You can export or delete locally stored financial data from Settings. You can withdraw online-AI consent at any time from the Markaz AI privacy dialog without deleting local conversation history.',
              ),
            ),
          ] else ...[
            Text(
              context.l10n.phrase('Estimates'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'Tax, electricity, solar, property, fuel and Zakat results are informational estimates. They are not official bills, tax advice, legal advice, financial advice or religious rulings.',
              ),
            ),
            SizedBox(height: 18),
            Text(
              context.l10n.phrase('User responsibility'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              context.l10n.phrase(
                'You are responsible for checking inputs, current official rates and exported records before relying on a result.',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
