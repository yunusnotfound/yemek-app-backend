import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Girilen kart bilgileri (submit anında okunur).
class CardFormData {
  final String cardHolderName;
  final String cardNumber; // yalnız rakamlar
  final String expireMonth; // 'MM'
  final String expireYear; // '20YY'
  final String? cvc;
  final String? cardAlias;

  const CardFormData({
    required this.cardHolderName,
    required this.cardNumber,
    required this.expireMonth,
    required this.expireYear,
    this.cvc,
    this.cardAlias,
  });
}

/// Kart bilgisi form alanları — profildeki "kart ekle" ve rezervasyon
/// sheet'indeki "yeni kartla öde" tarafından paylaşılır.
/// [requireCvc] yalnız ödeme bağlamında true olur (profilde CVV alınmaz).
class CardFormFields extends StatefulWidget {
  final bool requireCvc;
  final bool showAlias;

  const CardFormFields({
    super.key,
    this.requireCvc = false,
    this.showAlias = true,
  });

  @override
  State<CardFormFields> createState() => CardFormFieldsState();
}

class CardFormFieldsState extends State<CardFormFields> {
  final _formKey = GlobalKey<FormState>();
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _aliasController = TextEditingController();

  @override
  void dispose() {
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  /// Form geçerliyse veriyi döndürür, değilse hataları gösterip null döner.
  CardFormData? validateAndRead() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final expiry = _expiryController.text.split('/');
    return CardFormData(
      cardHolderName: _holderController.text.trim(),
      cardNumber: _numberController.text.replaceAll(' ', ''),
      expireMonth: expiry[0],
      expireYear: '20${expiry[1]}',
      cvc: widget.requireCvc ? _cvcController.text : null,
      cardAlias: _aliasController.text.trim().isEmpty
          ? null
          : _aliasController.text.trim(),
    );
  }

  static bool _luhnOk(String digits) {
    var sum = 0;
    var dbl = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var d = digits.codeUnitAt(i) - 48;
      if (dbl) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      dbl = !dbl;
    }
    return sum % 10 == 0;
  }

  String? _validateNumber(String? value) {
    final digits = (value ?? '').replaceAll(' ', '');
    if (digits.length < 12 || !_luhnOk(digits)) {
      return 'Gecerli bir kart numarasi girin';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    final v = value ?? '';
    final match = RegExp(r'^(0[1-9]|1[0-2])\/(\d{2})$').firstMatch(v);
    if (match == null) return 'AA/YY formatinda girin';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    final now = DateTime.now();
    // Kartlar ayın son gününe kadar geçerlidir.
    if (DateTime(year, month + 1, 0).isBefore(DateTime(now.year, now.month, 1))) {
      return 'Kartin suresi dolmus';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _holderController,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const [AutofillHints.creditCardName],
            decoration: const InputDecoration(
              labelText: 'Kart uzerindeki isim',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v ?? '').trim().length < 2 ? 'Kart uzerindeki isim gerekli' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.creditCardNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Kart numarasi',
              hintText: '0000 0000 0000 0000',
              prefixIcon: Icon(Icons.credit_card),
            ),
            validator: _validateNumber,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.creditCardExpirationDate],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'SKT',
                    hintText: 'AA/YY',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  validator: _validateExpiry,
                ),
              ),
              if (widget.requireCvc) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autofillHints: const [AutofillHints.creditCardSecurityCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{3,4}$').hasMatch(v ?? '') ? null : 'CVV gerekli',
                  ),
                ),
              ],
            ],
          ),
          if (widget.showAlias) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _aliasController,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
              decoration: const InputDecoration(
                labelText: 'Kart takma adi (istege bagli)',
                hintText: 'Orn: Is kartim',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rakamları '#### #### #### ####' olarak gruplar.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 'AAYY' girişini 'AA/YY' olarak biçimlendirir.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll('/', '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
