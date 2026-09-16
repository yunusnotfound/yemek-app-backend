import 'order_quantity_selector.dart';
import '../../../../core/utils/money_format.dart';
import '../../../coupons/presentation/coupons_page.dart';
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
  final CouponModel? initialCoupon;
  final int initialQuantity;

  const ReservationConfirmSheet({
    super.key,
    required this.package,
    this.initialCoupon,
    this.initialQuantity = 1,
  });

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
  bool _submitting = false;
  late int _quantity;
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
    _quantity = widget.initialQuantity.clamp(
      1,
      widget.package.remainingQuantity.clamp(1, 100),
    );
    if (widget.initialCoupon != null) {
      _couponController.text = widget.initialCoupon!.code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onValidateCoupon();
      });
    }
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

  double get _baseTotal =>
      (widget.package.discountedPrice * 100).round() * _quantity / 100;
  double get _originalTotal =>
      (widget.package.originalPrice * 100).round() * _quantity / 100;
  double get _packageDiscount => _originalTotal - _baseTotal;
  double get _totalPrice =>
      ((_baseTotal * 100).round() - (_couponDiscount * 100).round()).clamp(
        0,
        (_baseTotal * 100).round(),
      ) /
      100;

  void _changeQuantity(int value) {
    if (_couponValidating || _submitting) return;
    final code = _appliedCoupon?.code;
    setState(() {
      _quantity = value;
      _appliedCoupon = null;
      _couponDiscount = 0;
      _couponError = null;
    });
    if (code != null) {
      _couponController.text = code;
      _onValidateCoupon();
    }
  }

  bool get _isPaid => _totalPrice > 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReservationBloc, ReservationState>(
      listener: (context, state) {
        if (state is ReservationLoading) {
          setState(() => _submitting = true);
        } else if (state is CouponValidated) {
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
          setState(() => _submitting = false);
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

              // Başlık + kapat
              Row(
                children: [
                  Expanded(
                    child: Text('Rezervasyonu Onayla', style: AppTypography.h3),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.close,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Package summary
              _buildPackageSummary(),
              const SizedBox(height: AppSpacing.md),

              OrderQuantitySelector(
                quantity: _quantity,
                maximum: widget.package.remainingQuantity.clamp(1, 100),
                enabled: !_submitting && !_couponValidating,
                onChanged: _changeQuantity,
              ),
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
                      onPressed: isLoading || _submitting || _couponValidating
                          ? null
                          : _onConfirm,
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
                                  ? 'Öde ve Rezerve Et - ${formatMoney(_totalPrice)}'
                                  : 'Rezerve Et - ${formatMoney(_totalPrice)}',
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
                'Teslim saati, ${widget.package.formattedPickupTime}',
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _submitting || _couponValidating
                ? null
                : () async {
                    final selected = await openCoupons(
                      context,
                      package: widget.package,
                      quantity: _quantity,
                    );
                    if (!mounted || selected == null) return;
                    _couponController.text = selected.code;
                    _onValidateCoupon();
                  },
            icon: const Icon(Icons.confirmation_number_outlined),
            label: const Text('Kuponlarımdan seç'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppDepth.border),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Kupon kodu',
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
                enabled:
                    _appliedCoupon == null &&
                    !_submitting &&
                    !_couponValidating,
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
                onPressed: _submitting
                    ? null
                    : () {
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
                onPressed: _submitting || _couponValidating
                    ? null
                    : _onValidateCoupon,
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
              'Kupon uygulandı',
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
          'Ödeme Yontemi',
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
                    !state.cards.any(
                      (c) => c.cardToken == _selectedCardToken,
                    )) {
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
          _buildPriceRow('Paket fiyatı', formatMoney(_originalTotal)),
          const SizedBox(height: AppSpacing.sm),
          _buildPriceRow(
            'Paket indirimi',
            '-${formatMoney(_packageDiscount)}',
            valueColor: AppColors.success,
          ),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildPriceRow(
              'Kupon indirimi',
              '-${formatMoney(_couponDiscount)}',
              valueColor: AppColors.success,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _buildPriceRow(
            'Toplam',
            formatMoney(_totalPrice),
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
    if (code.isEmpty || _couponValidating || _submitting) return;
    setState(() => _couponValidating = true);

    context.read<ReservationBloc>().add(
      ValidateCoupon(
        code: code,
        orderTotal: _baseTotal,
        quantity: _quantity,
        packageId: widget.package.id,
      ),
    );
  }

  void _onConfirm() {
    if (_submitting || _couponValidating) return;
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
        setState(() => _paymentError = 'Lütfen bir ödeme yöntemi seçin');
        return;
      }
    }

    setState(() => _submitting = true);
    context.read<ReservationBloc>().add(
      CreateReservation(
        packageId: widget.package.id,
        quantity: _quantity,
        couponCode: _appliedCoupon?.code,
        expectedFinalPrice: _totalPrice,
        paymentCard: paymentCard,
      ),
    );
  }
}
