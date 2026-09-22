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
  final Color inactiveColor;
  final Color activeColor;
  final Color? backgroundColor;

  const FavoriteButton({
    super.key,
    required this.businessId,
    this.size = 22,
    this.inactiveColor = AppColors.textHint,
    this.activeColor = AppColors.error,
    this.backgroundColor,
  });

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
        return Semantics(
          label: isFav ? 'Favorilerden çıkar' : 'Favorilere ekle',
          button: true,
          child: InkResponse(
            onTap: () => context.read<FavoritesBloc>().add(
              ToggleFavorite(businessId: businessId),
            ),
            radius: 24,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: size + 10,
                  height: size + 10,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: size,
                    color: isFav ? activeColor : inactiveColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
