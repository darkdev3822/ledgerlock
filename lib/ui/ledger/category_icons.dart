import 'package:flutter/material.dart';

const _icons = <String, IconData>{
  'product_sales': Icons.storefront_rounded,
  'services': Icons.handshake_outlined,
  'tips': Icons.volunteer_activism_outlined,
  'refunds_given': Icons.undo_rounded,
  'other_income': Icons.add_card_rounded,
  'advertising': Icons.campaign_outlined,
  'platform_fees': Icons.percent_rounded,
  'contract_labor': Icons.groups_outlined,
  'equipment': Icons.computer_rounded,
  'insurance': Icons.shield_outlined,
  'legal_professional': Icons.gavel_rounded,
  'office': Icons.inventory_2_outlined,
  'rent': Icons.home_work_outlined,
  'supplies': Icons.shopping_bag_outlined,
  'taxes_licenses': Icons.badge_outlined,
  'travel': Icons.flight_takeoff_rounded,
  'meals': Icons.restaurant_rounded,
  'utilities': Icons.wifi_rounded,
  'software': Icons.apps_rounded,
  'education': Icons.school_outlined,
  'other_expense': Icons.more_horiz_rounded,
};

IconData categoryIcon(String id) => _icons[id] ?? Icons.label_outline_rounded;
