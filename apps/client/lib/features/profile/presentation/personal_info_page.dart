import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/foundation.dart';

final _nameRe = RegExp(r"^[A-Za-zÀ-ÿ' -]{2,40}$");
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Informations personnelles : photo de profil, prénom, nom, e-mail
/// et ville principale. Le téléphone (identifiant de connexion)
/// n'est pas modifiable ici.
class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  late final AppUser? _initial = ref.read(authProvider).user;
  late final _firstName = TextEditingController(text: _initial?.firstName);
  late final _lastName = TextEditingController(text: _initial?.lastName);
  late final _email = TextEditingController(text: _initial?.email);
  late String _city = _initial?.city ?? 'Abidjan';
  late Uint8List? _photo = ref.read(profilePhotoProvider);
  bool _photoChanged = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Map<String, String> get _errors {
    final e = <String, String>{};
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    final email = _email.text.trim();
    if (first.isEmpty) {
      e['firstName'] = 'Le prénom est requis.';
    } else if (!_nameRe.hasMatch(first)) {
      e['firstName'] = 'Au moins 2 caractères.';
    }
    if (last.isEmpty) {
      e['lastName'] = 'Le nom est requis.';
    } else if (!_nameRe.hasMatch(last)) {
      e['lastName'] = 'Au moins 2 caractères.';
    }
    if (email.isNotEmpty && !_emailRe.hasMatch(email)) {
      e['email'] = 'Adresse e-mail invalide.';
    }
    return e;
  }

  bool get _dirty {
    final u = _initial;
    if (u == null) return false;
    return _firstName.text.trim() != u.firstName ||
        _lastName.text.trim() != u.lastName ||
        _email.text.trim() != u.email ||
        _city != u.city ||
        _photoChanged;
  }

  Future<void> _pickCity() async {
    final city = await CityPicker.show(
      context,
      title: 'Ville principale',
      selectedName: _city,
    );
    if (city == null) return;
    setState(() => _city = city.name);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _photoChanged = true;
      });
    } catch (_) {
      if (mounted) {
        showMoncarToast(
          context,
          source == ImageSource.camera
              ? "Impossible d'ouvrir l'appareil photo."
              : "Impossible d'ouvrir la galerie.",
        );
      }
    }
  }

  Future<void> _showPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: MoncarColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Photo de profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MoncarColors.ink,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: MoncarColors.brand,
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: MoncarColors.brand,
              ),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            if (_photo != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: MoncarColors.danger),
                title: Text(
                  'Supprimer la photo',
                  style: TextStyle(color: MoncarColors.danger),
                ),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'remove':
        setState(() {
          _photo = null;
          _photoChanged = true;
        });
    }
  }

  Future<void> _save() async {
    final user = ref.read(authProvider).user;
    if (user == null || _errors.isNotEmpty) return;
    setState(() => _saving = true);
    // ⚠️ MOCK : PATCH /users/me — latence simulée.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (_photoChanged) {
      ref.read(profilePhotoProvider.notifier).state = _photo;
    }
    ref
        .read(authProvider.notifier)
        .updateUser(
          user.copyWith(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            city: _city,
          ),
        );
    showMoncarToast(context, 'Informations mises à jour.', success: true);
    context.pop();
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text('Les changements non enregistrés seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MoncarColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final user = _initial;
    if (user == null) {
      return Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: const TopBar(
          title: 'Informations personnelles',
          showBack: true,
          showBell: false,
        ),
        body: Center(
          child: Text(
            'Session expirée.',
            style: TextStyle(fontSize: 14, color: MoncarColors.inkMut),
          ),
        ),
      );
    }

    final errors = _errors;
    final canSave = _dirty && errors.isEmpty && !_saving;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: MoncarColors.background,
        appBar: TopBar(
          title: 'Informations personnelles',
          showBack: true,
          showBell: false,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MoncarAvatar(
                            initials: user
                                .copyWith(
                                  firstName: _firstName.text.trim(),
                                  lastName: _lastName.text.trim(),
                                )
                                .initials,
                            size: 88,
                            image: _photo == null ? null : MemoryImage(_photo!),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: MoncarColors.brand,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_camera,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _showPhotoOptions,
                      child: Text(
                        _photo == null
                            ? 'Ajouter une photo'
                            : 'Modifier la photo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OverlineText('Identité', color: MoncarColors.inkFaint),
                  const SizedBox(height: 8),
                  MoncarCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoncarTextField(
                          label: 'Prénom',
                          controller: _firstName,
                          hint: 'ex. Aïcha',
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          error: errors['firstName'],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        MoncarTextField(
                          label: 'Nom',
                          controller: _lastName,
                          hint: 'ex. Koné',
                          maxLength: 40,
                          textCapitalization: TextCapitalization.words,
                          error: errors['lastName'],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ces informations apparaissent sur vos billets.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  OverlineText('Coordonnées', color: MoncarColors.inkFaint),
                  const SizedBox(height: 8),
                  MoncarCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoncarTextField(
                          label: 'Téléphone',
                          initialValue: user.phone,
                          prefixIcon: Icons.phone_outlined,
                          readOnly: true,
                          enabled: false,
                          suffix: Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Votre numéro sert à vous connecter. Pour le changer, '
                          'contactez le support.',
                          style: TextStyle(
                            fontSize: 11,
                            color: MoncarColors.inkFaint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MoncarTextField(
                          label: 'E-mail (optionnel)',
                          controller: _email,
                          hint: 'vous@exemple.com',
                          prefixIcon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          error: errors['email'],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        const MoncarLabel('Ville principale'),
                        InkWell(
                          onTap: _pickCity,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: MoncarColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MoncarColors.hairline),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 18,
                                  color: MoncarColors.inkMut,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _city,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: MoncarColors.ink,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more,
                                  size: 20,
                                  color: MoncarColors.inkFaint,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StickyBottomBar(
              child: MoncarButton(
                label: 'Enregistrer',
                variant: MoncarButtonVariant.primary,
                size: MoncarButtonSize.lg,
                expand: true,
                isLoading: _saving,
                onPressed: canSave ? _save : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
