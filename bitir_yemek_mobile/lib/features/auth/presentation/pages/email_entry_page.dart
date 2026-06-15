import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/responsive.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../location/presentation/pages/location_permission_page.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../bloc/auth_bloc.dart';
import 'otp_verify_page.dart';

/// Entry point of the passwordless flow: the user types their email and
/// receives a one-time login code. Google/Apple sign-in remain available here.
class EmailEntryPage extends StatelessWidget {
  const EmailEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokenStorage = createDefaultTokenStorage();
    return BlocProvider(
      create: (context) => AuthBloc(
        authRepository: AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSource(
            dioClient: DioClient(tokenStorage: tokenStorage),
          ),
          tokenStorage: tokenStorage,
        ),
      ),
      child: const EmailEntryView(),
    );
  }
}

class EmailEntryView extends StatefulWidget {
  const EmailEntryView({super.key});

  @override
  State<EmailEntryView> createState() => _EmailEntryViewState();
}

class _EmailEntryViewState extends State<EmailEntryView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onContinuePressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        OtpRequested(email: _emailController.text.trim()),
      );
    }
  }

  Future<void> _navigateAfterLogin(BuildContext context, String role) async {
    final isBusinessOwner = role == 'business_owner';
    final locationService = LocationService();
    final hasPermission = await locationService.hasPermission();

    if (!context.mounted) return;

    if (isBusinessOwner) {
      if (hasPermission) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const BusinessOwnerScaffold(),
          ),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                const LocationPermissionPage(isBusinessOwner: true),
          ),
          (route) => false,
        );
      }
      return;
    }

    if (hasPermission) {
      final position = await locationService.getCurrentPosition();
      if (position != null && context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScaffold(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          ),
          (route) => false,
        );
        return;
      }
    }

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LocationPermissionPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is OtpSent) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OtpVerifyPage(
                  email: state.email,
                  isNewUser: state.isNewUser,
                ),
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Reached via Google/Apple sign-in.
            await _navigateAfterLogin(context, state.user.role);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final responsive = context.responsive;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(responsive.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldiniz!',
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: responsive.padding(AppSpacing.sm)),

                    Text(
                      'E-posta adresinizi girin, size bir giriş kodu gönderelim',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: responsive.padding(AppSpacing.xxl)),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: state is! AuthLoading,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onContinuePressed(),
                      decoration: const InputDecoration(
                        hintText: 'E-posta adresiniz',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'E-posta adresi gerekli';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Geçerli bir e-posta adresi girin';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: state is AuthLoading
                            ? null
                            : _onContinuePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        child: state is AuthLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Devam Et',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Divider & social sign-in
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: AppColors.textHint),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'veya',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: AppColors.textHint),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: state is AuthLoading
                            ? null
                            : () {
                                context.read<AuthBloc>().add(
                                  const GoogleSignInRequested(role: 'customer'),
                                );
                              },
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(
                          'Google ile Giriş Yap',
                          style: AppTypography.button.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.textHint),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ),

                    // Apple Sign-In Button (iOS only)
                    if (Platform.isIOS) ...[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: state is AuthLoading
                              ? null
                              : () {
                                  context.read<AuthBloc>().add(
                                    const AppleSignInRequested(role: 'customer'),
                                  );
                                },
                          icon: const Icon(
                            Icons.apple,
                            size: 28,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Apple ile Giriş Yap',
                            style: AppTypography.button.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
