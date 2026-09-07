import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../screens/ask_ele/ask_ele_screen.dart';
import '../screens/home_screen.dart';
import '../screens/nutrition/nutrition_log_screen.dart';
import '../screens/performance_screen.dart';
import '../screens/profile_screen.dart';
import 'ef_components.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final int currentIndex;

  const MainLayout({
    Key? key,
    required this.child,
    required this.currentIndex,
  }) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _navigateToPage(index);
  }

  void _navigateToPage(int index) {
    final Widget page;
    switch (index) {
      case 0:  page = const HomeScreen();           break;
      case 1:  page = const NutritionLogScreen();   break;
      case 2:  page = const AskEleScreen();         break;
      case 3:  page = const PerformanceScreen();    break;
      case 4:  page = const ProfileScreen();        break;
      default: page = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      EFPageRoute(
        page: MainLayout(currentIndex: index, child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartModel>().itemCount;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: EFNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
        cartCount: cartCount,
      ),
    );
  }
}
