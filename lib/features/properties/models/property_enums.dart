/// Type de bien recherché/publié.
enum PropertyType {
  logement,
  terrain,
  magasin;

  String get label => switch (this) {
        PropertyType.logement => 'Logement',
        PropertyType.terrain => 'Terrain',
        PropertyType.magasin => 'Magasin',
      };

  static PropertyType fromString(String value) => PropertyType.values
      .firstWhere((e) => e.name == value, orElse: () => PropertyType.logement);
}

/// Type de transaction.
enum TransactionType {
  location,
  vente;

  String get label => switch (this) {
        TransactionType.location => 'Location',
        TransactionType.vente => 'Vente',
      };

  static TransactionType fromString(String value) => TransactionType.values
      .firstWhere((e) => e.name == value, orElse: () => TransactionType.location);
}

/// Statut de disponibilité d'une propriété. "occupee" (bien loué) et
/// "vendue" (transaction terminée) sont deux statuts distincts, jamais
/// interchangeables : "occupee" n'a de sens que pour une annonce en
/// location, "vendue" que pour une annonce en vente (voir
/// PropertyViewSet.mark_status côté Django, qui refuse toute combinaison
/// incohérente avec transaction_type).
enum PropertyStatus {
  disponible,
  occupee,
  vendue,
  accomplie,
  annulee;

  String get label => switch (this) {
        PropertyStatus.disponible => 'Disponible',
        PropertyStatus.occupee => 'Occupée',
        PropertyStatus.vendue => 'Vendue',
        PropertyStatus.accomplie => 'Accomplie',
        PropertyStatus.annulee => 'Annulée',
      };

  static PropertyStatus fromString(String value) => PropertyStatus.values
      .firstWhere((e) => e.name == value, orElse: () => PropertyStatus.disponible);
}
