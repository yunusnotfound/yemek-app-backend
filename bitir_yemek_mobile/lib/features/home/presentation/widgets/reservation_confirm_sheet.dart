import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../cards/data/datasources/cards_remote_datasource.dart';
import '../../../cards/data/models/saved_card_model.dart';
import '../../../cards/data/repositories/cards_repository_impl.dart';
import '../../../cards/presentation/bloc/cards_bloc.dart';
import '../../../cards/presentation/widgets/card_form_fields.dart';
import '../../data/models/package_model.dart';
import '../../data/models/reservation_model.dart';
import '../bloc/reservation_bloc.dart';

class ReservationConfirmSheet extends StatefulWidget {
  final PackageModel package;

  const ReservationConfirmSheet({super.key, required this.package});

  @override
  State<ReservationConfirmSheet> createState() =>
      _ReservationConfirmSheetState();
}

class _ReservationConfirmSheetState extends State<ReservationConfirmSheet> {
  // RadioGroup sentineli: "yeni kart ile öde" seçeneği (kart tokenlarıyla çakışmaz).
  static const _newCardOption = '__new_card__';

  final _couponController = TextEditingController();
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0;
  bool _couponValidating = false;
  String? _couponError;

  // Ödeme yöntemi: kayıtlı kart tokenı veya yeni kart formu.
  late final CardsBloc _cardsBloc;
  final _cardFormKey = GlobalKey<CardFormFieldsState>();
  String? _selectedCardToken;
  bool _useNewCard = false;
  bool _saveNewCard = true;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    _cardsBloc = CardsBloc(
      repository: CardsRepositoryImpl(
        remoteDataSource: CardsRemoteDataSource(dioClient: appDioClient),
      ),
    )..add(const LoadCards());
  }

  @override
  void dispose() {
    _couponController.dispose();
    _cardsBloc.close();
    super.dispose();
  }

  double get _packageDiscount =>
      widget.package.originalPrice - widget.package.discountedPrice;

  double get _totalPrice => widget.package.discountedPrice - _couponDiscount;

  bool get _isPaid => _totalPrice > 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReservationBloc, ReservationState>(
      listener: (context, state) {
        if (state is CouponValidated) {
          setState(() {
            _appliedCoupon = state.coupon;
            _couponDiscount = state.discount;
            _couponValidating = false;
            _couponError = null;
          });
        } else if (state is CouponError) {
          setState(() {
            _couponValidating = false;
            _couponError = state.message;
            _appliedCoupon = null;
            _couponDiscount = 0;
          });
        } else if (state is CouponValidating) {
          setState(() {
            _couponValidating = true;
            _couponError = null;
          });
        } else if (state is ReservationError) {
          // Kayıtlı kart bayat olabilir (iyzico'da silinmiş) -> listeyi sessizce yenile.
          _cardsBloc.add(const LoadCards(silent: true));
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPadding,
          right: AppSpacing.screenPadding,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              // Title
              Text('Rezervasyonu Onayla', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.lg),

              // Package summary
              _buildPackageSummary(),
              const SizedBox(height: AppSpacing.md),

              // Pickup info
              _buildPickupInfo(),
              const SizedBox(height: AppSpacing.lg),

              // Coupon input
              _buildCouponInput(),
              const SizedBox(height: AppSpacing.lg),

              // Payment method (yalnız ücretli siparişte)
              if (_isPaid) ...[
                _buildPaymentMethod(),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Price breakdown
              _buildPriceBreakdown(),
              const SizedBox(height: AppSpacing.lg),

              // Confirm button
              BlocBuilder<ReservationBloc, ReservationState>(
                builder: (context, state) {
                  final isLoading = state is ReservationLoading;
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _isPaid
                                  ? 'Öde ve Rezerve Et - ₺${_totalPrice.toStringAsFixed(0)}'
                                  : 'Rezerve Et - ₺${_totalPrice.toStringAsFixed(0)}',
                              style: AppTypography.button,
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageSummary() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 60,
            height: 60,
            color: AppColors.divider,
            child: AppCachedImage(
              imageUrl: widget.package.imageUrl,
              fit: BoxFit.cover,
              placeholder: Icon(Icons.restaurant, color: AppColors.textHint),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.package.title,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.package.business.name,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickupInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Bugun, ${widget.package.formattedPickupTime}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.package.business.address,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kupon Kodu (opsiyonel)',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponController,
                enabled: _appliedCoupon == null,
                decoration: InputDecoration(
                  hintText: 'Kupon kodunu girin',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (_appliedCoupon != null)
              IconButton(
                onPressed: () {
                  setState(() {
                    _appliedCoupon = null;
                    _couponDiscount = 0;
                    _couponController.clear();
                    _couponError = null;
                  });
                },
                icon: const Icon(Icons.close, color: AppColors.error),
              )
            else
              ElevatedButton(
                onPressed: _couponValidating ? null : _onValidateCoupon,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                ),
                child: _couponValidating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Uygula'),
              ),
          ],
        ),
        if (_couponError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _couponError!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        if (_appliedCoupon != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Kupon uygulandi!',
              style: AppTypography.bodySmall.copyWith(color: AppColors.success),
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Odeme Yontemi',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textHint,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BlocConsumer<CardsBloc, CardsState>(
          bloc: _cardsBloc,
          listener: (context, state) {
            if (state is CardsLoaded) {
              setState(() {
                // Seçili kart artık listede yoksa (silinmiş) seçimi düşür.
                if (_selectedCardToken != null &&
                    !state.cards.any((c) => c.cardToken == _selectedCardToken)) {
                  _selectedCardToken = null;
                }
                if (state.cards.isEmpty) {
                  _useNewCard = true;
                } else if (_selectedCardToken == null && !_useNewCard) {
                  _selectedCardToken = state.cards.first.cardToken;
                }
              });
            } else if (state is CardsError) {
              // Kart listesi alınamadı — ödeme bloklanmasın, yeni kart formuna düş.
              setState(() => _useNewCard = true);
            }
          },
          builder: (context, state) {
            if (state is CardsLoading || state is CardsInitial) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final cards = state is CardsLoaded
                ? state.cards
                : const <SavedCardModel>[];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: RadioGroup<String>(
                groupValue: _useNewCard ? _newCardOption : _selectedCardToken,
                onChanged: (v) => setState(() {
                  _useNewCard = v == _newCardOption;
                  if (!_useNewCard) _selectedCardToken = v;
                  _paymentError = null;
                }),
                child: Column(
                  children: [
                    for (final card in cards) ...[
                      RadioListTile<String>(
                        value: card.cardToken,
                        dense: true,
                        activeColor: AppColors.primary,
                        title: Text(
                          '${card.displayName} ${card.maskedNumber}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        secondary: const Icon(
                          Icons.credit_card,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                    RadioListTile<String>(
                      value: _newCardOption,
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        cards.isEmpty ? 'Kart ile ode' : 'Yeni kart ile ode',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.add_card,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    if (_useNewCard)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: Column(
                          children: [
                            CardFormFields(
                              key: _cardFormKey,
                              requireCvc: true,
                              showAlias: false,
                            ),
                            CheckboxListTile(
                              value: _saveNewCard,
                              onChanged: (v) =>
                                  setState(() => _saveNewCard = v ?? false),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                              title: Text(
                                'Kartimi sonraki siparisler icin kaydet',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_paymentError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _paymentError!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _buildPriceRow(
            'Paket fiyati',
            '₺${widget.package.originalPrice.toStringAsFixed(0)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildPriceRow(
            'Indirim',
            '-₺${_packageDiscount.toStringAsFixed(0)}',
            valueColor: AppColors.success,
          ),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildPriceRow(
              'Kupon indirimi',
              '-₺${_couponDiscount.toStringAsFixed(0)}',
              valueColor: AppColors.success,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _buildPriceRow(
            'Toplam',
            '₺${_totalPrice.toStringAsFixed(0)}',
            isBold: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)
              : AppTypography.bodyMedium,
        ),
        Text(
          value,
          style:
              (isBold
                      ? AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        )
                      : AppTypography.bodyMedium)
                  .copyWith(color: valueColor),
        ),
      ],
    );
  }

  void _onValidateCoupon() {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    context.read<ReservationBloc>().add(
      ValidateCoupon(code: code, orderTotal: widget.package.discountedPrice),
    );
  }

  void _onConfirm() {
    Map<String, dynamic>? paymentCard;

    if (_isPaid) {
      if (_useNewCard) {
        final data = _cardFormKey.currentState?.validateAndRead();
        if (data == null) return; // form hataları alanlarda gösterilir
        paymentCard = {
          'cardHolderName': data.cardHolderName,
          'cardNumber': data.cardNumber,
          'expireMonth': data.expireMonth,
          'expireYear': data.expireYear,
          'cvc': data.cvc,
          'saveCard': _saveNewCard,
        };
      } else if (_selectedCardToken != null) {
        paymentCard = {'savedCardToken': _selectedCardToken};
      } else {
        setState(() => _paymentError = 'Lutfen bir odeme yontemi secin');
        return;
      }
    }

    context.read<ReservationBloc>().add(
      CreateReservation(
        packageId: widget.package.id,
        couponCode: _appliedCoupon?.code,
        paymentCard: paymentCard,
      ),
    );
  }
}
