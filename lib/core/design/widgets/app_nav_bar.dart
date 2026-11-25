import 'package:flutter/material.dart';

import 'package:assistant/core/design/tokens.dart';

/// Bottom navigation: المجاميع / بحث / السجل / الإعدادات.
class AppNavBar extends StatelessWidget {
  /// Creates the bar highlighting [currentIndex].
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Index of the selected tab (0 = المجاميع).
  final int currentIndex;

  /// Called with the tapped tab index.
  final ValueChanged<int> onTap;

  static const List<({String label, IconData icon})> _items = [
    (label: 'المجاميع', icon: Icons.groups_outlined),
    (label: 'بحث', icon: Icons.search),
    (label: 'السجل', icon: Icons.history),
    (label: 'الإعدادات', icon: Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MnaraColors.card,
        border: Border(top: BorderSide(color: MnaraColors.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    label: _items[i].label,
                    icon: _items[i].icon,
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MnaraColors.text : MnaraColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? MnaraColors.sel : null,
                  borderRadius: BorderRadius.circular(MnaraRadii.pill),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: MnaraText.tiny(color).copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
