/// Rôles d'utilisateurs LoueMoi :
/// - client : Utilisateur standard (recherche, favoris, réservation gratuite, messagerie)
/// - admin : Administrateur LoueMoi (gestion exclusive et publication des annonces)
enum UserRole {
  client,
  admin;

  static UserRole fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'admin' => UserRole.admin,
      _ => UserRole.client,
    };
  }

  String toJson() => name;
}
