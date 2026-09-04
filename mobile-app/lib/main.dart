import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'core/theme/mobile_theme.dart';
import 'core/services/mobile_bridge_client.dart';
import 'features/pairing/screens/pairing_screen.dart';
import 'features/scanner/screens/barcode_gun_screen.dart';
import 'features/inventory/screens/mobile_stock_in_screen.dart';
import 'features/cashier/screens/mobile_cashier_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileBridgeClient.instance.init();
  runApp(const ProviderScope(child: HirallMobileApp()));
}

class HirallMobileApp extends StatelessWidget {
  const HirallMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hirall Mobile Companion',
      debugShowCheckedModeBanner: false,
      theme: MobileTheme.lightTheme,
      darkTheme: MobileTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MobileMainNavigationShell(),
    );
  }
}

class MobileMainNavigationShell extends StatefulWidget {
  const MobileMainNavigationShell({super.key});

  @override
  State<MobileMainNavigationShell> createState() => _MobileMainNavigationShellState();
}

class _MobileMainNavigationShellState extends State<MobileMainNavigationShell> {
  int _currentIndex = 1; // Default to Barcode Gun

  final List<Widget> _screens = const [
    PairingScreen(),
    BarcodeGunScreen(),
    MobileStockInScreen(),
    MobileCashierScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.qrCode),
            selectedIcon: Icon(LucideIcons.qrCode, color: MobileAppColors.primary),
            label: 'Pairing',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.scanBarcode),
            selectedIcon: Icon(LucideIcons.scanBarcode, color: MobileAppColors.primary),
            label: 'Barcode Gun',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.packagePlus),
            selectedIcon: Icon(LucideIcons.packagePlus, color: MobileAppColors.primary),
            label: 'Stock In',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.shoppingCart),
            selectedIcon: Icon(LucideIcons.shoppingCart, color: MobileAppColors.primary),
            label: 'Cashier POS',
          ),
        ],
      ),
    );
  }
}
