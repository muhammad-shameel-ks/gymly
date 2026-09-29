/// Pure-Dart validation for the inquiry quick-add form.
///
/// DESIGN.md: quick-add requires name + phone, note optional.
library;

/// Result of validating the quick-add form.
class LeadFormError {
  const LeadFormError({this.name, this.phone});

  final String? name;
  final String? phone;

  bool get isValid => name == null && phone == null;
}

/// Validates inquiry quick-add input. Returns field errors (null = ok).
LeadFormError validateLeadForm({required String name, required String phone}) {
  String? nameError;
  String? phoneError;

  if (name.trim().isEmpty) {
    nameError = 'Enter a name.';
  }

  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (phone.trim().isEmpty) {
    phoneError = 'Enter a phone number.';
  } else if (digits.length < 7 || digits.length > 15) {
    phoneError = 'Enter a phone number, like 98765 43210.';
  }

  return LeadFormError(name: nameError, phone: phoneError);
}

/// Normalise a phone number for storage/comparison: digits only,
/// stripping a leading country-code-length prefix is NOT done here —
/// identity is the raw digit string per gym (UNIQUE(gym_id, phone)).
String normalizePhone(String phone) => phone.replaceAll(RegExp(r'\D'), '');
