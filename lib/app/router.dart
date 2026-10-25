import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/pending_activation_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
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
import '../features/agents/screens/agent_search_screen.dart';
import '../features/bailleurs/screens/bailleur_properties_screen.dart';
import '../features/bailleurs/screens/bailleur_search_screen.dart';
import '../features/profile/screens/agent_dashboard_screen.dart';
import '../features/profile/screens/agent_space_screen.dart';
import '../features/profile/screens/bailleur_dashboard_screen.dart';
import '../features/profile/screens/bailleur_space_screen.dart';
import '../features/profile/screens/contacted_properties_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/my_properties_screen.dart';
import '../features/profile/screens/personal_info_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/sold_properties_screen.dart';
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
    redirect: (context, state) {
      final user = ref.read(authControllerProvider).valueOrNull;
      final location = state.matchedLocation;
      if (user != null && user.needsActivation) {
        if (location != AppRoutes.pendingActivation) {
          return AppRoutes.pendingActivation;
        }
      } else if (user != null && !user.needsActivation && location == AppRoutes.pendingActivation) {
        return AppRoutes.home;
      }
      return null;
    },
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
      GoRoute(
        path: AppRoutes.pendingActivation,
        builder: (context, state) => const PendingActivationScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          phone: Uri.decodeComponent(state.pathParameters['phone']!),
        ),
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
              path: AppRoutes.messages,
              builder: (context, state) => const ConversationsScreen(),
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
                GoRoute(
                  path: 'bailleur',
                  builder: (context, state) => const BailleurSpaceScreen(),
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
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.notifications,
              builder: (context, state) => const NotificationsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: AppRoutes.personalInfo,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PersonalInfoScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.contactedProperties,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ContactedPropertiesScreen(),
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
        path: AppRoutes.soldProperties,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SoldPropertiesScreen(),
      ),
      GoRoute(
        path: AppRoutes.bailleurDashboard,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BailleurDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.agentSearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AgentSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.bailleurSearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BailleurSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.bailleurPublicProperties,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return BailleurPropertiesScreen(
            ownerId: state.pathParameters['id']!,
            ownerName: extra?['ownerName'] as String? ?? '',
          );
        },
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
    ],
  );
});
