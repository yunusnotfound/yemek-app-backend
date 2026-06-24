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

  bool _isFav(FavoritesState state) =>
      state is FavoritesLoaded &&
      state.favorites.any((f) => f.businessId == businessId);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesBloc, FavoritesState>(
      buildWhen: (prev, curr) =>
          curr is FavoritesLoaded && _isFav(prev) != _isFav(curr),
      builder: (context, state) {
        final isFav = _isFav(state);
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
