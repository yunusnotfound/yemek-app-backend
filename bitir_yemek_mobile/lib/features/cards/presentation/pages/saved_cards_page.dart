import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/datasources/cards_remote_datasource.dart';
import '../../data/models/saved_card_model.dart';
import '../../data/repositories/cards_repository_impl.dart';
import '../bloc/cards_bloc.dart';
import '../widgets/add_card_sheet.dart';

class SavedCardsPage extends StatelessWidget {
  const SavedCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CardsBloc(
        repository: CardsRepositoryImpl(
          remoteDataSource: CardsRemoteDataSource(dioClient: appDioClient),
        ),
      )..add(const LoadCards()),
      child: const _SavedCardsView(),
    );
  }
}

class _SavedCardsView extends StatelessWidget {
  const _SavedCardsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kayitli Kartlarim')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCardSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Kart Ekle'),
      ),
      body: BlocConsumer<CardsBloc, CardsState>(
        listener: (context, state) {
          if (state is CardActionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CardsLoading || state is CardsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CardsError) {
            return _buildError(context, state.message);
          }
          final cards = switch (state) {
            CardsLoaded(:final cards) => cards,
            CardAdding(:final cards) => cards,
            _ => const <SavedCardModel>[],
          };
          if (cards.isEmpty) {
            return _buildEmpty(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _SavedCardTile(card: cards[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Henuz kayitli kartiniz yok', style: AppTypography.bodyLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Kart ekleyin, odemelerinizi tek dokunusla tamamlayin.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTypography.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<CardsBloc>().add(const LoadCards()),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardSheet(BuildContext context) {
    final bloc = context.read<CardsBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => AddCardSheet(cardsBloc: bloc),
    );
  }
}

class _SavedCardTile extends StatelessWidget {
  final SavedCardModel card;

  const _SavedCardTile({required this.card});

  IconData get _brandIcon {
    switch (card.cardAssociation) {
      case 'VISA':
      case 'MASTER_CARD':
      case 'TROY':
      case 'AMERICAN_EXPRESS':
        return Icons.credit_card;
      default:
        return Icons.credit_card_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(_brandIcon, color: AppColors.primary),
        ),
        title: Text(
          card.displayName,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${card.brandLabel} ${card.maskedNumber}',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final bloc = context.read<CardsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Karti Sil'),
        content: Text(
          '${card.displayName} (${card.maskedNumber}) kartini silmek istediginize emin misiniz?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(DeleteCard(cardToken: card.cardToken));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
