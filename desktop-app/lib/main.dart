import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'features/activation/screens/activation_screen.dart';
import 'features/shell/screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final isActivated = prefs.getBool('is_activated') ?? false;
  final orgName = isActivated ? prefs.getString('organization_name') : null;
  final branchName = prefs.getString('branch_name');
  final businessType = prefs.getString('business_type');
  final enabledModules = prefs.getStringList('enabled_modules');

  runApp(
    ProviderScope(
      child: HirallPosApp(
        organizationName: orgName,
        branchName: branchName,
        businessType: businessType,
        enabledModules: enabledModules,
      ),
    ),
  );
}

class HirallPosApp extends ConsumerWidget {
  final String? organizationName;
  final String? branchName;
  final String? businessType;
  final List<String>? enabledModules;

  const HirallPosApp({
    super.key,
    this.organizationName,
    this.branchName,
    this.businessType,
    this.enabledModules,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Primary Grey Theme (Default)
      darkTheme: AppTheme.darkTheme, // Dark Graphite Theme
      themeMode: themeMode,
      home: organizationName != null
          ? MainShellScreen(
              organizationName: organizationName!,
              branchName: branchName ?? 'KERICHO',
              businessType: businessType ?? 'supermarket',
              enabledModules: enabledModules ??
                  const [
                    'cashier',
                    'storekeeping',
                    'accounting',
                    'hr_management',
                    'pos_outlets',
                  ],
            )
          : const ActivationScreen(),
    );
  }
}
