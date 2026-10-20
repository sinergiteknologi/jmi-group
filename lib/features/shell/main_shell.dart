import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../cart/cart_pages.dart';
import '../catalog/catalog_pages.dart';
import '../home/home_page.dart';
import '../orders/orders_pages.dart';
import '../report/report_pages.dart';
import '../settings/settings_pages.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<AppState>().cartCount;
    final pages = [
      HomePage(onGoCatalog: () => setState(() => _index = 1)),
      const ProductListPage(),
      const OrderStatusPage(),
      const MutationPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final state = context.read<AppState>();
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          );
          await state.refreshCart();
        },
        tooltip: 'Cart',
        child: Badge(
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          child: const Icon(Icons.shopping_cart_outlined),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Mutasi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}
