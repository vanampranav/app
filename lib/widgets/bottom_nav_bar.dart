import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import 'ef_components.dart';

export 'ef_components.dart' show EFNavBar;

// Thin backwards-compat wrapper — new code should use EFNavBar directly.
class AnimatedBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AnimatedBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartModel>().itemCount;
    return EFNavBar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      cartCount: cartCount,
    );
  }
}
