import 'package:flutter_riverpod/legacy.dart';

/// FALLBACK — only used if foundation did not provide its own
/// selected-gym provider. Selected gym id; `null` = All gyms
/// (Home aggregates across gyms when null).
final selectedGymIdProvider = StateProvider<String?>((ref) => null);
