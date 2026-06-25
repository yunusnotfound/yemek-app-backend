import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../bloc/favorites_bloc.dart';

/// İşletmenin favori durumunu kendi içinde izleyip değiştiren bağımsız buton.
///
/// Yalnız KENDİ id'sinin favori durumu değiştiğinde yeniden çizilir; bu sayede
/// favori değiştirmek tüm listeyi/kartları değil sadece ilgili kalbi rebuild eder.
class FavoriteButton extends StatelessWidget {
  final String businessId;
  final double size;

  const FavoriteButton({super.key, required this.businessId, this.size = 22});

  @override
  Widget build(BuildContext context) {
    // Favori durumunu bloc'un her zaman güncel olan _favorites listesinden
    // (isFavorite getter) okuyoruz. BlocSelector her emit'te yeniden hesaplar
    // ama yalnız bu işletmenin boolean değeri değiştiğinde rebuild eder; araya
    // giren marker state'ler (FavoriteAddSuccess/RemoveSuccess) değeri bozmaz,
    // böylece ekleme ve çıkarma anında yansır.
    return BlocSelector<FavoritesBloc, FavoritesState, bool>(
      selector: (_) => context.read<FavoritesBloc>().isFavorite(businessId),
      builder: (context, isFav) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context
              .read<FavoritesBloc>()
              .add(ToggleFavorite(businessId: businessId)),
          child: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            size: size,
            color: isFav ? AppColors.error : AppColors.textHint,
          ),
        );
      },
    );
  }
}
