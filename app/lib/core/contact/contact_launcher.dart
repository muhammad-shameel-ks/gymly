/// `ContactLauncher` — the one place a phone number leaves the app, into the
/// system dialer or WhatsApp.
///
/// Every Call / WhatsApp action on a lead card, dues card or member record
/// routes through here, so "reach this person" behaves and sounds the same on
/// every surface: one [Haptics.impact] fired here (callers must not fire their
/// own), digits normalised once, and a single failure path that tells the owner
/// what to do next instead of silently doing nothing.
///
/// The launch is deliberately **not** gated on `canLaunchUrl`: on Android 11+
/// and iOS that check returns `false` unless the platform manifest declares the
/// scheme (`<queries>` / `LSApplicationQueriesSchemes`), which would block the
/// launch even when a handler exists. Instead the launch is attempted and a
/// thrown error or a `false` result is treated as failure — the honest signal.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../motion/motion.dart';

/// Opens the dialer or WhatsApp for a lead/member phone number.
abstract final class ContactLauncher {
  /// Opens the phone dialer on [phone]. Shows a SnackBar when it cannot.
  static Future<void> call(BuildContext context, String? phone) async {
    Haptics.impact();
    final digits = _digitsOf(phone);
    if (digits.isEmpty) {
      _tell(context, _noNumber);
      return;
    }
    // A bare 10-digit number is Indian; dial it with the country code. Any
    // other length is already carrying its own code and goes through as-is.
    final number = digits.length == 10 ? '+91$digits' : digits;
    await _launch(
      context,
      Uri(scheme: 'tel', path: number),
      failure: "Couldn't open the dialer. This phone has no calling app.",
    );
  }

  /// Opens WhatsApp (wa.me) for [phone]. Shows a SnackBar when it cannot.
  static Future<void> openWhatsApp(BuildContext context, String? phone) async {
    Haptics.impact();
    final digits = _digitsOf(phone);
    if (digits.isEmpty) {
      _tell(context, _noNumber);
      return;
    }
    // wa.me carries no `+`: the Indian country code leads the digits directly.
    final number = digits.length == 10 ? '91$digits' : digits;
    await _launch(
      context,
      Uri.parse('https://wa.me/$number'),
      failure:
          "Couldn't open WhatsApp. Check that it is installed, then try again.",
    );
  }

  /// Every non-digit removed, so `+91 98123 45678` and `98123-45678` normalise
  /// to the same string.
  static String _digitsOf(String? phone) =>
      phone?.replaceAll(RegExp(r'\D'), '') ?? '';

  /// Attempts [uri] outside the app, then reports [failure] when the platform
  /// refuses or no app answers. Never throws out of here.
  static Future<void> _launch(
    BuildContext context,
    Uri uri, {
    required String failure,
  }) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      _tell(context, failure);
    }
  }

  /// The one SnackBar shape used by this file, guarded for async gaps.
  static void _tell(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static const _noNumber = 'No phone number saved. Add one first.';
}
