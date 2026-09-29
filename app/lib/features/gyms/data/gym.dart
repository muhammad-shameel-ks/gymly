/// One physical gym location belonging to an Owner.
/// All other data is scoped to a gym.
class Gym {
  const Gym({required this.id, required this.ownerId, required this.name});

  final String id;
  final String ownerId;
  final String name;

  factory Gym.fromJson(Map<String, dynamic> json) => Gym(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
      );
}
