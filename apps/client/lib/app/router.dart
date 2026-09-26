import 'package:core_api/core_api.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assistant/presentation/assistant_page.dart';
import '../features/auth/presentation/inscription_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/onboarding_page.dart';
import '../features/auth/application/auth_flow.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/auth/presentation/password_reset_pages.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/colis/presentation/colis_detail_page.dart';
import '../features/colis/presentation/colis_new_page.dart';
import '../features/colis/presentation/colis_page.dart';
import '../features/history/presentation/history_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/location/presentation/location_results_page.dart';
import '../features/location/presentation/my_rentals_page.dart';
import '../features/location/presentation/rental_condition_page.dart';
import '../features/location/presentation/rental_detail_page.dart';
import '../features/location/presentation/rental_payment_page.dart';
import '../features/location/presentation/rental_request_page.dart';
import '../features/location/presentation/location_detail_page.dart';
import '../features/location/presentation/location_page.dart';
import '../features/location/presentation/vehicle_reviews_page.dart';
import '../features/loyalty/presentation/loyalty_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/help_page.dart';
import '../features/profile/presentation/personal_info_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/security_page.dart';
import '../features/profile/presentation/settings_page.dart';
import '../features/promotions/presentation/promotion_detail_page.dart';
import '../features/promotions/presentation/promotions_page.dart';
import '../features/tracking/presentation/tracking_page.dart';
import '../features/voyager/presentation/compare_page.dart';
import '../features/voyager/presentation/confirmation_page.dart';
import '../features/voyager/presentation/passengers_page.dart';
import '../features/voyager/presentation/payment_page.dart';
import '../features/voyager/presentation/recap_page.dart';
import '../features/voyager/presentation/seats_page.dart';
import '../features/voyager/presentation/ticket_page.dart';
import '../features/voyager/presentation/trip_detail_page.dart';
import '../features/voyager/presentation/voyager_page.dart';
import '../features/shared/application/analytics.dart';
import '../features/shared/application/providers.dart';
import 'app_shell.dart';

/// Router de l'app MON CAR Client (go_router) — portage de la table
/// de routage du prototype web (`ScreenRouter` + garde auth).
///
/// Chaque GoRoute porte un `name` : c'est lui qui remonte dans Firebase
/// Analytics comme nom d'écran (sinon ce serait le chemin complet, avec
/// les IDs dynamiques — illisible dans le dashboard).
final appRouterProvider = Provider<GoRouter>((ref) {
  // Le router écoute l'état d'auth pour re-évaluer les redirects
  // (connexion/déconnexion en cours de session).
  final auth = ValueNotifier<AuthState>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  final screenObserver = MoncarAnalytics.screenObserver;

  return GoRouter(
    initialLocation: '/',
    observers: [?screenObserver],
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.matchedLocation;
      final loggedIn = auth.value.isAuthenticated;
      final isAuthRoute = path.startsWith('/auth');

      // Garde auth : non connecté → flux d'authentification.
      if (!loggedIn && !isAuthRoute) return '/auth/splash';
      // Connecté mais sur une route d'auth (hors splash) → accueil.
      if (loggedIn && isAuthRoute && path != '/auth/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),

      // ----- Flux d'authentification (hors shell) -----
      GoRoute(
        path: '/auth/splash',
        name: 'auth_splash',
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: '/auth/onboarding',
        name: 'auth_onboarding',
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/auth/inscription',
        name: 'auth_inscription',
        builder: (_, _) => const InscriptionPage(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'auth_login',
        builder: (_, state) =>
            LoginPage(initialPhone: state.uri.queryParameters['phone']),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'auth_otp',
        builder: (_, state) => OtpPage(
          phone: state.uri.queryParameters['phone'] ?? '',
          purpose: OtpPurpose.fromQuery(state.uri.queryParameters['purpose']),
        ),
      ),
      GoRoute(
        path: '/auth/forgot',
        name: 'auth_forgot_password',
        builder: (_, state) => ForgotPasswordPage(
          initialPhone: state.uri.queryParameters['phone'],
        ),
      ),
      GoRoute(
        path: '/auth/reset',
        name: 'auth_reset_password',
        builder: (_, _) => const NewPasswordPage(),
      ),

      // ----- Écrans applicatifs (shell avec bottom nav) -----
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, _) => const HomePage(),
          ),

          // Voyager : recherche, résultats, réservation, billet.
          GoRoute(
            path: '/voyager',
            name: 'voyager',
            builder: (_, _) => const VoyagerPage(),
            routes: [
              GoRoute(
                path: 'compare',
                name: 'voyager_compare',
                builder: (_, _) => const ComparePage(),
              ),
              GoRoute(
                path: 'trip/:tripId',
                name: 'voyager_trip',
                builder: (_, state) =>
                    TripDetailPage(tripId: state.pathParameters['tripId']!),
              ),
              GoRoute(
                path: 'seats/:tripId',
                name: 'voyager_seats',
                builder: (_, state) =>
                    SeatsPage(tripId: state.pathParameters['tripId']!),
              ),
              GoRoute(
                path: 'passengers/:tripId',
                name: 'voyager_passengers',
                builder: (_, state) =>
                    PassengersPage(tripId: state.pathParameters['tripId']!),
              ),
              GoRoute(
                path: 'recap/:bookingId',
                name: 'voyager_recap',
                builder: (_, state) =>
                    RecapPage(bookingId: state.pathParameters['bookingId']!),
              ),
              GoRoute(
                path: 'payment/:bookingId',
                name: 'voyager_payment',
                builder: (_, state) =>
                    PaymentPage(bookingId: state.pathParameters['bookingId']!),
              ),
              GoRoute(
                path: 'confirmation/:bookingId',
                name: 'voyager_confirmation',
                builder: (_, state) => ConfirmationPage(
                  bookingId: state.pathParameters['bookingId']!,
                ),
              ),
              GoRoute(
                path: 'ticket/:ticketId',
                name: 'voyager_ticket',
                builder: (_, state) =>
                    TicketPage(ticketId: state.pathParameters['ticketId']!),
              ),
            ],
          ),

          // Colis.
          GoRoute(
            path: '/colis',
            name: 'colis',
            builder: (_, _) => const ColisPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'colis_new',
                builder: (_, _) => const ColisNewPage(),
              ),
              GoRoute(
                path: ':parcelId',
                name: 'colis_detail',
                builder: (_, state) => ColisDetailPage(
                  parcelId: state.pathParameters['parcelId']!,
                ),
              ),
            ],
          ),

          // Location.
          GoRoute(
            path: '/location',
            name: 'location',
            builder: (_, _) => const LocationPage(),
            routes: [
              GoRoute(
                path: 'veh/:vehicleId',
                name: 'location_vehicule',
                builder: (_, state) => LocationDetailPage(
                  vehicleId: state.pathParameters['vehicleId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'reviews',
                    name: 'location_vehicule_reviews',
                    builder: (_, state) => VehicleReviewsPage(
                      vehicleId: state.pathParameters['vehicleId']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'request/:vehicleId',
                name: 'location_demande',
                builder: (_, state) => RentalRequestPage(
                  vehicleId: state.pathParameters['vehicleId']!,
                  optionIds: [
                    for (final o
                        in (state.uri.queryParameters['options'] ?? '').split(
                          ',',
                        ))
                      if (o.isNotEmpty) o,
                  ],
                ),
              ),
              GoRoute(
                path: 'results',
                name: 'location_resultats',
                builder: (_, _) => const LocationResultsPage(),
              ),
              GoRoute(
                path: 'mine',
                name: 'location_mes_locations',
                builder: (_, _) => const MyRentalsPage(),
              ),
              GoRoute(
                path: 'rental/:rentalId',
                name: 'location_suivi',
                builder: (_, state) => RentalDetailPage(
                  rentalId: state.pathParameters['rentalId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'etat',
                    name: 'location_etat_des_lieux',
                    builder: (_, state) => RentalConditionPage(
                      rentalId: state.pathParameters['rentalId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'pay',
                    name: 'location_paiement',
                    builder: (_, state) => RentalPaymentPage(
                      rentalId: state.pathParameters['rentalId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Profil.
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (_, _) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'info',
                name: 'profile_info',
                builder: (_, _) => const PersonalInfoPage(),
              ),
              GoRoute(
                path: 'security',
                name: 'profile_security',
                builder: (_, _) => const SecurityPage(),
              ),
            ],
          ),

          // Écrans secondaires (push par-dessus le shell).
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/history',
            name: 'history',
            builder: (_, _) => const HistoryPage(),
          ),
          GoRoute(
            path: '/promotions',
            name: 'promotions',
            builder: (_, _) => const PromotionsPage(),
            routes: [
              GoRoute(
                path: ':promoId',
                name: 'promotion_detail',
                builder: (_, state) => PromotionDetailPage(
                  promoId: state.pathParameters['promoId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/loyalty',
            name: 'loyalty',
            builder: (_, _) => const LoyaltyPage(),
          ),
          GoRoute(
            path: '/tracking/:tripId',
            name: 'tracking',
            builder: (_, state) =>
                TrackingPage(tripId: state.pathParameters['tripId']!),
          ),
          GoRoute(
            path: '/help',
            name: 'help',
            builder: (_, _) => const HelpPage(),
          ),
          GoRoute(
            path: '/assistant',
            name: 'assistant',
            builder: (_, _) => const AssistantPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (_, _) => const SettingsPage(),
          ),
        ],
      ),
      // Galerie du design system (dev / recette uniquement, lien dans
      // Paramètres › À propos).
      GoRoute(
        path: '/galerie',
        name: 'galerie',
        builder: (_, _) => MoncarGalleryPage(
          subtitle: 'MON CAR · ${AppEnvironment.current.label}',
          errorMessages: apiErrorMessages,
        ),
      ),
    ],
    errorBuilder: (_, state) => const _NotFoundPage(),
  );
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Cette page n'existe pas ou plus."),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text("Retour à l'accueil"),
            ),
          ],
        ),
      ),
    );
  }
}
