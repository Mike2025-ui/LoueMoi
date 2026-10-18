import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/filters/providers/filter_providers.dart';
import 'package:louemoi/features/home/widgets/main_bottom_nav.dart';
import 'package:louemoi/features/messaging/providers/message_providers.dart';

/// Reproduit la structure réelle de routerProvider (5 branches : Menu,
/// Favoris, Reserves, Messages, Profil) sans le splash/redirect, pour tester
/// MainBottomNav — le vrai widget de production, pas une reconstruction —
/// à des largeurs d'écran étroites. Un RenderFlex overflow est une erreur de
/// layout déterministe détectée par le moteur Flutter réel, pas un mock.
GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainBottomNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (c, s) => const _Placeholder('screen-home')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/favorites', builder: (c, s) => const _Placeholder('screen-favorites')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reservations', builder: (c, s) => const _Placeholder('screen-reservations')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/messages', builder: (c, s) => const _Placeholder('screen-messages')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (c, s) => const _Placeholder('screen-profile')),
          ]),
        ],
      ),
    ],
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

Future<void> _pumpAt(WidgetTester tester, Size size, {List<Override> extraOverrides = const []}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      // Layout uniquement : le badge non-lu n'a pas besoin de données
      // réelles ici, seulement d'être résolu immédiatement — sans ça, le
      // délai simulé de MockMessageRepository (300ms) laisse un timer en
      // attente à la fin du test.
      overrides: [
        conversationsProvider.overrideWith((ref) async => const []),
        ...extraOverrides,
      ],
      child: MaterialApp.router(routerConfig: _buildTestRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

/// canPublish (voir MainBottomNav) exige un agent/bailleur connecté pour que
/// le FAB apparaisse — sans ça, MockAuthRepository.restoreSession() renvoie
/// null par défaut et le FAB n'existe simplement pas dans l'arbre.
class _FakeAgentAuthRepository extends MockAuthRepository {
  @override
  Future<User?> restoreSession() async => const User(
        id: 'a1',
        firstName: 'Mme',
        lastName: 'Kouakou',
        phone: '+225070000000',
        whatsapp: '+225070000000',
        role: UserRole.agent,
      );
}

void main() {
  // Largeurs demandées par l'audit : 320/360/375/390/412 (mission section 17).
  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('MainBottomNav ne déborde pas à ${width}px de large', (tester) async {
      await _pumpAt(tester, Size(width, 800));

      // Un RenderFlex overflow (ou toute autre exception de layout) est
      // capturé par FlutterError.onError pendant pump — takeException() le
      // remonte ici s'il y en a eu un.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('les 5 onglets et leurs labels sont bien présents, sans doublon', (tester) async {
    await _pumpAt(tester, const Size(375, 800));

    for (final label in ['Menu', 'Favoris', 'Réservations', 'Messages', 'Profil']) {
      expect(find.text(label), findsOneWidget, reason: 'label "$label" attendu une seule fois');
    }
  });

  group('répartition égale des 5 onglets de la barre de navigation', () {
    for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
      testWidgets('les 5 onglets ont une largeur identique à ${width.toInt()}px', (tester) async {
        await _pumpAt(
          tester,
          Size(width, 800),
          extraOverrides: [
            authControllerProvider.overrideWith((ref) => AuthController(_FakeAgentAuthRepository())),
          ],
        );

        final expectedWidth = width / 5;
        for (final label in ['Menu', 'Favoris', 'Réservations', 'Messages', 'Profil']) {
          final buttonFinder = find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          );
          final rect = tester.getRect(buttonFinder.first);
          expect(
            rect.width,
            closeTo(expectedWidth, 1.0),
            reason: 'l\'onglet "$label" doit occuper exactement 1/5 de la barre',
          );
        }

        // Vérifie la présence du FAB de publication pour agent/bailleur
        expect(find.byType(FloatingActionButton), findsOneWidget);
      });
    }
  });

  testWidgets('les labels des onglets ne sont jamais tronqués (ellipsis)', (tester) async {
    // find.text() matche la chaîne du widget Text quel que soit son rendu
    // visuel : un Text avec overflow: TextOverflow.ellipsis contient encore
    // exactement "Réservations" en mémoire même quand il s'affiche
    // "Rése..." à l'écran — le test précédent ne détecte donc pas la
    // troncature visuelle. On vérifie ici explicitement qu'aucun label n'est
    // configuré pour se couper (FittedBox le réduit à la place, voir
    // main_bottom_nav.dart) — à la plus petite largeur auditée (320px), là
    // où l'espace par onglet est le plus contraint.
    await _pumpAt(tester, const Size(320, 800));

    for (final label in ['Menu', 'Favoris', 'Réservations', 'Messages', 'Profil']) {
      final textWidget = tester.widget<Text>(find.text(label));
      expect(
        textWidget.overflow,
        isNot(TextOverflow.ellipsis),
        reason: 'le label "$label" ne doit pas se couper avec "..."',
      );
    }
  });

  testWidgets('le bouton plus pour la publication apparait uniquement dans Menu', (tester) async {
    await _pumpAt(
      tester,
      const Size(375, 800),
      extraOverrides: [
        authControllerProvider.overrideWith((ref) => AuthController(_FakeAgentAuthRepository())),
      ],
    );

    // Dans l'onglet Menu (index 0) : le FAB est visible
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // On navigue vers Favoris (index 1) : le FAB disparaît
    await tester.tap(find.text('Favoris'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // On navigue vers Réservations (index 2) : pas de FAB
    await tester.tap(find.text('Réservations'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // On navigue vers Messages (index 3) : pas de FAB
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // On navigue vers Profil (index 4) : pas de FAB
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);

    // Retour sur Menu (index 0) : le FAB réapparaît
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('le bouton plus est masqué quand la feuille de filtres est ouverte', (tester) async {
    await _pumpAt(
      tester,
      const Size(375, 800),
      extraOverrides: [
        authControllerProvider.overrideWith((ref) => AuthController(_FakeAgentAuthRepository())),
        isFiltersSheetOpenProvider.overrideWith((ref) => true),
      ],
    );

    // Même sur l'onglet Menu (index 0) d'un agent/bailleur : le FAB n'apparaît pas
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
