/// Rôles d'utilisateurs LoueMoi :
/// - client : Utilisateur standard (recherche, favoris, réservation gratuite, messagerie)
/// - agent : Agent immobilier
/// - bailleur : Propriétaire bailleur
/// - admin : Administrateur LoueMoi (gestion exclusive et publication des annonces)
enum UserRole {
  client,
  agent,
  bailleur,
  admin;

  static UserRole fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'admin' => UserRole.admin,
      'agent' => UserRole.agent,
      'bailleur' => UserRole.bailleur,
      _ => UserRole.client,
    };
  }

  String toJson() => name;
}
