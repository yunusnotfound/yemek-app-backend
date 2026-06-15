import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/datasources/business_owner_remote_datasource.dart';
import '../../data/models/owner_package_model.dart';
import '../../data/repositories/business_owner_repository_impl.dart';
import '../bloc/owner_packages_bloc.dart';

class PackageFormPage extends StatefulWidget {
  final String businessId;
  final OwnerPackageModel? package; // null = create, non-null = edit

  const PackageFormPage({super.key, required this.businessId, this.package});

  @override
  State<PackageFormPage> createState() => _PackageFormPageState();
}

class _PackageFormPageState extends State<PackageFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _originalPriceController;
  late final TextEditingController _discountedPriceController;
  late final TextEditingController _quantityController;

  DateTime? _pickupDate;
  TimeOfDay? _pickupStart;
  TimeOfDay? _pickupEnd;
  bool _isActive = true;
  bool _submitting = false;

  bool get _isEdit => widget.package != null;

  @override
  void initState() {
    super.initState();
    final p = widget.package;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _originalPriceController = TextEditingController(
      text: p != null ? p.originalPrice.toStringAsFixed(2) : '',
    );
    _discountedPriceController = TextEditingController(
      text: p != null ? p.discountedPrice.toStringAsFixed(2) : '',
    );
    _quantityController = TextEditingController(
      text: p != null ? '${p.quantity}' : '',
    );

    if (p != null) {
      _isActive = p.isActive;
      // Parse pickupDate: "2024-01-15"
      try {
        final parts = p.pickupDate.split('-');
        _pickupDate = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } catch (_) {}
      // Parse pickupStart/End: "18:00:00" or "18:00"
      _pickupStart = _parseTime(p.pickupStart);
      _pickupEnd = _parseTime(p.pickupEnd);
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickupDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _pickupDate = picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_pickupStart ?? const TimeOfDay(hour: 18, minute: 0))
        : (_pickupEnd ?? const TimeOfDay(hour: 21, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _pickupStart = picked;
        } else {
          _pickupEnd = picked;
        }
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Paketi Düzenle' : 'Yeni Paket'),
        backgroundColor: AppColors.background,
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Paket adı *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Açıklama (isteğe bağlı)',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _sectionLabel('Fiyatlandırma'),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Normal fiyat *',
                        suffixText: '₺',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (double.tryParse(v) == null) return 'Geçersiz';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _discountedPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'İndirimli fiyat *',
                        suffixText: '₺',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Gerekli';
                        if (double.tryParse(v) == null) return 'Geçersiz';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Quantity
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Adet *',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gerekli';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'En az 1 olmalı';
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),
              _sectionLabel('Teslim Alma'),
              const SizedBox(height: AppSpacing.sm),

              // Pickup date
              _DateTile(
                label: 'Tarih',
                value: _pickupDate != null
                    ? _formatDate(_pickupDate!)
                    : 'Tarih seçin *',
                icon: Icons.calendar_today_outlined,
                hasValue: _pickupDate != null,
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.sm),

              Row(
                children: [
                  Expanded(
                    child: _DateTile(
                      label: 'Başlangıç',
                      value: _pickupStart != null
                          ? _formatTime(_pickupStart!)
                          : 'Başlangıç *',
                      icon: Icons.schedule,
                      hasValue: _pickupStart != null,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DateTile(
                      label: 'Bitiş',
                      value: _pickupEnd != null
                          ? _formatTime(_pickupEnd!)
                          : 'Bitiş *',
                      icon: Icons.schedule,
                      hasValue: _pickupEnd != null,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),

              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('Durum'),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isActive ? 'Aktif' : 'Pasif',
                      style: AppTypography.bodyMedium,
                    ),
                    subtitle: Text(
                      _isActive
                          ? 'Paket müşterilere görünür'
                          : 'Paket müşterilere gizli',
                      style: AppTypography.bodySmall,
                    ),
                    value: _isActive,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),

              // Submit
              _SubmitButton(
                isEdit: _isEdit,
                submitting: _submitting,
                businessId: widget.businessId,
                packageId: widget.package?.id,
                getFormData: () => ({
                  'title': _titleController.text.trim(),
                  'description': _descriptionController.text.trim(),
                  'originalPrice':
                      double.tryParse(_originalPriceController.text.trim()) ??
                      0.0,
                  'discountedPrice':
                      double.tryParse(_discountedPriceController.text.trim()) ??
                      0.0,
                  'quantity':
                      int.tryParse(_quantityController.text.trim()) ?? 1,
                  'pickupDate': _pickupDate != null
                      ? _formatDate(_pickupDate!)
                      : '',
                  'pickupStart': _pickupStart != null
                      ? _formatTime(_pickupStart!)
                      : '',
                  'pickupEnd': _pickupEnd != null
                      ? _formatTime(_pickupEnd!)
                      : '',
                  'isActive': _isActive,
                }),
                validate: () {
                  if (!(_formKey.currentState?.validate() ?? false)) {
                    return false;
                  }
                  if (_pickupDate == null ||
                      _pickupStart == null ||
                      _pickupEnd == null) {
                    _showError('Teslim alma bilgilerini doldurun');
                    return false;
                  }
                  final op =
                      double.tryParse(_originalPriceController.text.trim()) ??
                      0;
                  final dp =
                      double.tryParse(_discountedPriceController.text.trim()) ??
                      0;
                  if (dp >= op) {
                    _showError(
                      'İndirimli fiyat, orijinal fiyattan küçük olmalı',
                    );
                    return false;
                  }
                  final sm = _pickupStart!.hour * 60 + _pickupStart!.minute;
                  final em = _pickupEnd!.hour * 60 + _pickupEnd!.minute;
                  if (em <= sm) {
                    _showError('Bitiş saati, başlangıç saatinden sonra olmalı');
                    return false;
                  }
                  return true;
                },
                onSetSubmitting: (v) => setState(() => _submitting = v),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: AppTypography.bodySmall.copyWith(
      color: AppColors.textHint,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool hasValue;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasValue ? AppColors.primary : Colors.transparent,
            width: hasValue ? 1.5 : 0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: hasValue ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful submit button that calls the repository directly
class _SubmitButton extends StatefulWidget {
  final bool isEdit;
  final bool submitting;
  final String businessId;
  final String? packageId;
  final Map<String, dynamic> Function() getFormData;
  final bool Function() validate;
  final void Function(bool) onSetSubmitting;

  const _SubmitButton({
    required this.isEdit,
    required this.submitting,
    required this.businessId,
    this.packageId,
    required this.getFormData,
    required this.validate,
    required this.onSetSubmitting,
  });

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton> {
  late final BusinessOwnerRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    final tokenStorage = createDefaultTokenStorage();
    _repository = BusinessOwnerRepositoryImpl(
      remoteDataSource: BusinessOwnerRemoteDataSource(
        dioClient: DioClient(tokenStorage: tokenStorage),
      ),
    );
  }

  Future<void> _onPressed() async {
    if (!widget.validate()) return;
    widget.onSetSubmitting(true);
    final data = widget.getFormData();
    try {
      if (widget.isEdit && widget.packageId != null) {
        await _repository.updatePackage(
          widget.packageId!,
          title: data['title'] as String,
          description: (data['description'] as String).isEmpty
              ? null
              : data['description'] as String,
          originalPrice: data['originalPrice'] as double,
          discountedPrice: data['discountedPrice'] as double,
          quantity: data['quantity'] as int,
          pickupStart: data['pickupStart'] as String,
          pickupEnd: data['pickupEnd'] as String,
          pickupDate: data['pickupDate'] as String,
          isActive: data['isActive'] as bool,
        );
      } else {
        await _repository.createPackage(
          businessId: widget.businessId,
          title: data['title'] as String,
          description: (data['description'] as String).isEmpty
              ? null
              : data['description'] as String,
          originalPrice: data['originalPrice'] as double,
          discountedPrice: data['discountedPrice'] as double,
          quantity: data['quantity'] as int,
          pickupStart: data['pickupStart'] as String,
          pickupEnd: data['pickupEnd'] as String,
          pickupDate: data['pickupDate'] as String,
        );
      }

      if (mounted) {
        // Trigger refresh in bloc
        context.read<OwnerPackagesBloc>().add(const RefreshPackages());
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      widget.onSetSubmitting(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: widget.submitting ? null : _onPressed,
        child: widget.submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(widget.isEdit ? 'Güncelle' : 'Paket Oluştur'),
      ),
    );
  }
}
