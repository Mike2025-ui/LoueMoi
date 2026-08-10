import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/gallery/screens/gallery_screen.dart';
import '../features/gallery/screens/photo_viewer_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/home/widgets/main_bottom_nav.dart';
import '../features/map/screens/property_map_screen.dart';
import '../features/messaging/screens/conversation_screen.dart';
import '../features/messaging/screens/conversations_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/onboarding/screens/splash_screen.dart';
import '../features/profile/screens/agent_dashboard_screen.dart';
import '../features/profile/screens/agent_space_screen.dart';
import '../features/profile/screens/my_properties_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/properties/screens/property_detail_screen.dart';
import '../features/publish/screens/publish_screen.dart';
import '../features/reservations/screens/congrats_screen.dart';
import '../features/reservations/screens/reservation_confirmation_screen.dart';
import '../features/reservations/screens/reservation_summary_screen.dart';
import '../features/reservations/screens/reservations_list_screen.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainBottomNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.favorites,
              builder: (context, state) => const FavoritesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reservationsList,
              builder: (context, state) => const ReservationsListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'agent',
                  builder: (context, state) => const AgentSpaceScreen(),
                  routes: [
                    GoRoute(
                      path: 'properties',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) => const MyPropertiesScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.publish,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PublishScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProperty,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PublishScreen(editPropertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.agentDashboard,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AgentDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.propertyMap,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PropertyMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.propertyDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.propertyGallery,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            GalleryScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.propertyGalleryViewer,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final images = (extra?['images'] as List?)?.cast<String>() ?? const <String>[];
          final index = extra?['index'] as int? ?? 0;
          return PhotoViewerScreen(images: images, initialIndex: index);
        },
      ),
      GoRoute(
        path: AppRoutes.reservationSummary,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ReservationSummaryScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reservationConfirmation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReservationConfirmationScreen(),
      ),
      GoRoute(
        path: AppRoutes.reservationCongrats,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CongratsScreen(),
      ),
      GoRoute(
        path: AppRoutes.messages,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.conversation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ConversationScreen(
            conversationId: state.pathParameters['id']!,
            participantName: extra?['participantName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
