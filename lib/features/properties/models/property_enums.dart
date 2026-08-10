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

/// Statut de disponibilité d'une propriété.
enum PropertyStatus {
  disponible,
  occupee;

  String get label => switch (this) {
        PropertyStatus.disponible => 'Disponible',
        PropertyStatus.occupee => 'Occupée',
      };

  static PropertyStatus fromString(String value) => PropertyStatus.values
      .firstWhere((e) => e.name == value, orElse: () => PropertyStatus.disponible);
}
