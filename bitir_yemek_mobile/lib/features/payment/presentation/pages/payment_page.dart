import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../home/data/models/package_model.dart';
import '../../../home/data/models/reservation_model.dart';
import '../../../home/presentation/pages/reservation_success_page.dart';
import '../../data/datasources/payment_remote_datasource.dart';
import '../../data/models/payment_init_model.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../bloc/payment_bloc.dart';

class PaymentPage extends StatelessWidget {
  final PaymentInit payment;
  final PackageModel package;
  final ReservationModel reservation;

  const PaymentPage({
    super.key,
    required this.payment,
    required this.package,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PaymentBloc(
        repository: PaymentRepositoryImpl(
          remoteDataSource: PaymentRemoteDataSource(dioClient: appDioClient),
        ),
        conversationId: payment.conversationId ?? reservation.id,
      ),
      child: _PaymentView(
        payment: payment,
        package: package,
        reservation: reservation,
      ),
    );
  }
}

class _PaymentView extends StatefulWidget {
  final PaymentInit payment;
  final PackageModel package;
  final ReservationModel reservation;

  const _PaymentView({
    required this.payment,
    required this.package,
    required this.reservation,
  });

  @override
  State<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<_PaymentView> {
  bool _webLoading = true;

  // Backend callback/result URL'i host'tan bağımsız, path ile yakalanır (dev tüneli de çalışır).
  bool _isResultUrl(String? url) {
    if (url == null) return false;
    return url.contains('/payments/result') || url.contains('/payments/iyzico/callback');
  }

  Future<void> _handleBack(BuildContext context, bool locked) async {
    if (locked) return; // doğrulama sürerken çıkışı engelle
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödemeden vazgeç'),
        content: const Text(
          'Ödemeden vazgeçmek istediğinize emin misiniz? Rezervasyonunuz iptal edilecek.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam et')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vazgeç', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PaymentBloc>();
    final url = widget.payment.paymentPageUrl;

    return BlocConsumer<PaymentBloc, PaymentState>(
      listener: (context, state) {
        if (state is PaymentSucceeded) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReservationSuccessPage(
                reservation: widget.reservation,
                package: widget.package,
                message: 'Ödemeniz alındı, afiyet olsun!',
              ),
            ),
          );
        } else if (state is PaymentFailedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final verifying = state is PaymentVerifying;
        final pending = state is PaymentPendingState;
        final locked = verifying || pending;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack(context, locked);
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: const Text('Ödeme', style: TextStyle(color: AppColors.textPrimary)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => _handleBack(context, locked),
              ),
            ),
            body: Stack(
              children: [
                if (url != null && url.isNotEmpty)
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(url)),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: false,
                      javaScriptEnabled: true,
                      transparentBackground: true,
                    ),
                    onLoadStart: (controller, uri) {
                      if (_isResultUrl(uri?.toString())) {
                        bloc.add(const PaymentVerificationRequested());
                      }
                    },
                    onLoadStop: (controller, uri) {
                      if (mounted) setState(() => _webLoading = false);
                      if (_isResultUrl(uri?.toString())) {
                        bloc.add(const PaymentVerificationRequested());
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      if (mounted) setState(() => _webLoading = false);
                    },
                  )
                else
                  const Center(child: Text('Ödeme sayfası yüklenemedi')),

                if (_webLoading && !locked)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary)),

                if (verifying) _buildOverlay(spinner: true, title: 'Ödemeniz doğrulanıyor...'),

                if (pending) _buildPendingOverlay(context, bloc),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlay({required bool spinner, required String title}) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOverlay(BuildContext context, PaymentBloc bloc) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 64, color: AppColors.warning),
            const SizedBox(height: AppSpacing.lg),
            Text('Ödemeniz işleniyor', style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ödemeniz birkaç dakika içinde onaylanacak ve "Siparişlerim" bölümünde görünecek.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => bloc.add(const PaymentVerificationRequested()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: const Text('Tekrar kontrol et', style: AppTypography.button),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text(
                  'Siparişlerime Git',
                  style: AppTypography.button.copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
