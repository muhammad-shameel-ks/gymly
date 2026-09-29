/// Pure-Dart validation for the plan create/edit form.
///
/// DESIGN.md: plans carry `amount >= 0` (₹) and `duration_days > 0`.
library;

/// Field errors for the plan form (null = ok).
class PlanFormError {
  const PlanFormError({this.name, this.amount, this.durationDays});

  final String? name;
  final String? amount;
  final String? durationDays;

  bool get isValid =>
      name == null && amount == null && durationDays == null;
}

/// Validates plan form input. Amount/duration arrive as raw text from the
/// form fields so parsing errors surface as field errors, not exceptions.
///
/// Every message names the fix in the owner's words (voice spec rule 6: what
/// happened → what to do); none of them blames the owner or says "invalid".
PlanFormError validatePlanForm({
  required String name,
  required String amount,
  required String durationDays,
}) {
  String? nameError;
  String? amountError;
  String? durationError;

  if (name.trim().isEmpty) {
    nameError = 'Enter a plan name.';
  }

  final parsedAmount = num.tryParse(amount.trim());
  if (amount.trim().isEmpty) {
    amountError = 'Enter an amount.';
  } else if (parsedAmount == null) {
    amountError = 'Enter the amount in ₹, like 3333.';
  } else if (parsedAmount < 0) {
    amountError = 'Enter an amount of ₹0 or more.';
  }

  final parsedDays = int.tryParse(durationDays.trim());
  if (durationDays.trim().isEmpty) {
    durationError = 'Enter a duration in days.';
  } else if (parsedDays == null) {
    durationError = 'Enter the duration in whole days.';
  } else if (parsedDays <= 0) {
    durationError = 'Enter a duration of at least 1 day.';
  }

  return PlanFormError(
    name: nameError,
    amount: amountError,
    durationDays: durationError,
  );
}
