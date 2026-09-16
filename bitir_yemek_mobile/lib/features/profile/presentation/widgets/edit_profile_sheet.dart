import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class EditProfileSheet extends StatefulWidget {
  final String currentName;
  final String? currentPhone;
  final void Function(String name, String? phone) onSave;

  const EditProfileSheet({
    super.key,
    required this.currentName,
    this.currentPhone,
    required this.onSave,
  });

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Profili Düzenle', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.lg),
            // Name field
            Text(
              'Ad Soyad',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Adınızı girin',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ad alanı boş bırakılamaz';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            // Phone field
            Text(
              'Telefon',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                hintText: '5XX XXX XX XX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.lg),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSave,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSave() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text.trim();
      widget.onSave(_nameController.text.trim(), phone.isEmpty ? null : phone);
      Navigator.of(context).pop();
    }
  }
}
