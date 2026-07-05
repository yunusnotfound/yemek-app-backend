import 'package:equatable/equatable.dart';

/// iyzico'da saklanan kartın maskeli görünümü — PAN asla client'a gelmez.
class SavedCardModel extends Equatable {
  final String cardToken;
  final String? cardAlias;
  final String? binNumber;
  final String? lastFourDigits;
  final String? cardAssociation; // VISA / MASTER_CARD / TROY / AMERICAN_EXPRESS
  final String? cardFamily;
  final String? cardBankName;

  const SavedCardModel({
    required this.cardToken,
    this.cardAlias,
    this.binNumber,
    this.lastFourDigits,
    this.cardAssociation,
    this.cardFamily,
    this.cardBankName,
  });

  factory SavedCardModel.fromJson(Map<String, dynamic> json) {
    return SavedCardModel(
      cardToken: json['cardToken'] as String,
      cardAlias: json['cardAlias'] as String?,
      binNumber: json['binNumber'] as String?,
      lastFourDigits: json['lastFourDigits'] as String?,
      cardAssociation: json['cardAssociation'] as String?,
      cardFamily: json['cardFamily'] as String?,
      cardBankName: json['cardBankName'] as String?,
    );
  }

  String get maskedNumber => '**** ${lastFourDigits ?? '****'}';

  /// Listede gösterilecek başlık: takma ad > banka adı > marka.
  String get displayName {
    if (cardAlias != null && cardAlias!.trim().isNotEmpty) return cardAlias!;
    if (cardBankName != null && cardBankName!.trim().isNotEmpty) {
      return cardBankName!;
    }
    return brandLabel;
  }

  String get brandLabel {
    switch (cardAssociation) {
      case 'VISA':
        return 'Visa';
      case 'MASTER_CARD':
        return 'Mastercard';
      case 'TROY':
        return 'Troy';
      case 'AMERICAN_EXPRESS':
        return 'Amex';
      default:
        return 'Kart';
    }
  }

  @override
  List<Object?> get props => [
    cardToken,
    cardAlias,
    binNumber,
    lastFourDigits,
    cardAssociation,
    cardFamily,
    cardBankName,
  ];
}
