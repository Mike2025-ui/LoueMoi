import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';
import 'package:louemoi/core/widgets/primary_button.dart';
import 'package:louemoi/features/publish/screens/publish_screen.dart';

/// Point 2 — vidéo dans les annonces : UI de sélection/aperçu/remplacement/
/// suppression côté PublishScreen (écran de modification — même écran que
/// la publication, voir editPropertyId).
///
/// La sélection RÉELLE d'une vidéo (ImagePicker) et sa lecture (video_player)
/// dépendent toutes deux d'un canal de plateforme natif, indisponible en
/// environnement `flutter test` — avec ou sans appareil Android, ce canal
/// n'existe pas dans ce contexte. Le code applicatif gère déjà cette absence
/// (try/catch → message d'erreur, jamais un crash) : ces tests vérifient
/// donc ce chemin (bouton → état de chargement → erreur gérée), pas une
/// sélection/lecture réelle sur téléphone (voir rapport final).
void main() {
  Property makeProperty({String? video}) {
    return Property(
      id: 'p1',
      title: 'Villa test',
      description: 'Une belle villa.',
      type: PropertyType.logement,
      category: 'Villa',
      transactionType: TransactionType.location,
      price: 500000,
      city: 'Abidjan',
      commune: 'Cocody',
      district: 'Vallon',
      address: '',
      status: PropertyStatus.disponible,
      images: const ['https://example.com/photo1.jpg'],
      coverImage: 'https://example.com/photo1.jpg',
      video: video,
      features: const [],
      amenities: const [],
      agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  const agentUser = User(
    id: 'a1',
    firstName: 'Mme',
    lastName: 'Kouakou',
    phone: '+225070000000',
    whatsapp: '+225070000000',
    role: UserRole.agent,
  );

  Future<ProviderContainer> pumpEditScreen(
    WidgetTester tester,
    Property property, {
    Future<Property> Function()? onDeleteVideo,
  }) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => AuthController(_FakeAuthRepository(agentUser))),
        propertyRepositoryProvider.overrideWithValue(
          _FakeRepo(property, onDeleteVideo: onDeleteVideo),
        ),
      ],
    );
    addTearDown(container.dispose);
    // authControllerProvider démarre en AsyncValue.loading() (restauration de
    // session asynchrone, voir AuthController) : sans ce réglage immédiat,
    // PublishScreen affiche d'abord son écran "réservé aux agents" (canPublish
    // encore faux). En conditions réelles ceci n'est jamais atteint (cet
    // écran n'est accessible qu'une fois déjà authentifié, l'auth étant
    // résolue dès le splash screen) ; en test, il faut reproduire cette même
    // garantie explicitement.
    container.read(authControllerProvider.notifier).state = AsyncValue.data(agentUser);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PublishScreen(editPropertyId: property.id)),
      ),
    );
    await tester.pumpAndSettle();

    // publishFormProvider n'est plus autoDispose (voir
    // publish_form_autodispose_test.dart pour la régression complète) : plus
    // besoin de réécrire manuellement PublishFormState.fromProperty ici,
    // _loadInitial() l'a déjà fait de façon stable.

    // Ces 4 "Suivant" (titre/prix/commune déjà valides via fromProperty)
    // atteignent l'étape Photos/Vidéo sans déclencher d'erreur de validation.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
    }
    return container;
  }

  testWidgets('sans vidéo existante : bouton "Ajouter une vidéo" affiché', (tester) async {
    await pumpEditScreen(tester, makeProperty());

    expect(find.text('Ajouter une vidéo'), findsOneWidget);
    expect(find.text('Supprimer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avec vidéo existante : options Remplacer/Supprimer affichées', (tester) async {
    await pumpEditScreen(tester, makeProperty(video: 'https://example.com/clip.mp4'));

    expect(find.text('Remplacer'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Ajouter une vidéo'), findsNothing);
  });

  testWidgets('supprimer une vidéo existante appelle deleteVideo et revient à "Ajouter"',
      (tester) async {
    var deleteCalled = false;
    final property = makeProperty(video: 'https://example.com/clip.mp4');
    await pumpEditScreen(
      tester,
      property,
      onDeleteVideo: () async {
        deleteCalled = true;
        return Property.fromJson({...property.toJson(), 'video': null});
      },
    );

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(deleteCalled, isTrue);
    expect(find.text('Ajouter une vidéo'), findsOneWidget);
    expect(find.text('Supprimer'), findsNothing);
  });

  testWidgets('échec de suppression : message d\'erreur affiché, la vidéo reste',
      (tester) async {
    final property = makeProperty(video: 'https://example.com/clip.mp4');
    await pumpEditScreen(
      tester,
      property,
      onDeleteVideo: () async => throw Exception('Réseau indisponible'),
    );

    await tester.ensureVisible(find.text('Supprimer'));
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    // La suppression a échoué : les actions restent affichées (rien n'a
    // été retiré localement), et une snackbar d'erreur est affichée.
    expect(find.text('Remplacer'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('"Ajouter une vidéo" affiche un état de chargement puis une erreur gérée '
      '(sélecteur natif en échec)', (tester) async {
    final originalPlatform = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FailingImagePickerPlatform();
    addTearDown(() => ImagePickerPlatform.instance = originalPlatform);

    await pumpEditScreen(tester, makeProperty());

    await tester.ensureVisible(find.text('Ajouter une vidéo'));
    await tester.tap(find.text('Ajouter une vidéo'));
    await tester.pump(); // frame suivant : la sélection est en cours

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Impossible de sélectionner la vidéo.'), findsOneWidget);
  });

  testWidgets('"Remplacer" une vidéo existante suit le même chemin (chargement puis erreur gérée)',
      (tester) async {
    final originalPlatform = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FailingImagePickerPlatform();
    addTearDown(() => ImagePickerPlatform.instance = originalPlatform);

    await pumpEditScreen(tester, makeProperty(video: 'https://example.com/clip.mp4'));

    await tester.ensureVisible(find.text('Remplacer'));
    await tester.tap(find.text('Remplacer'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Impossible de sélectionner la vidéo.'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('aucun débordement à ${width.toInt()}px sur l\'étape Photos/Vidéo', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpEditScreen(tester, makeProperty(video: 'https://example.com/clip.mp4'));

      expect(tester.takeException(), isNull);
    });
  }
}

class _FakeAuthRepository extends MockAuthRepository {
  _FakeAuthRepository(this._user);
  final User _user;

  @override
  Future<User?> restoreSession() async => _user;
}

class _FakeRepo extends MockPropertyRepository {
  _FakeRepo(this._property, {this.onDeleteVideo});

  final Property _property;
  final Future<Property> Function()? onDeleteVideo;

  @override
  Future<Property> fetchPropertyById(String id) async => _property;

  @override
  Future<Property> deleteVideo(String propertyId) {
    if (onDeleteVideo != null) return onDeleteVideo!();
    return Future.value(Property.fromJson({..._property.toJson(), 'video': null}));
  }
}

/// Simule un échec du sélecteur natif (ImagePickerPlatform, mécanisme de
/// test officiel du package image_picker) — sans ce mock, ImagePicker() sans
/// canal de plateforme enregistré reste indéfiniment en attente au lieu
/// d'échouer, ce qui ferait expirer pumpAndSettle plutôt que de refléter
/// l'état réel de l'UI. Reproduit un scénario d'échec réel (permission
/// refusée, sélecteur indisponible...), couvert par le try/catch de
/// _pickVideo dans publish_screen.dart.
class _FailingImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) {
    // Échec après un léger délai (pas synchrone) : laisse l'état de
    // chargement de _pickVideo être réellement observable sur au moins une
    // frame, comme lors d'une vraie interaction utilisateur avec le
    // sélecteur natif.
    return Future.delayed(
      const Duration(milliseconds: 50),
      () => throw Exception('Sélecteur vidéo indisponible (simulation de test).'),
    );
  }
}
