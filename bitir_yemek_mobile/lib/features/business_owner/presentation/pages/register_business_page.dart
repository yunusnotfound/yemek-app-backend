import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../data/datasources/business_owner_remote_datasource.dart';
import '../../data/models/owner_business_model.dart';
import '../../data/repositories/business_owner_repository_impl.dart';

class RegisterBusinessPage extends StatefulWidget {
  const RegisterBusinessPage({super.key});

  @override
  State<RegisterBusinessPage> createState() => _RegisterBusinessPageState();
}

class _RegisterBusinessPageState extends State<RegisterBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _phoneController = TextEditingController();

  List<OwnerCategoryModel> _categories = [];
  int? _selectedCategoryId;
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  bool _submitting = false;
  bool _loadingCategories = true;
  String? _locationError;

  late final BusinessOwnerRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    _repository = BusinessOwnerRepositoryImpl(
      remoteDataSource: BusinessOwnerRemoteDataSource(
        dioClient: appDioClient,
      ),
    );
    _loadCategories();
    _fetchLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    final locationService = LocationService();
    final position = await locationService.getCurrentPosition();
    if (mounted) {
      if (position != null) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationLoading = false;
        });
      } else {
        setState(() {
          _locationLoading = false;
          _locationError = 'Konum alınamadı. Lütfen konum izni verin.';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kategori seçin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum bilgisi alınması gerekiyor'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _repository.createBusiness(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        categoryId: _selectedCategoryId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İşletmeniz oluşturuldu! Onay sürecindeyken siparişlere kapalıdır.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true); // pop with true = business created
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('İşletme Ekle'),
        backgroundColor: AppColors.background,
      ),
      body: _loadingCategories
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Temel Bilgiler
                    _sectionLabel('Temel Bilgiler'),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'İşletme adı *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ad gerekli' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Açıklama (isteğe bağlı)',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Category dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        hintText: 'Kategori *',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'Kategori seçin' : null,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('İletişim'),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Telefon (isteğe bağlı)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('Adres'),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        hintText: 'Adres *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Adres gerekli'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              hintText: 'Şehir *',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Şehir gerekli'
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: _districtController,
                            decoration: const InputDecoration(
                              hintText: 'İlçe *',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'İlçe gerekli'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _sectionLabel('Konum (GPS)'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildLocationTile(),

                    const SizedBox(height: AppSpacing.xxl),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('İşletme Oluştur'),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'İşletmeniz oluşturulduktan sonra yönetici onayı bekleme sürecine girecektir.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTypography.bodySmall.copyWith(
        color: AppColors.textHint,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          if (_locationLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else if (_locationError != null)
            const Icon(Icons.location_off, color: AppColors.error, size: 20)
          else
            const Icon(Icons.my_location, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _locationLoading
                  ? 'Konum alınıyor...'
                  : _locationError != null
                  ? _locationError!
                  : 'Lat: ${_latitude?.toStringAsFixed(5)}, Lng: ${_longitude?.toStringAsFixed(5)}',
              style: AppTypography.bodySmall.copyWith(
                color: _locationError != null
                    ? AppColors.error
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (!_locationLoading && _locationError != null)
            TextButton(
              onPressed: _fetchLocation,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Tekrar Dene'),
            ),
        ],
      ),
    );
  }
}
