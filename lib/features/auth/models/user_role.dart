/// Les trois seuls types de compte exposés dans l'app mobile. "admin" existe
/// côté Django (is_staff/is_superuser) mais n'est jamais un choix possible
/// ni un espace visible côté Flutter — l'administration reste exclusivement
/// dans Django Admin.
///
/// Bailleur et agent sont deux rôles strictement indépendants : aucune
/// délégation, aucun transfert de propriété entre eux. Les deux peuvent
/// publier/posséder des annonces.
enum UserRole {
  client,
  bailleur,
  agent;

  static UserRole fromString(String? value) {
    return switch (value) {
      'bailleur' => UserRole.bailleur,
      'agent' => UserRole.agent,
      // "admin" existe côté Django via is_staff/is_superuser (voir User.isStaff/isSuperAdmin)
      // et retombe sur client au niveau du rôle enum.
      _ => UserRole.client,
    };
  }

  String toJson() => name;
}
