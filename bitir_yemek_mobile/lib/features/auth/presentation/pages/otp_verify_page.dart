import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../location/presentation/pages/location_permission_page.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../bloc/auth_bloc.dart';

/// Second step of the passwordless flow: enter the emailed code. For brand-new
/// accounts ([isNewUser] true) we also collect a name (required) and phone.
class OtpVerifyPage extends StatelessWidget {
  final String email;
  final bool isNewUser;

  const OtpVerifyPage({
    super.key,
    required this.email,
    required this.isNewUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(
        authRepository: AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSource(
            dioClient: appDioClient,
          ),
          tokenStorage: appTokenStorage,
        ),
      ),
      child: OtpVerifyView(email: email, isNewUser: isNewUser),
    );
  }
}

class OtpVerifyView extends StatefulWidget {
  final String email;
  final bool isNewUser;

  const OtpVerifyView({
    super.key,
    required this.email,
    required this.isNewUser,
  });

  @override
  State<OtpVerifyView> createState() => _OtpVerifyViewState();
}

class _OtpVerifyViewState extends State<OtpVerifyView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
        OtpVerifyRequested(
          email: widget.email,
          code: _codeController.text.trim(),
          name: widget.isNewUser ? _nameController.text.trim() : null,
          phone: widget.isNewUser ? _phoneController.text.trim() : null,
        ),
      );
    }
  }

  void _onResendPressed() {
    context.read<AuthBloc>().add(OtpRequested(email: widget.email));
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
        title: Text(
          'Giriş Kodu',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthAuthenticated) {
            await _navigateAfterLogin(context, state.user.role);
          } else if (state is OtpSent) {
            // Resend succeeded — stay on this page.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
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
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      '${widget.email} adresine gönderilen 6 haneli kodu girin.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Code Field
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      enabled: state is! AuthLoading,
                      textAlign: TextAlign.center,
                      style: AppTypography.h2.copyWith(letterSpacing: 12),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        hintText: '------',
                        prefixIcon: Icon(Icons.lock_clock_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Giriş kodu gerekli';
                        }
                        if (value.length != 6) {
                          return '6 haneli kodu girin';
                        }
                        return null;
                      },
                    ),

                    // New-account fields
                    if (widget.isNewUser) ...[
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _nameController,
                        enabled: state is! AuthLoading,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Ad Soyad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ad soyad gerekli';
                          }
                          if (value.trim().length < 2) {
                            return 'Ad soyad en az 2 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: state is! AuthLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Telefon (opsiyonel)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (value.length < 10 || value.length > 11) {
                              return 'Geçerli bir telefon numarası girin';
                            }
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: state is AuthLoading
                            ? null
                            : _onVerifyPressed,
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
                                'Doğrula',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Resend code
                    Center(
                      child: TextButton(
                        onPressed: state is AuthLoading ? null : _onResendPressed,
                        child: Text(
                          'Kodu tekrar gönder',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
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
