import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;

  const ProfileHeader({super.key, required this.user});

  String get _initials {
    final parts = user.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return (parts.first.isEmpty ? '?' : parts.first[0]).toUpperCase();
  }

  String get _memberSince {
    return DateFormat('MMMM yyyy', 'tr_TR').format(user.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.screenPadding),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: AppDepth.surface(warm: true),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppDepth.gradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: AppDepth.card,
            ),
            child: Center(
              child: Text(
                _initials,
                style: AppTypography.h1.copyWith(
                  color: AppColors.primaryInk,
                  fontSize: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Name
          Text(user.name, style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          // Email
          Text(
            user.email,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          // Member since
          Text(
            '$_memberSince\'den beri üye',
            style: AppTypography.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
