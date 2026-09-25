import 'package:flutter/material.dart';

import '../app_preferences.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _saving = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _changeStep(int step) {
    setState(() => _step = step);
    _scroll.jumpTo(0);
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.preferences.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.saveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final strings = context.l10n;
    final titles = [
      strings.onboardingFindTitle,
      strings.onboardingReviewTitle,
      strings.onboardingTogetherTitle,
    ];
    final descriptions = [
      strings.onboardingFindBody,
      strings.onboardingReviewBody,
      strings.onboardingTogetherBody,
    ];
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scroll,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 20),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            if (_step > 0)
                              IconButton(
                                tooltip: strings.back,
                                onPressed: _saving
                                    ? null
                                    : () => _changeStep(_step - 1),
                                icon: const Icon(Icons.arrow_back_rounded),
                              )
                            else
                              const SizedBox(width: 48, height: 48),
                            Expanded(
                              child: Semantics(
                                label: strings.onboardingProgress(_step + 1, 3),
                                liveRegion: true,
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                        3,
                                        (index) => Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              width: index == _step ? 32 : 10,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: index <= _step
                                                    ? colors.primary
                                                    : colors.border,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            )),
                                  ),
                                ),
                              ),
                            ),
                            ExcludeSemantics(
                                child: Text('${_step + 1}/3',
                                    style: TextStyle(
                                        color: colors.muted,
                                        fontWeight: FontWeight.w600))),
                          ]),
                          const SizedBox(height: 32),
                          ExcludeSemantics(child: _OnboardingArt(step: _step)),
                          const SizedBox(height: 36),
                          Semantics(
                            header: true,
                            child: Text(titles[_step],
                                style: TextStyle(
                                    fontSize: 30,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: colors.text)),
                          ),
                          const SizedBox(height: 16),
                          Text(descriptions[_step],
                              style: TextStyle(
                                  fontSize: 17,
                                  height: 1.6,
                                  color: colors.muted)),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    if (_step == 2) {
                                      _finish();
                                    } else {
                                      _changeStep(_step + 1);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              minimumSize: const Size.fromHeight(56),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              elevation: 0,
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700),
                            ),
                            child: Text(_step == 2
                                ? strings.onboardingStart
                                : strings.onboardingNext),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _saving ? null : _finish,
                            style: TextButton.styleFrom(
                                minimumSize: const Size.fromHeight(48)),
                            child: Text(strings.onboardingSkip,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Resolution-independent artwork that follows both app themes.
class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 240,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 320,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                  width: 224,
                  height: 224,
                  decoration: BoxDecoration(
                      color: colors.primarySoft, shape: BoxShape.circle)),
              Positioned(
                  left: 18,
                  top: 20,
                  child: Icon(Icons.cloud_rounded,
                      size: 48, color: colors.primarySoft)),
              Positioned(
                  right: 12,
                  top: 44,
                  child: Icon(Icons.cloud_rounded,
                      size: 36, color: colors.primarySoft)),
              Positioned(
                  left: 18,
                  bottom: 20,
                  child: Icon(Icons.park_rounded,
                      size: 66, color: colors.success)),
              Positioned(
                  right: 12,
                  bottom: 16,
                  child: Icon(Icons.park_rounded,
                      size: 82, color: colors.success)),
              if (step == 0) ...[
                Positioned(
                    left: 50,
                    bottom: 35,
                    child: Icon(Icons.apartment_rounded,
                        size: 110,
                        color: colors.primary.withValues(alpha: 0.25))),
                Icon(Icons.accessible_forward_rounded,
                    size: 148, color: colors.primary),
                Positioned(
                    right: 54,
                    top: 18,
                    child: Icon(Icons.location_on_rounded,
                        size: 66, color: colors.primary)),
              ] else if (step == 1)
                Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    width: 132,
                    height: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.primary, width: 5)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Container(
                              width: 36,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(8))),
                          Icon(Icons.rate_review_rounded,
                              size: 56, color: colors.primary),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                  3,
                                  (_) => Icon(Icons.star_rounded,
                                      color: colors.warning, size: 28))),
                          Icon(Icons.check_circle_rounded,
                              color: colors.success, size: 32),
                        ]),
                  ),
                )
              else ...[
                Icon(Icons.favorite_rounded, size: 196, color: colors.primary),
                Positioned(
                    top: 72,
                    child: Icon(Icons.diversity_3_rounded,
                        size: 80, color: colors.onPrimary)),
                Positioned(
                    right: 36,
                    top: 8,
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 36, color: colors.warning)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
