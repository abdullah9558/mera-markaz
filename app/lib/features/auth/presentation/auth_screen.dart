import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/presentation/brand_widgets.dart';
import 'auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialSignup = false,
    this.allowGuest = true,
    this.popOnAuthenticated = false,
    this.onBiometric,
  });
  final bool initialSignup;
  final bool allowGuest;
  final bool popOnAuthenticated;
  final Future<void> Function()? onBiometric;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  late bool signup;
  late bool landing;
  bool obscure = true;

  @override
  void initState() {
    super.initState();
    signup = widget.initialSignup;
    landing = widget.allowGuest && !widget.initialSignup;
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (signup && password.text != confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.phrase('Passwords do not match.'))),
      );
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    if (signup) {
      await controller.signUp(name.text, email.text, password.text);
    } else {
      await controller.signIn(email.text, password.text);
    }
  }

  void _showForm(bool create) => setState(() {
    signup = create;
    landing = false;
  });

  void _goBack() {
    if (widget.allowGuest) {
      setState(() {
        landing = true;
        signup = false;
      });
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider.select((value) => value.user), (
      previous,
      next,
    ) {
      if (widget.popOnAuthenticated &&
          previous?.isGuest == true &&
          next != null &&
          !next.isGuest) {
        Navigator.maybePop(context);
      }
    });
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 80,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (!landing && widget.onBiometric == null)
                        IconButton(
                          tooltip: context.l10n.phrase('Back'),
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(128, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        icon: const Icon(Icons.language, size: 19),
                        label: Text(context.l10n.phrase('English')),
                      ),
                    ],
                  ),
                  SizedBox(height: landing ? 76 : 46),
                  Container(
                    width: landing ? 120 : 150,
                    height: landing ? 120 : 150,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .025),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withValues(alpha: .14),
                          blurRadius: 35,
                        ),
                      ],
                    ),
                    child: const BrandMark(size: 108),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.phrase('MeraMarkaz'),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.phrase(
                      'Your Money. Your Bills. Your Pakistan.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFC7CBD6),
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: landing ? 42 : 48),
                  landing
                      ? _LandingCard(
                          busy: state.busy,
                          onEmail: () => _showForm(false),
                          onSignup: () => _showForm(true),
                          onGoogle: () => ref
                              .read(authControllerProvider.notifier)
                              .google(),
                          onFacebook: () => ref
                              .read(authControllerProvider.notifier)
                              .facebook(),
                          onGuest: () => ref
                              .read(authControllerProvider.notifier)
                              .continueOffline(),
                        )
                      : _AuthForm(
                          formKey: formKey,
                          signup: signup,
                          busy: state.busy,
                          error: state.error,
                          obscure: obscure,
                          name: name,
                          email: email,
                          password: password,
                          confirm: confirm,
                          onToggleObscure: () =>
                              setState(() => obscure = !obscure),
                          onSubmit: submit,
                          onToggleMode: () => setState(() => signup = !signup),
                          onGoogle: () => ref
                              .read(authControllerProvider.notifier)
                              .google(),
                          onFacebook: () => ref
                              .read(authControllerProvider.notifier)
                              .facebook(),
                          onGuest: widget.allowGuest
                              ? () => ref
                                    .read(authControllerProvider.notifier)
                                    .continueOffline()
                              : null,
                          onBiometric: widget.onBiometric,
                        ),
                  if (!landing) ...[
                    const SizedBox(height: 42),
                    Text(
                      '${context.l10n.phrase('Terms')}   •   ${context.l10n.phrase('Privacy Policy')}',
                      style: TextStyle(
                        color: const Color(0xFFC7CBD6).withValues(alpha: .7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.phrase('© 2026 Mera Markaz Inc.'),
                      style: TextStyle(
                        color: const Color(0xFFC7CBD6).withValues(alpha: .6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.busy,
    required this.onEmail,
    required this.onSignup,
    required this.onGoogle,
    required this.onFacebook,
    required this.onGuest,
  });
  final bool busy;
  final VoidCallback onEmail;
  final VoidCallback onSignup;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : onGoogle,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF18221F),
          ),
          icon: const GoogleBrandMark(size: 24),
          label: Text(context.l10n.phrase('Continue with Google')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : onFacebook,
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF1877F2)),
          ),
          icon: const FacebookBrandMark(size: 25, inverse: true),
          label: Text(context.l10n.phrase('Continue with Facebook')),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onEmail,
          icon: const Icon(Icons.mail_outline),
          label: Text(context.l10n.phrase('Continue with Email')),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: busy ? null : onGuest,
          child: Text(context.l10n.phrase('Continue as Guest')),
        ),
        const SizedBox(height: 26),
        const _OrDivider(),
        const SizedBox(height: 26),
        Text(
          context.l10n.phrase('New to Mera Markaz?'),
          style: const TextStyle(color: Color(0xFFC7CBD6)),
        ),
        TextButton(
          onPressed: busy ? null : onSignup,
          child: Text(context.l10n.phrase('Create a new Account')),
        ),
      ],
    ),
  );
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.signup,
    required this.busy,
    required this.error,
    required this.obscure,
    required this.name,
    required this.email,
    required this.password,
    required this.confirm,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onGoogle,
    required this.onFacebook,
    this.onGuest,
    this.onBiometric,
  });
  final GlobalKey<FormState> formKey;
  final bool signup;
  final bool busy;
  final String? error;
  final bool obscure;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;
  final VoidCallback? onGuest;
  final Future<void> Function()? onBiometric;

  @override
  Widget build(BuildContext context) => _GlassPanel(
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.phrase(signup ? 'Create account' : 'Sign In'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          if (signup) ...[
            TextFormField(
              controller: name,
              decoration: InputDecoration(
                hintText: context.l10n.phrase('Full name'),
              ),
              validator: (value) => value == null || value.trim().length < 2
                  ? context.l10n.phrase('Enter your full name.')
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: context.l10n.phrase('Email Address'),
            ),
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())
                ? context.l10n.phrase('Enter a valid email address.')
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: password,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: context.l10n.phrase('Password'),
              suffixIcon: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: (value) => value == null || value.length < 6
                ? context.l10n.phrase('Password must be at least 6 characters.')
                : null,
          ),
          if (signup) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: confirm,
              obscureText: obscure,
              decoration: InputDecoration(
                hintText: context.l10n.phrase('Confirm password'),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? context.l10n.phrase('Confirm your password.')
                  : null,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.phrase(error!),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: Text(
              context.l10n.phrase(signup ? 'Create account' : 'Sign In'),
            ),
          ),
          if (onBiometric != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onBiometric,
              icon: const Icon(Icons.fingerprint),
              label: Text(context.l10n.phrase('Sign in with fingerprint')),
            ),
          ],
          const SizedBox(height: 14),
          TextButton(
            onPressed: busy ? null : onToggleMode,
            child: Text(
              context.l10n.phrase(
                signup
                    ? 'Already have an account? Sign in'
                    : "Don't have an account? Sign Up",
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _OrDivider(label: 'OR CONTINUE WITH'),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: busy ? null : onGoogle,
            icon: const GoogleBrandMark(size: 24),
            label: Text(context.l10n.phrase('Google')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onFacebook,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1877F2),
              side: const BorderSide(color: Color(0xFF1877F2)),
            ),
            icon: const FacebookBrandMark(size: 25),
            label: Text(context.l10n.phrase('Facebook')),
          ),
          if (onGuest != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: busy ? null : onGuest,
              icon: const Icon(Icons.arrow_forward),
              label: Text(context.l10n.phrase('Explore as Guest')),
            ),
          ],
        ],
      ),
    ),
  );
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
    decoration: BoxDecoration(
      color: const Color(0xFF201C22).withValues(alpha: .82),
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
      boxShadow: [
        BoxShadow(
          color: AppColors.emerald.withValues(alpha: .08),
          blurRadius: 36,
        ),
      ],
    ),
    child: child,
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({this.label = 'OR'});
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC7CBD6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class GoogleBrandMark extends StatelessWidget {
  const GoogleBrandMark({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/google-g.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: context.l10n.phrase('Google'),
  );
}

class FacebookBrandMark extends StatelessWidget {
  const FacebookBrandMark({super.key, this.size = 24, this.inverse = false});
  final double size;
  final bool inverse;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.bottomCenter,
    decoration: BoxDecoration(
      color: inverse ? Colors.white : const Color(0xFF1877F2),
      shape: BoxShape.circle,
    ),
    child: Text(
      context.l10n.phrase('f'),
      style: TextStyle(
        color: inverse ? const Color(0xFF1877F2) : Colors.white,
        fontSize: size * .94,
        height: .93,
        fontWeight: FontWeight.w900,
        fontFamily: 'Arial',
      ),
    ),
  );
}
