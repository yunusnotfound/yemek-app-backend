import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/theme.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/location_service.dart';
import '../../../business_owner/presentation/pages/business_owner_scaffold.dart';
import '../../../location/presentation/pages/location_permission_page.dart';
import '../../../main/presentation/pages/main_scaffold.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../bloc/auth_bloc.dart';
import '../../domain/app_role.dart';
import 'otp_verify_page.dart';
import '../widgets/login_hero.dart';

/// Entry point of the passwordless flow: the user types their email and
/// receives a one-time login code. Google/Apple sign-in remain available here.
class EmailEntryPage extends StatelessWidget {
  /// Onboarding'in son sayfasında seçilen rol. Google/Apple girişine `role`
  /// olarak geçer; doğrudan bu sayfaya gelinen durumlarda müşteri varsayılır.
  final AppRole role;

  const EmailEntryPage({super.key, this.role = AppRole.customer});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(
        authRepository: AuthRepositoryImpl(
          remoteDataSource: AuthRemoteDataSource(dioClient: appDioClient),
          tokenStorage: appTokenStorage,
        ),
      ),
      child: EmailEntryView(role: role),
    );
  }
}

class EmailEntryView extends StatefulWidget {
  final AppRole role;

  const EmailEntryView({super.key, this.role = AppRole.customer});

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
    if (context.read<AuthBloc>().state is AuthLoading) return;
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFAF5), AppColors.background],
          ),
        ),
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) async {
            if (state is OtpSent) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => OtpVerifyPage(
                    email: state.email,
                    isNewUser: state.isNewUser,
                    role: widget.role.apiValue,
                  ),
                ),
              );
            } else if (state is AuthAuthenticated) {
              await _navigateAfterLogin(context, state.user.role);
            } else if (state is AuthError) {
              AppNotice.error(context, state.message);
            }
          },
          builder: (context, state) {
            final loading = state is AuthLoading;
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          alignment: Alignment.topCenter,
                          curve: Curves.easeOutCubic,
                          child: keyboardVisible
                              ? const SizedBox(height: 18)
                              : const Padding(
                                  padding: EdgeInsets.only(top: 18, bottom: 24),
                                  child: LoginHero(),
                                ),
                        ),
                        _buildSignInCard(loading),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Navigator.of(context).canPop()
              ? IconButton.filledTonal(
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppDepth.border),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 21),
                )
              : null,
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 34,
                    height: 34,
                    cacheWidth: 102,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'BitirGitsin',
                  style: AppTypography.h3.copyWith(
                    fontSize: 22,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildSignInCard(bool loading) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.creamTop,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppDepth.border),
        boxShadow: AppDepth.card,
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hoş geldin',
                style: AppTypography.h1.copyWith(
                  color: AppColors.ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'E-postanla giriş yap veya aramıza katıl.\nSana tek kullanımlık bir kod göndereceğiz.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 25),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                enabled: !loading,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onContinuePressed(),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: AppTypography.bodyLarge.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'E-posta adresin',
                  hintText: 'ornek@eposta.com',
                  fillColor: const Color(0xFFFCF8F4),
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    size: 21,
                    color: AppColors.inkSoft,
                  ),
                  floatingLabelStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryInk,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppDepth.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : _onContinuePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Devam et',
                              style: AppTypography.button,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'veya hesabınla devam et',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final google = _socialButton(
                    label: 'Google',
                    icon: Image.asset(
                      'assets/images/google-mark.png',
                      width: 20,
                      height: 20,
                      cacheWidth: 60,
                      excludeFromSemantics: true,
                    ),
                    onPressed: loading
                        ? null
                        : () => context.read<AuthBloc>().add(
                            GoogleSignInRequested(role: widget.role.apiValue),
                          ),
                  );
                  final apple = _socialButton(
                    label: 'Apple',
                    icon: const Icon(
                      Icons.apple,
                      size: 23,
                      color: Colors.white,
                    ),
                    dark: true,
                    onPressed: loading
                        ? null
                        : () => context.read<AuthBloc>().add(
                            AppleSignInRequested(role: widget.role.apiValue),
                          ),
                  );
                  if (!Platform.isIOS) return google;
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [google, const SizedBox(height: 12), apple],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: google),
                      const SizedBox(width: 12),
                      Expanded(child: apple),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required Widget icon,
    required VoidCallback? onPressed,
    bool dark = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? AppColors.ink : Colors.white,
        foregroundColor: dark ? Colors.white : AppColors.ink,
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(color: dark ? AppColors.ink : AppDepth.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Semantics(
        label: '$label ile giriş yap',
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.button.copyWith(
                    color: dark ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
