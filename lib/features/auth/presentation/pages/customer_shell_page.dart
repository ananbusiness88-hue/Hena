import 'package:flutter/material.dart';

import '../../../catalog/presentation/pages/store_categories_page.dart';
import '../../../checkout/presentation/pages/customer_order_tracking_page.dart';

class CustomerShellPage extends StatefulWidget {
  const CustomerShellPage({super.key});

  @override
  State<CustomerShellPage> createState() => _CustomerShellPageState();
}

class _CustomerShellPageState extends State<CustomerShellPage> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    StoreCategoriesPage(),
    const _CustomerPlaceholderPage(icon: Icons.storefront_outlined, title: ''),
    const _CustomerPlaceholderPage(
      icon: Icons.favorite_border_rounded,
      title: '',
    ),
    const CustomerOrderTrackingPage(),
    const _CustomerPlaceholderPage(
      icon: Icons.person_outline_rounded,
      title: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '',
          ),
        ],
      ),
    );
  }
}

class _CustomerPlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CustomerPlaceholderPage({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF087A4B)),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
