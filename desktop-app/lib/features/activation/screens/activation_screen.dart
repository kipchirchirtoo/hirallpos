import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/network/api_service.dart';
import '../../shell/screens/main_shell_screen.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _licenseController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  Future<void> _loadSavedKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('license_key') ?? 'HPOS-HF9P-37QH-JZTM';
    if (mounted) {
      setState(() {
        _licenseController.text = savedKey;
      });
    }
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndActivate() async {
    final key = _licenseController.text.trim().toUpperCase();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter your license activation key.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.verifyLicense(licenseKey: key);

      if (res['is_valid'] == true) {
        final orgName = (res['organization_name'] as String?)?.isNotEmpty == true
            ? res['organization_name']!
            : 'Merchant Store';
        final branchName = (res['branch_name'] as String?)?.isNotEmpty == true
            ? res['branch_name']!
            : 'Main Branch';
        final businessType = res['business_type'] ?? 'supermarket';
        final modules = List<String>.from(res['enabled_modules'] ?? [
          'cashier',
          'storekeeping',
          'pos_outlets',
          'accounting',
          'hr_management'
        ]);

        // Persist activation details so restarts never ask again
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('license_key', key);
        await prefs.setString('organization_id', res['organization_id'] ?? '5e8e0062-e422-48fe-9f06-449a146f6c8c');
        await prefs.setString('organization_name', orgName);
        await prefs.setString('branch_id', res['branch_id'] ?? '331b6fe8-1430-4bd4-be23-d4d62a67eab7');
        await prefs.setString('branch_name', branchName);
        await prefs.setString('business_type', businessType);
        await prefs.setStringList('enabled_modules', modules);
        await prefs.setBool('is_activated', true);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MainShellScreen(
                organizationName: orgName,
                branchName: branchName,
                businessType: businessType,
                enabledModules: modules,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res['message'] ??
                'License key not recognized. Please register your organization in the Web Admin Portal to obtain a valid key.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to connect to Cloud Database server. Ensure backend is running and check network connection.\n\nError: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Stack(
        children: [
          // Top-Right Theme Mode Toggle
          Positioned(
            top: 20,
            right: 20,
            child: InkWell(
              onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDark ? LucideIcons.sun : LucideIcons.moon,
                      size: 16,
                      color: isDark ? const Color(0xFFFBBF24) : AppColors.textPrimary(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDark ? 'Light Theme' : 'Dark Theme',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Center Card
          Center(
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(LucideIcons.store, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HIRALL POS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Desktop Terminal Activation',
                            style: TextStyle(fontSize: 13, color: AppColors.textMuted(context)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Activate Store Terminal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the activation key generated from your Web Admin Onboarding Portal.',
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _licenseController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(LucideIcons.key, color: AppColors.primary, size: 20),
                      hintText: 'e.g. HIRALL-MYSTORE-8891-PRO',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _verifyAndActivate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(LucideIcons.arrowRight, size: 18),
                      label: Text(_isLoading ? 'Verifying & Initializing Station...' : 'Activate & Launch Station', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
