import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../bloc/cards_bloc.dart';
import 'card_form_fields.dart';

/// Profil > Kayitli Kartlarim'dan kart ekleme bottom sheet'i (CVV alınmaz —
/// kart yalnız iyzico cüzdanına kaydedilir, tahsilat yapılmaz).
class AddCardSheet extends StatefulWidget {
  final CardsBloc cardsBloc;

  const AddCardSheet({super.key, required this.cardsBloc});

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  final _formFieldsKey = GlobalKey<CardFormFieldsState>();

  void _submit() {
    final data = _formFieldsKey.currentState?.validateAndRead();
    if (data == null) return;
    widget.cardsBloc.add(
      AddCard(
        cardHolderName: data.cardHolderName,
        cardNumber: data.cardNumber,
        expireMonth: data.expireMonth,
        expireYear: data.expireYear,
        cardAlias: data.cardAlias,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cardsBloc,
      child: BlocListener<CardsBloc, CardsState>(
        listener: (context, state) {
          if (state is CardAdded) {
            Navigator.of(context).pop();
            AppNotice.success(context, 'Kart kaydedildi');
          } else if (state is CardActionError) {
            AppNotice.error(context, state.message);
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Yeni Kart Ekle', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.md),
                CardFormFields(key: _formFieldsKey),
                const SizedBox(height: AppSpacing.lg),
                BlocBuilder<CardsBloc, CardsState>(
                  builder: (context, state) {
                    final isAdding = state is CardAdding;
                    return SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isAdding ? null : _submit,
                        child: isAdding
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Karti Kaydet'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
