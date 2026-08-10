import '../config/env.dart';

/// Résout une source d'image venant du backend Django :
/// - déjà absolue (`http://`/`https://`) → inchangée ;
/// - asset local du bundle Flutter (`assets/...`) → inchangée (mode mock) ;
/// - relative (`/media/...`, typique d'un `ImageField` Django sans contexte
///   de requête) → préfixée par [Env.apiBaseUrl].
String buildMediaUrl(String source) {
  if (source.isEmpty) return source;
  if (source.startsWith('http://') || source.startsWith('https://')) return source;
  if (source.startsWith('assets/')) return source;
  if (source.startsWith('/')) return '${Env.apiBaseUrl}$source';
  return source;
}

/// true si [source] doit être chargée depuis le réseau (après résolution),
/// false si c'est un asset local du bundle Flutter.
bool isNetworkMediaSource(String source) {
  final resolved = buildMediaUrl(source);
  return resolved.startsWith('http://') || resolved.startsWith('https://');
}
