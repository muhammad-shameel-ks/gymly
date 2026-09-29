/// `AppSearchBar` — the one search field for list screens.
///
/// Wraps the M3 [SearchBar] with the configuration the members tab already
/// ships (leading magnifier, `Search by name or phone` hint, a clear button
/// that appears only while there is text), so every searchable list looks and
/// sounds the same. Screens own the query: keep it in local state and filter
/// the list, so a keystroke never re-fetches and never drops the list's
/// skeleton or scroll position.
library;

import 'package:flutter/material.dart';

import '../motion/motion.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search by name or phone',
    this.onChanged,
  });

  final TextEditingController controller;

  /// Placeholder shown while the field is empty.
  final String hintText;

  /// Called on every edit, including the clear button (which reports `''`).
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Only this field rebuilds per keystroke: the trailing clear button's
    // presence follows the text, and the owning screen is told via [onChanged].
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => SearchBar(
        controller: controller,
        hintText: hintText,
        onChanged: onChanged,
        leading: const Icon(Icons.search),
        trailing: value.text.isEmpty
            ? null
            : [
                TapScale(
                  // Press feedback; clearing fires its own impact haptic.
                  child: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      Haptics.impact();
                      controller.clear();
                      onChanged?.call('');
                    },
                  ),
                ),
              ],
      ),
    );
  }
}
