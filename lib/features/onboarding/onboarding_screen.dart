import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sankalpa/app/theme/tokens.dart';
import 'package:sankalpa/data/errors/app_error.dart';
import 'package:sankalpa/data/models/category.dart';
import 'package:sankalpa/data/repositories/category_repository.dart';
import 'package:sankalpa/data/repositories/manifestation_repository.dart';
import 'package:sankalpa/data/repositories/user_profile_repository.dart';
import 'package:sankalpa/data/seed/seed_manifestations.dart';

/// Five-step guided write-your-own onboarding.
///
/// One screen per area-of-life, each with a single text field and a
/// gentle example prompt. Designed so a new user lands with their *own*
/// voice in the library rather than a pile of generic starters — the seed
/// pack is still available as a one-tap escape hatch on the welcome step.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// One step of the guided flow. `categoryName` matches the user's
/// auto-seeded categories (created by the `handle_new_user()` trigger),
/// so we can map the user's answer to the right category id at save time.
class _Step {
  const _Step({
    required this.categoryName,
    required this.title,
    required this.prompt,
    required this.example,
    required this.themeId,
  });

  final String categoryName;
  final String title;
  final String prompt;
  final String example;
  final String themeId;
}

const _steps = <_Step>[
  _Step(
    categoryName: 'Self',
    title: 'About you',
    prompt: 'How do you want to feel and show up each day?',
    example: 'I am calm, present, and quietly powerful.',
    themeId: 'chocolate',
  ),
  _Step(
    categoryName: 'Health',
    title: 'Your body',
    prompt: 'What does a strong, healthy you look like?',
    example: 'My body is strong, energised, and well-rested.',
    themeId: 'sage',
  ),
  _Step(
    categoryName: 'Family',
    title: 'Your people',
    prompt: 'What do you wish for the people closest to you?',
    example: 'My family is healthy, happy, and bonded in love.',
    themeId: 'terracotta',
  ),
  _Step(
    categoryName: 'Career',
    title: 'Your work',
    prompt: 'What does your work create in the world?',
    example: 'My work has meaning and creates real impact.',
    themeId: 'dusk',
  ),
  _Step(
    categoryName: 'Wealth',
    title: 'Abundance',
    prompt: 'What is your relationship with money and resources?',
    example: 'Money flows to me easily and I steward it wisely.',
    themeId: 'chocolate',
  ),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _controllers = <TextEditingController>[
    for (final _ in _steps) TextEditingController(),
  ];
  int _index = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isWelcome => _index == 0;
  bool get _isLast => _index == _steps.length;
  bool get _isReview => _index == _steps.length;

  Future<void> _next() async {
    await HapticFeedback.selectionClick();
    if (_isReview) {
      await _save();
      return;
    }
    setState(() => _index++);
    await _pageCtrl.animateToPage(
      _index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_index == 0) return;
    setState(() => _index--);
    await _pageCtrl.animateToPage(
      _index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _useStarters() async {
    setState(() => _saving = true);
    try {
      await ref.read(seedServiceProvider).seedIfNeeded();
      ref
        ..invalidate(manifestationsProvider)
        ..invalidate(userProfileProvider);
      if (mounted) context.go('/library');
    } on Object catch (e) {
      _showError('Couldn\u2019t add starters. ${AppError.from(e).message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final entries = <_DraftManifestation>[];
    for (var i = 0; i < _steps.length; i++) {
      final text = _controllers[i].text.trim();
      if (text.isEmpty) continue;
      entries.add(
        _DraftManifestation(
          text: text,
          categoryName: _steps[i].categoryName,
          themeId: _steps[i].themeId,
        ),
      );
    }
    if (entries.isEmpty) {
      _showError('Add at least one manifestation, or pick the starter set.');
      return;
    }

    setState(() => _saving = true);
    try {
      final cats = await ref.read(categoryRepositoryProvider).list();
      final byName = <String, Category>{for (final c in cats) c.name: c};
      final repo = ref.read(manifestationRepositoryProvider);
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        await repo.create(
          text: e.text,
          categoryId: byName[e.categoryName]?.id,
          themeId: e.themeId,
          sortOrder: (i + 1) * 10,
        );
      }
      await ref
          .read(userProfileRepositoryProvider)
          .updateSettings({'imported_seed': true});
      ref
        ..invalidate(manifestationsProvider)
        ..invalidate(userProfileProvider);
      if (mounted) context.go('/');
    } on Object catch (e) {
      _showError('Couldn\u2019t save. ${AppError.from(e).message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = _steps.length + 2;
    final progress = (_index + 1) / totalPages;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              progress: progress,
              showBack: !_isWelcome,
              onBack: _back,
              onSkip: _saving ? null : () => context.go('/'),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(
                    onBegin: _next,
                    onUseStarters: _saving ? null : _useStarters,
                    saving: _saving,
                  ),
                  for (var i = 0; i < _steps.length; i++)
                    _PromptPage(
                      step: _steps[i],
                      controller: _controllers[i],
                    ),
                  _ReviewPage(
                    steps: _steps,
                    controllers: _controllers,
                  ),
                ],
              ),
            ),
            if (!_isWelcome)
              _Footer(
                isLast: _isLast,
                saving: _saving,
                onNext: _saving ? null : _next,
              ),
          ],
        ),
      ),
    );
  }
}

class _DraftManifestation {
  const _DraftManifestation({
    required this.text,
    required this.categoryName,
    required this.themeId,
  });

  final String text;
  final String categoryName;
  final String themeId;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.progress,
    required this.showBack,
    required this.onBack,
    required this.onSkip,
  });

  final double progress;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: showBack
                    ? IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, size: 20),
                      )
                    : null,
              ),
              const Spacer(),
              if (onSkip != null)
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(Accents.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.isLast,
    required this.saving,
    required this.onNext,
  });

  final bool isLast;
  final bool saving;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onNext,
          child: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(isLast ? 'Save & continue' : 'Next'),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.onBegin,
    required this.onUseStarters,
    required this.saving,
  });

  final VoidCallback onBegin;
  final VoidCallback? onUseStarters;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Icon(
            Icons.auto_awesome,
            size: 36,
            color: Accents.gold.withValues(alpha: 0.95),
          ),
          const SizedBox(height: 24),
          Text(
            'Let\u2019s shape your\nmanifestations.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontFamily: 'Fraunces',
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'A short five-step walk through the areas of your life. '
            'Write each one in your own words \u2014 you can edit, '
            'reorder, or remove any of them later.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: saving ? null : onBegin,
              child: const Text('Begin (about 3 minutes)'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onUseStarters,
              child: Text(
                saving ? 'Adding\u2026' : 'Or use 12 hand-picked starters',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PromptPage extends StatelessWidget {
  const _PromptPage({required this.step, required this.controller});

  final _Step step;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            step.title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Accents.gold,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.prompt,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Fraunces',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            maxLines: 5,
            minLines: 3,
            textInputAction: TextInputAction.done,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: 'Fraunces',
              fontSize: 18,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: step.example,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'Fraunces',
                fontSize: 18,
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.32),
              ),
              filled: true,
              fillColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Phrase it as if it\u2019s already true. Skip if nothing comes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.steps, required this.controllers});

  final List<_Step> steps;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = <int>[];
    for (var i = 0; i < controllers.length; i++) {
      if (controllers[i].text.trim().isNotEmpty) filled.add(i);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your manifestations',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: 'Fraunces',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filled.isEmpty
                ? 'You haven\u2019t written any yet. Go back to add at least one, or use the starter set.'
                : 'Looks great. Tap save to add ${filled.length} to your library.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          for (final i in filled) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[i].categoryName.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Accents.gold,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    controllers[i].text.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Fraunces',
                      fontSize: 17,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
