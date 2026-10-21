import 'package:flutter/material.dart';

const String appName = 'Expense Tracker';

/// Must match `version:` in pubspec.yaml (checked by a unit test).
const String appVersion = '1.0.0';

const String otherCategory = 'Other';

const List<String> paymentTypes = [
  'Cash',
  'Card',
  'UPI',
  'Net Banking',
  'Wallet',
  'Other',
];

/// Generic account labels. Records saved by earlier builds may contain other
/// values; those are kept and shown as-is.
const List<String> bankAccounts = [
  'Cash',
  'Bank account',
  'Credit card',
  'Wallet',
  'Other',
];

/// Icons are referenced by key (not code point) so release builds can
/// tree-shake the icon font safely.
const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant_rounded,
  'flight': Icons.flight_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'receipt': Icons.receipt_long_rounded,
  'movie': Icons.movie_rounded,
  'health': Icons.medical_services_rounded,
  'payments': Icons.payments_rounded,
  'home': Icons.home_rounded,
  'school': Icons.school_rounded,
  'work': Icons.work_rounded,
  'savings': Icons.savings_rounded,
  'gift': Icons.card_giftcard_rounded,
  'car': Icons.directions_car_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'grocery': Icons.local_grocery_store_rounded,
  'phone': Icons.smartphone_rounded,
  'pets': Icons.pets_rounded,
  'fitness': Icons.fitness_center_rounded,
  'child': Icons.child_friendly_rounded,
  'bolt': Icons.bolt_rounded,
  'trending': Icons.trending_up_rounded,
  'category': Icons.category_rounded,
};

IconData iconForKey(String? key) =>
    categoryIcons[key] ?? Icons.category_rounded;

/// Mid-tone colors that keep enough contrast with white icons in both themes.
const List<int> categoryColors = [
  0xFF0F766E, // teal
  0xFF2563EB, // blue
  0xFF7C3AED, // violet
  0xFFDB2777, // pink
  0xFFDC2626, // red
  0xFFEA580C, // orange
  0xFFCA8A04, // amber
  0xFF16A34A, // green
  0xFF0891B2, // cyan
  0xFF4F46E5, // indigo
  0xFF9333EA, // purple
  0xFF64748B, // slate
];
