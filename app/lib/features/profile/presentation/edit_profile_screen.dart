import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../domain/user_profile.dart';
import 'profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _occupation;
  late String _province;
  bool _saving = false;

  static const _provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Gilgit-Baltistan',
    'Azad Jammu & Kashmir',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName);
    _phone = TextEditingController(text: widget.profile.phone);
    _city = TextEditingController(text: widget.profile.city);
    _occupation = TextEditingController(text: widget.profile.occupation);
    _province = widget.profile.province;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(userProfileProvider.notifier)
        .save(
          widget.profile.copyWith(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            city: _city.text.trim(),
            province: _province,
            occupation: _occupation.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Edit profile'))),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.phrase('Personal information'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.phrase(
              'Keep your details up to date for a more personal experience.',
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: CircleAvatar(
              radius: 54,
              backgroundImage: widget.profile.photoUrl?.isNotEmpty == true
                  ? NetworkImage(widget.profile.photoUrl!)
                  : null,
              child: widget.profile.photoUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      widget.profile.fullName.trim().isEmpty
                          ? context.l10n.phrase('User')
                          : widget.profile.fullName.trim().characters.first,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Full name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (value) => value == null || value.trim().length < 2
                ? context.l10n.phrase('Enter your full name.')
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: widget.profile.email,
            enabled: false,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Email address'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Phone number'),
              hintText: '03XX XXXXXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _province.isEmpty ? null : _province,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Province / Region'),
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: _provinces
                .map(
                  (province) => DropdownMenuItem(
                    value: province,
                    child: Text(context.l10n.phrase(province)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _province = value ?? ''),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('City'),
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _occupation,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Occupation'),
              prefixIcon: const Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              context.l10n.phrase(_saving ? 'Saving…' : 'Save changes'),
            ),
          ),
        ],
      ),
    ),
  );
}
