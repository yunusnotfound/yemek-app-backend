import 'package:flutter/material.dart';
import '../../../../config/theme.dart';
import '../widgets/food_orbit.dart';
import '../widgets/rescue_game.dart';
import '../widgets/surprise_box.dart';
import 'email_entry_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// İlk sayfa salt GÖRSEL (kendi kendine dönen kompozisyon, kullanıcıdan bir
  /// şey beklemez); sonraki ikisi etkileşimli ve birbirinden farklı jest ister
  /// — dokunma ve sürükleme. Aynı hissin tekrarlanmaması için böyle ayrıldı.
  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      title: 'Yiyecek İsrafına Son',
      description:
          'Restoranlardan ve marketlerden arta kalan lezzetli yiyecekleri keşfet, hem cebini hem dünyayı koru.',
    ),
    _OnboardingData(
      title: 'Sürpriz Paketler',
      description:
          'Kutuya dokun ve ne çıkacağını gör. Gerçek paketler de böyle: uygun fiyat, her seferinde başka bir lezzet.',
    ),
    _OnboardingData(
      title: 'Sen Kurtar, Çöpe Gitmesin',
      description:
          'Yemeği çantana sürükle. Uygulamada yaptığın şey de tam olarak bu.',
    ),
  ];

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EmailEntryPage()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  right: AppSpacing.screenPadding,
                ),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    'Atla',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                    ),
                    child: _buildPage(index),
                  );
                },
              ),
            ),

            // Bottom section: dots + button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.textHint.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    // Etkileşimler İSTEĞE BAĞLI keyif katmanıdır; oynamayan
                    // kullanıcıyı bekletmemek için buton her zaman aktiftir.
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _goToLogin();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Başlayalım' : 'Devam',
                        style: AppTypography.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sayfa gövdesi. Başlık + açıklama düzeni üç sayfada da aynı kalır; değişen
  /// tek şey üstteki etkileşim alanı. Metin bloğu sabit durduğu için sayfalar
  /// arası geçişte düzen zıplamaz.
  Widget _buildPage(int index) {
    final page = _pages[index];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildVisual(index),

        const SizedBox(height: AppSpacing.xl),

        Text(
          page.title,
          textAlign: TextAlign.center,
          style: AppTypography.h1.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        Text(
          page.description,
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Sayfanın üst görsel alanı. 0 salt dekoratif; 1 ve 2 etkileşimli ve ayrı
  /// jestler kullanır (dokunma / sürükleme).
  Widget _buildVisual(int index) {
    switch (index) {
      case 0:
        return const FoodOrbit();
      case 1:
        return const SurpriseBox();
      default:
        return const RescueGame();
    }
  }
}

class _OnboardingData {
  final String title;
  final String description;

  const _OnboardingData({
    required this.title,
    required this.description,
  });
}
