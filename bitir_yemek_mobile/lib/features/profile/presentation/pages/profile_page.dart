import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/pages/email_entry_page.dart';
import '../../../cards/presentation/pages/saved_cards_page.dart';
import 'notifications_page.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_menu_item.dart';

class ProfilePage extends StatelessWidget {
  final void Function(int)? onTabSwitch;

  const ProfilePage({super.key, this.onTabSwitch});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoggedOut || state is AccountDeleted) {
          // Çıkış yapan kullanıcı tanıtımı zaten görmüştür; doğrudan girişe
          // götürülür. (Hesap silmede de aynı: cihazda bir kez giriş yapılmış
          // olması değişmiyor.)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmailEntryPage()),
            (route) => false,
          );
        } else if (state is ProfileUpdateSuccess) {
          AppNotice.success(context, state.message);
        } else if (state is ProfileUpdateError) {
          AppNotice.error(context, state.message);
        } else if (state is AccountDeleteError) {
          AppNotice.error(context, state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ProfileState state) {
    if (state is ProfileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ProfileError) {
      return _buildErrorState(context, state.message);
    }

    final user = _getUserFromState(state);
    if (user == null) {
      return _buildErrorState(context, 'Profil yuklenemedi');
    }

    final isUpdating = state is ProfileUpdating;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            ProfileHeader(user: user),

            // Edit button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isUpdating
                      ? null
                      : () => _showEditSheet(context, user),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Profili Duzenle'),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Account section
            _buildSection(
              context,
              title: 'Hesap',
              children: [
                ProfileMenuItem(
                  icon: Icons.person_outline,
                  title: 'Kisisel Bilgiler',
                  subtitle: user.name,
                  onTap: () => _showEditSheet(context, user),
                ),
                ProfileMenuItem(
                  icon: Icons.email_outlined,
                  title: 'E-posta',
                  subtitle: user.email,
                  trailing: user.isEmailVerified
                      ? const Icon(
                          Icons.verified,
                          color: AppColors.success,
                          size: 20,
                        )
                      : const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                ),
                ProfileMenuItem(
                  icon: Icons.phone_outlined,
                  title: 'Telefon',
                  subtitle: user.phone ?? 'Belirtilmemis',
                  onTap: () => _showEditSheet(context, user),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Settings section
            _buildSection(
              context,
              title: 'Ayarlar',
              children: [
                ProfileMenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Bildirimler',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
                ProfileMenuItem(
                  icon: Icons.credit_card_outlined,
                  title: 'Kayitli Kartlarim',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedCardsPage()),
                  ),
                ),
                ProfileMenuItem(
                  icon: Icons.info_outline,
                  title: 'Hakkinda',
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Logout button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.error,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Cikis Yap',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Delete account
            TextButton(
              onPressed: () => _showDeleteAccountDialog(context),
              child: Text(
                'Hesabi Sil',
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              title,
              style: AppTypography.caption.copyWith(
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
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
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 72,
                      color: AppColors.divider,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProfileBloc>().add(ProfileLogoutRequested());
              },
              icon: const Icon(Icons.login),
              label: const Text('Tekrar Giris Yap'),
            ),
          ],
        ),
      ),
    );
  }

  UserModel? _getUserFromState(ProfileState state) {
    if (state is ProfileLoaded) return state.user;
    if (state is ProfileUpdating) return state.user;
    if (state is ProfileUpdateSuccess) return state.user;
    if (state is ProfileUpdateError) return state.user;
    return null;
  }

  void _showEditSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => EditProfileSheet(
        currentName: user.name,
        currentPhone: user.phone,
        onSave: (name, phone) {
          context.read<ProfileBloc>().add(
            UpdateProfile(name: name, phone: phone),
          );
        },
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    AppDialog.show<void>(
      context,
      builder: (dialogContext) => AppDialogShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gerçek uygulama logosu — açılış sahnesindeki rozetin küçüğü.
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'BitirGitsin',
              style: AppTypography.h2.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'Versiyon 1.0.0',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Gida israfini onlemek icin isletmeler ve musterileri bulusturan platform.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.inkSoft,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            // İnce ayraç — logonun altındaki bloğu sloganla ayırır.
            Container(
              width: 46,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Birlikte israfi bitirelim, gitsin!',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            _AboutCloseButton(
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    AppDialog.confirm(
      context,
      icon: Icons.logout_rounded,
      title: 'Cikis yap',
      message: 'Hesabinizdan cikis yapmak istediginize emin misiniz?',
      cancelLabel: 'Iptal',
      confirmLabel: 'Cikis Yap',
    ).then((confirmed) {
      if (confirmed && context.mounted) {
        context.read<ProfileBloc>().add(ProfileLogoutRequested());
      }
    });
  }

  void _showDeleteAccountDialog(BuildContext context) {
    AppDialog.confirm(
      context,
      icon: Icons.person_off_rounded,
      title: 'Hesabi sil',
      message:
          'Hesabinizi silmek istediginize emin misiniz? Bu islem geri alinamaz ve tum verileriniz kalici olarak silinecektir.',
      cancelLabel: 'Iptal',
      confirmLabel: 'Hesabi Sil',
    ).then((confirmed) {
      if (confirmed && context.mounted) {
        context.read<ProfileBloc>().add(DeleteAccountRequested());
      }
    });
  }
}

/// "Hakkında" panelini kapatan tam genişlikte hayalet düğme.
class _AboutCloseButton extends StatelessWidget {
  const _AboutCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.34),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          'Tamam',
          style: AppTypography.button.copyWith(fontSize: 15),
        ),
      ),
    );
  }
}
