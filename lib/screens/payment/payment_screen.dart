import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamboplus/core/theme/app_colors.dart';
import 'package:jamboplus/core/theme/app_theme.dart';
import 'package:jamboplus/providers/app_config_provider.dart';
import 'package:jamboplus/providers/service_providers.dart';
import 'package:jamboplus/providers/user_provider.dart';
import 'package:jamboplus/services/payment_voice_service.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _voiceService = PaymentVoiceService();
  int _currentStep = 0;
  bool _isProcessing = false;
  String _processingHint = 'Subiri, inaendelea...';
  Timer? _pollTimer;
  int _pollAttempts = 0;

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  int _selectedPackage = -1;
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();

  static const _packageIcons = [
    Icons.bolt_rounded,
    Icons.star_rounded,
    Icons.workspace_premium_rounded,
    Icons.diamond_rounded,
  ];

  static const _packageColors = [
    Color(0xFFFF6B35),
    AppColors.primaryCyan,
    AppColors.accentPurple,
    AppColors.primaryIndigo,
  ];

  List<_Package> get _packages {
    final plans = ref.watch(pricingProvider).valueOrNull ?? [];
    return List.generate(plans.length, (i) {
      final p = plans[i];
      return _Package(
        id: p.id,
        name: p.name,
        duration: 'Siku ${p.durationDays}',
        price: p.price.round(),
        originalPrice: p.originalPrice.round(),
        icon: _packageIcons[i % _packageIcons.length],
        color: _packageColors[i % _packageColors.length],
        isBestValue: i == 1 && plans.length > 1,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playVoice(0));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _voiceService.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _playVoice(Object key) => _voiceService.play(key);

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().length >= 2;
      case 1:
        return _selectedPackage >= 0;
      case 2:
        return _isValidTzPhone(_phoneController.text);
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    _playVoice(step);
  }

  void _nextStep() {
    if (!_canProceed) return;
    if (_currentStep < 3) {
      _goToStep(_currentStep + 1);
    } else {
      _processPayment();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedPackage < 0 || _selectedPackage >= _packages.length) return;
    final pkg = _packages[_selectedPackage];
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() {
      _isProcessing = true;
      _processingHint = 'Inatuma ombi la malipo kwenye simu...';
    });
    _playVoice('wait');

    try {
      final api = ref.read(apiServiceProvider);
      final started = await api.startPayment(
        name: name,
        phone: phone,
        planId: pkg.id,
        amount: pkg.price,
      );
      final orderId = (started['orderId'] ?? started['order_id'] ?? '')
          .toString()
          .trim();
      if (orderId.isEmpty) {
        throw StateError('Hakuna orderId kutoka seva');
      }

      if (!mounted) return;
      setState(() {
        _processingHint =
            'Angalia simu yako na weka PIN kukamilisha malipo...';
      });

      await _pollUntilDone(orderId);
    } on DioException catch (e) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() => _isProcessing = false);
      await _playVoice('fail');
      final msg = _dioErrorMessage(e);
      if (mounted) _showResultDialog(false, message: msg);
    } catch (_) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() => _isProcessing = false);
      await _playVoice('fail');
      if (mounted) _showResultDialog(false);
    }
  }

  Future<void> _pollUntilDone(String orderId) async {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    const maxAttempts = 40; // ~2 minutes at 3s
    final api = ref.read(apiServiceProvider);
    final completer = Completer<void>();

    Future<void> tick() async {
      if (!mounted || completer.isCompleted) return;
      _pollAttempts += 1;
      try {
        final status = await api.checkPaymentStatus(orderId);
        final completed = status['completed'] == true ||
            status['activated'] == true;
        final failed = status['failed'] == true;

        if (completed) {
          _pollTimer?.cancel();
          await ref.read(userProvider.notifier).syncFromServer();
          // Prefer user payload from status if present.
          final userJson = status['user'];
          if (userJson is Map<String, dynamic>) {
            // syncFromServer already refreshed; ignore payload shape mismatches.
          }
          if (!mounted) return;
          setState(() => _isProcessing = false);
          await _playVoice('success');
          if (mounted) {
            _showResultDialog(
              true,
              message:
                  'Malipo yamefanikiwa! Akaunti yako ya Premium imefunguliwa.',
            );
          }
          if (!completer.isCompleted) completer.complete();
          return;
        }

        if (failed) {
          _pollTimer?.cancel();
          if (!mounted) return;
          setState(() => _isProcessing = false);
          await _playVoice('fail');
          if (mounted) {
            _showResultDialog(
              false,
              message: (status['message'] ??
                      'Malipo hayajakamilika. Jaribu tena.')
                  .toString(),
            );
          }
          if (!completer.isCompleted) completer.complete();
          return;
        }
      } catch (_) {
        // Keep polling through transient network errors.
      }

      if (_pollAttempts >= maxAttempts) {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        await _playVoice('fail');
        if (mounted) {
          _showResultDialog(
            false,
            message:
                'Hatukuona uthibitisho wa malipo bado. Ikiwa ulilipa, fungua app tena baada ya dakika chache au wasiliana na msaada.',
          );
        }
        if (!completer.isCompleted) completer.complete();
      }
    }

    await tick();
    if (completer.isCompleted) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => tick());
    await completer.future;
  }

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return 'Imeshindikana kuanzisha malipo. Jaribu tena.';
  }

  void _showResultDialog(bool success, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PaymentResultDialog(
        success: success,
        message: message,
        onDone: () {
          Navigator.of(ctx).pop();
          if (success) Navigator.of(context).pop();
        },
        onRetry: success
            ? null
            : () {
                Navigator.of(ctx).pop();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildNameStep(),
                    _buildPackageStep(),
                    _buildPhoneStep(),
                    _buildConfirmStep(),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _currentStep == 0
                ? () => Navigator.of(context).pop()
                : _prevStep,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              shadowColor: AppColors.primaryIndigo.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lipia Premium',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _stepSubtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.premiumGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPurple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${_currentStep + 1} / 4',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepSubtitle {
    const subs = [
      'Hatua ya kwanza',
      'Chagua kifurushi',
      'Namba ya malipo',
      'Hakiki na lipia',
    ];
    return subs[_currentStep];
  }

  // ── Step Indicator ──

  Widget _buildStepIndicator() {
    const labels = ['Jina', 'Kifurushi', 'Namba', 'Hakiki'];
    const icons = [
      Icons.person_rounded,
      Icons.card_giftcard_rounded,
      Icons.phone_rounded,
      Icons.verified_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: List.generate(4, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: isDone || isActive
                            ? AppColors.primaryGradient
                            : null,
                        color: isDone || isActive
                            ? null
                            : AppColors.textMuted.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: isActive ? 40 : 30,
                      height: isActive ? 40 : 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDone || isActive
                            ? AppColors.primaryGradient
                            : null,
                        color: isDone || isActive
                            ? null
                            : AppColors.textMuted.withValues(alpha: 0.1),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryCyan
                                      .withValues(alpha: 0.45),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18)
                            : Icon(
                                icons[i],
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textMuted,
                                size: isActive ? 20 : 16,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isDone || isActive
                            ? AppColors.primaryIndigo
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Step 1: Name ──

  Widget _buildNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryCyan.withValues(alpha: 0.12),
                    AppColors.primaryIndigo.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primaryCyan,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Je, unaitwa nani?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ingiza jina lako kamili ili tuweze kukutambua',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Jina Kamili',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            onChanged: (_) => setState(() {}),
            decoration: _borderedInputDecoration(
              hint: 'majina yako hapa',
              prefixIcon: Icons.badge_rounded,
              borderColor: AppColors.primaryCyan,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.primaryCyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jina litaonekana kwenye risiti yako ya malipo',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0);
  }

  // ── Step 2: Package ──

  Widget _buildPackageStep() {
    final pricingAsync = ref.watch(pricingProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Je, unapenda kifurushi gani?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Chagua kifurushi kinachokufaa zaidi',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          pricingAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )),
            error: (_, __) => Text(
              'Imeshindwa kupakia bei. Jaribu tena baadae.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            data: (_) {
              if (_packages.isEmpty) {
                return Text(
                  'Hakuna vifurushi vinavyopatikana kwa sasa.',
                  style: TextStyle(color: AppColors.textSecondary),
                );
              }
              return Column(
                children: _buildPackageCards(),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0);
  }

  List<Widget> _buildPackageCards() {
    return List.generate(_packages.length, (i) {
            final pkg = _packages[i];
            final isSelected = _selectedPackage == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => setState(() => _selectedPackage = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? pkg.color
                          : AppColors.textMuted.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: pkg.color.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color:
                                  AppColors.primaryIndigo.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(colors: [
                                  pkg.color,
                                  pkg.color.withValues(alpha: 0.7),
                                ])
                              : null,
                          color: isSelected
                              ? null
                              : pkg.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          pkg.icon,
                          color: isSelected ? Colors.white : pkg.color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pkg.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isSelected
                                        ? pkg.color
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                if (pkg.isBestValue) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'BORA ZAIDI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pkg.duration,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'TSh ${_formatPrice(pkg.price)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isSelected
                              ? pkg.color
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isSelected
                              ? LinearGradient(colors: [
                                  pkg.color,
                                  pkg.color.withValues(alpha: 0.7),
                                ])
                              : null,
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: AppColors.textMuted.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
  }

  // ── Step 3: Phone ──

  Widget _buildPhoneStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.12),
                    AppColors.primaryCyan.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: AppColors.primaryGreen,
                size: 52,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'Namba ya Malipo',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Ingiza namba ya simu utakayotumia kulipa',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Namba ya Simu',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            inputFormatters: const [
              _TanzaniaPhoneInputFormatter(),
            ],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
            onChanged: (_) => setState(() {}),
            decoration: _borderedInputDecoration(
              hint: '0712345678',
              prefixIcon: Icons.sim_card_rounded,
              borderColor: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Njia zinazopokelewa',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodChip(
                  label: 'M-Pesa',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFFE21B1B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodChip(
                  label: 'Tigo Pesa',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF00529B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodChip(
                  label: 'Airtel',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFFED1C24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodChip(
                  label: 'Halotel',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0066CC),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0);
  }

  // ── Step 4: Confirm ──

  Widget _buildConfirmStep() {
    final pkg = _selectedPackage >= 0 ? _packages[_selectedPackage] : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryIndigo.withValues(alpha: 0.1),
                    AppColors.accentPurple.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.primaryIndigo,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Hakiki Taarifa Zako',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 24,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Hakikisha kila kitu ni sahihi kabla ya kulipia',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryIndigo.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryIndigo.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _ConfirmRow(
                  icon: Icons.person_rounded,
                  label: 'Jina',
                  value: _nameController.text.trim(),
                  color: AppColors.primaryCyan,
                ),
                _buildDivider(),
                _ConfirmRow(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Kifurushi',
                  value:
                      pkg != null ? '${pkg.name} (${pkg.duration})' : '-',
                  color: AppColors.accentPurple,
                ),
                _buildDivider(),
                _ConfirmRow(
                  icon: Icons.phone_rounded,
                  label: 'Namba',
                  value: _phoneController.text.trim(),
                  color: AppColors.primaryGreen,
                ),
                _buildDivider(),
                _ConfirmRow(
                  icon: Icons.payments_rounded,
                  label: 'Kiasi',
                  value: pkg != null
                      ? 'TSh ${_formatPrice(pkg.price)}'
                      : '-',
                  color: AppColors.primaryIndigo,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryCyan.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryCyan,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Baada ya kubonyeza "Lipia Sasa", utapokea ujumbe wa kuingiza PIN kwenye simu yako.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0);
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        color: AppColors.textMuted.withValues(alpha: 0.12),
      ),
    );
  }

  // ── Bottom Bar ──

  Widget _buildBottomBar() {
    final isLastStep = _currentStep == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceBorder.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _isProcessing
            ? Container(
                key: const ValueKey('processing'),
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryIndigo.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryIndigo.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryIndigo,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _processingHint,
                      style: TextStyle(
                        color: AppColors.primaryIndigo,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                key: const ValueKey('button'),
                width: double.infinity,
                height: 56,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _canProceed ? 1.0 : 0.45,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _canProceed
                          ? (isLastStep
                              ? AppColors.premiumGradient
                              : AppColors.primaryGradient)
                          : null,
                      color: _canProceed
                          ? null
                          : AppColors.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _canProceed
                          ? [
                              BoxShadow(
                                color: (isLastStep
                                        ? AppColors.accentPurple
                                        : AppColors.primaryCyan)
                                    .withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canProceed ? _nextStep : null,
                        borderRadius: BorderRadius.circular(18),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLastStep)
                                const Icon(Icons.lock_rounded,
                                    color: Colors.white, size: 20),
                              if (isLastStep) const SizedBox(width: 8),
                              Text(
                                isLastStep ? 'Lipia Sasa' : 'Endelea',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (!isLastStep) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Helpers ──

  static bool _isValidTzPhone(String raw) {
    final phone = raw.trim();
    return RegExp(r'^0\d{9}$').hasMatch(phone);
  }

  InputDecoration _borderedInputDecoration({
    required String hint,
    required IconData prefixIcon,
    required Color borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.textMuted.withValues(alpha: 0.5),
      ),
      prefixIcon: Icon(prefixIcon, color: borderColor),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.textMuted.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: borderColor,
          width: 2.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
    );
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

// ── Supporting Classes ──

class _TanzaniaPhoneInputFormatter extends TextInputFormatter {
  const _TanzaniaPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    if (!digits.startsWith('0')) {
      return oldValue;
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class _Package {
  const _Package({
    required this.id,
    required this.name,
    required this.duration,
    required this.price,
    required this.originalPrice,
    required this.icon,
    required this.color,
    this.isBestValue = false,
  });

  final String id;
  final String name;
  final String duration;
  final int price;
  final int originalPrice;
  final IconData icon;
  final Color color;
  final bool isBestValue;
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '-' : value,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: isBold ? 20 : 15,
                  color:
                      isBold ? AppColors.primaryIndigo : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentResultDialog extends StatelessWidget {
  const _PaymentResultDialog({
    required this.success,
    required this.onDone,
    this.onRetry,
    this.message,
  });

  final bool success;
  final VoidCallback onDone;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: success
                    ? const LinearGradient(
                        colors: [AppColors.primaryGreen, Color(0xFF34D399)])
                    : const LinearGradient(
                        colors: [AppColors.liveRed, Color(0xFFFF6B6B)]),
                boxShadow: [
                  BoxShadow(
                    color: (success
                            ? AppColors.primaryGreen
                            : AppColors.liveRed)
                        .withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                success
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: Colors.white,
                size: 48,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 28),
            Text(
              success ? 'Malipo Yamefanikiwa!' : 'Malipo Hayajakamilika',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color:
                    success ? AppColors.primaryGreen : AppColors.liveRed,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message ??
                  (success
                      ? 'Akaunti yako ya Premium imefunguliwa. Unaweza kutazama chaneli zote sasa.'
                      : 'Hakikisha una fedha za kutosha na umeweka PIN/password sahihi. Jaribu tena.'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: success
                      ? const LinearGradient(
                          colors: [AppColors.primaryGreen, Color(0xFF34D399)])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (success
                              ? AppColors.primaryGreen
                              : AppColors.primaryCyan)
                          .withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDone,
                    borderRadius: BorderRadius.circular(16),
                    child: Center(
                      child: Text(
                        success ? 'Endelea Kutazama' : 'Sawa',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!success && onRetry != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Jaribu Tena',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primaryIndigo,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: 350.ms,
          curve: Curves.easeOutBack,
        );
  }
}
