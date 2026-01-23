import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../screens/home_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/wishlist_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth_screen.dart';

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
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    setState(() {
      _isAuthenticated = token != null;
    });
  }

  void _onItemTapped(int index) async {
    if (index == 5 && !_isAuthenticated) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        ),
      );
      
      if (result == true) {
        await _checkAuthStatus();
        setState(() {
          _selectedIndex = index;
        });
        _navigateToPage(index);
      }
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    _navigateToPage(index);
  }

  void _navigateToPage(int index) {
    Widget page;
    switch (index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const ShopScreen();
        break;
      case 2:
        page = const WishlistScreen();
        break;
      case 3:
        page = const CartScreen();
        break;
      case 4:
        page = const DevicesScreen();
        break;
      case 5:
        page = const ProfileScreen();
        break;
      default:
        page = const HomeScreen();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MainLayout(
          currentIndex: index,
          child: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: AnimatedBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
      ),
    );
  }
} 