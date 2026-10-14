import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../messaging/providers/message_providers.dart';
import '../../properties/models/property.dart';
import '../../properties/providers/property_providers.dart';

/// "Propriétés contactées" — dérivée des conversations réellement ouvertes
/// par l'utilisateur (Conversation.property côté Django), jamais de données
/// inventées. Une conversation sans annonce précise (property=null) est
/// simplement ignorée. Une annonce supprimée entre-temps (fetchPropertyById
/// qui échoue) est aussi ignorée plutôt que de faire planter tout l'écran.
final contactedPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final conversations = await ref.watch(conversationsProvider.future);
  final propertyRepository = ref.watch(propertyRepositoryProvider);

  final propertyIds = conversations
      .map((c) => c.propertyId)
      .whereType<String>()
      .toSet();

  final properties = <Property>[];
  for (final id in propertyIds) {
    try {
      properties.add(await propertyRepository.fetchPropertyById(id));
    } catch (_) {
      // Annonce supprimée/inaccessible entre-temps : ignorée silencieusement.
    }
  }
  return properties;
});
