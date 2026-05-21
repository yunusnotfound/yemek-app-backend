import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/datasources/business_owner_remote_datasource.dart';
import '../../data/repositories/business_owner_repository_impl.dart';

class VerifyOrderPage extends StatefulWidget {
  final String businessId;
  final String? prefillCode;

  const VerifyOrderPage({
    super.key,
    required this.businessId,
    this.prefillCode,
  });

  @override
  State<VerifyOrderPage> createState() => _VerifyOrderPageState();
}

class _VerifyOrderPageState extends State<VerifyOrderPage> {
  late final TextEditingController _codeController;
  late final BusinessOwnerRepositoryImpl _repository;
  bool _loading = false;
  Map<String, dynamic>? _successResult;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.prefillCode ?? '');
    final tokenStorage = createDefaultTokenStorage();
    _repository = BusinessOwnerRepositoryImpl(
      remoteDataSource: BusinessOwnerRemoteDataSource(
        dioClient: DioClient(tokenStorage: tokenStorage),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen teslim alma kodunu girin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _successResult = null;
    });

    try {
      final result = await _repository.verifyOrder(widget.businessId, code);
      if (mounted) {
        setState(() {
          _loading = false;
          _successResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
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
        title: const Text('Sipariş Doğrula'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: _successResult != null ? _buildSuccessView() : _buildInputView(),
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),

        // Icon
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner,
              size: 40,
              color: AppColors.primary,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Center(
          child: Text(
            'Teslim Alma Kodunu Girin',
            style: AppTypography.h3,
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Center(
          child: Text(
            'Müşterinin sipariş onay kodunu girin ve doğrulayın.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Code input
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '• • • •',
            hintStyle: TextStyle(
              fontSize: 28,
              letterSpacing: 8,
              color: AppColors.textHint,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _verify(),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _verify,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_loading ? 'Doğrulanıyor...' : 'Doğrula'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final order = _successResult!['order'] as Map<String, dynamic>?;
    final user = order?['user'] as Map<String, dynamic>?;
    final pkg = order?['package'] as Map<String, dynamic>?;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 56,
            color: AppColors.success,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        Text(
          'Sipariş Doğrulandı!',
          style: AppTypography.h2.copyWith(color: AppColors.success),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(
          'Sipariş başarıyla teslim alındı olarak işaretlendi.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Order info card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (user != null)
                _infoRow(
                  Icons.person_outline,
                  'Müşteri',
                  user['name']?.toString() ?? '',
                ),
              if (pkg != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _infoRow(
                  Icons.inventory_2_outlined,
                  'Paket',
                  pkg['title']?.toString() ?? '',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),

        // Done button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tamam'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
