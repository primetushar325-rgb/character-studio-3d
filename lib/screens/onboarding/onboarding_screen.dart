import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/settings_provider.dart';
import '../../widgets/micro_animations.dart';
import '../../widgets/premium_button.dart';

/// First-launch onboarding (3 pages + Get Started). No login required.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    (
      'Meet Your Characters',
      'Bring your 3D characters to life. Import any GLB model and it joins your library instantly.',
      Icons.view_in_ar_rounded,
    ),
    (
      'Animate',
      'Choose any animation included in your GLB — walk, run, dance or anything else, all detected automatically.',
      Icons.animation_rounded,
    ),
    (
      'Create Anywhere',
      'Everything runs directly on your device. No account, no internet, no limits.',
      Icons.phone_iphone_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.read<SettingsProvider>().completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: TextButton(
                    onPressed: () =>
                        context.read<SettingsProvider>().completeOnboarding(),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final (title, subtitle, icon) = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x337B9BFF),
                                  Color(0x225EEAD4),
                                ],
                              ),
                              border: Border.all(color: AppColors.strokeStrong),
                            ),
                            child: Icon(icon,
                                size: 46, color: AppColors.accentAlt),
                          ),
                          const SizedBox(height: 34),
                          StaggeredEntrance(
                            index: index,
                            child: Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(height: 1.1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontSize: 16, height: 1.55),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 28),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? AppColors.accent : AppColors.strokeStrong,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    PremiumButton(
                      label: isLast ? 'Get Started' : 'Continue',
                      onPressed: _next,
                      style: PremiumButtonStyle.primary,
                      expanded: true,
                      icon: isLast ? Icons.bolt_rounded : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
