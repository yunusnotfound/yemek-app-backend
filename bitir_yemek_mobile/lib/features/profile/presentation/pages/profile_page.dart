import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/pages/welcome_page.dart';
import '../../../cards/presentation/pages/saved_cards_page.dart';
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
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
          );
        } else if (state is ProfileUpdateSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ProfileUpdateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state is AccountDeleteError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.eco, size: 40, color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('BitirGitsin', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.xs),
            Text('Versiyon 1.0.0', style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Gida israfini onlemek icin isletmeler ve musterileri bulusturan platform.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Birlikte israfi bitirelim, gitsin!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cikis Yap'),
        content: const Text(
          'Hesabinizdan cikis yapmak istediginize emin misiniz?',
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
              context.read<ProfileBloc>().add(ProfileLogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cikis Yap'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hesabi Sil'),
        content: const Text(
          'Hesabinizi silmek istediginize emin misiniz? Bu islem geri alinamaz ve tum verileriniz kalici olarak silinecektir.',
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
              context.read<ProfileBloc>().add(DeleteAccountRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hesabi Sil'),
          ),
        ],
      ),
    );
  }
}
