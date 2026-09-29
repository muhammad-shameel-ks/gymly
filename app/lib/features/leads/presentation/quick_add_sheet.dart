/// Quick-add bottom sheet: name + phone required, note optional.
///
/// Sheet motion comes from [AppTransitions.sheetController] (350–500 ms
/// budget); the fields stagger in once per open; the outcome pairs with one
/// haptic — success on save, error on validation failure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_sheet.dart';
import '../application/leads_providers.dart';
import '../data/lead_validators.dart';

Future<void> showQuickAddSheet(BuildContext context) async {
  Haptics.sheet();
  final controller = AppTransitions.sheetController(
    Navigator.of(context),
    reduceMotion: AppMotionConfig.reduceMotionOf(context),
  );
  try {
    await showAppSheet<void>(
      context,
      transitionAnimationController: controller,
      builder: (_) => const _QuickAddForm(),
    );
  } finally {
    controller.dispose();
  }
}

class _QuickAddForm extends ConsumerStatefulWidget {
  const _QuickAddForm();

  @override
  ConsumerState<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<_QuickAddForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  String? _nameError;
  String? _phoneError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result =
        validateLeadForm(name: _name.text, phone: _phone.text);
    setState(() {
      _nameError = result.name;
      _phoneError = result.phone;
    });
    if (!result.isValid) {
      Haptics.error();
      return;
    }
    final inquiry =
        await ref.read(leadsControllerProvider.notifier).add(
              name: _name.text,
              phone: _phone.text,
              note: _note.text.isEmpty ? null : _note.text,
            );
    if (!mounted) return;
    if (inquiry != null) {
      Haptics.success();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inquiry.name} added to leads.')),
      );
    } else {
      Haptics.error();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Couldn't add this lead. Check your connection, then try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(leadsControllerProvider).isLoading;
    return AppSheet(
      title: 'New lead',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(
            index: 0,
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration:
                  InputDecoration(labelText: 'Name', errorText: _nameError),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 1,
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  InputDecoration(labelText: 'Phone', errorText: _phoneError),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          StaggeredEntrance(
            index: 2,
            child: TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          StaggeredEntrance(
            index: 3,
            child: TapScale(
              // Press feedback only; saving carries the outcome haptic.
              enabled: !saving,
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add lead'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
