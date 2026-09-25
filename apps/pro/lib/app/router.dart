import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/application/session_controller.dart';
import '../core/domain/models.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/onboarding_page.dart';
import '../features/auth/presentation/otp_page.dart';
import '../features/auth/presentation/password_change_page.dart';
import '../features/auth/presentation/profile_choice_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/business/presentation/missions_page.dart';
import '../features/business/presentation/rental_flow_page.dart';
import '../features/chauffeur/presentation/close_trip_page.dart';
import '../features/chauffeur/presentation/drive_page.dart';
import '../features/chauffeur/presentation/route_map_page.dart';
import '../features/common/presentation/help_page.dart';
import '../features/common/presentation/incidents_page.dart';
import '../features/common/presentation/notifications_page.dart';
import '../features/common/presentation/profile_page.dart';
import '../features/common/presentation/sync_page.dart';
import '../features/common/presentation/voyage_page.dart';
import '../features/controleur/presentation/baggage_check_page.dart';
import '../features/controleur/presentation/manual_entry_page.dart';
import '../features/controleur/presentation/scan_history_page.dart';
import '../features/controleur/presentation/scan_page.dart';
import '../features/convoyeur/presentation/baggage_page.dart';
import '../features/convoyeur/presentation/manifest_page.dart';
import '../features/convoyeur/presentation/next_stop_page.dart';
import '../features/convoyeur/presentation/parcels_page.dart';
import '../features/convoyeur/presentation/passenger_page.dart';
import '../features/home/presentation/dashboard_page.dart';
import 'pro_shell.dart';

/// Écrans accessibles sans session (parcours connexion / inscription).
const _guestRoutes = {
  '/login',
  '/inscription',
  '/otp',
  '/mot-de-passe-oublie',
  '/nouveau-mot-de-passe',
};

const _publicRoutes = {..._guestRoutes, '/onboarding', '/password', '/profil'};

/// Garde d'interface par profil (le serveur reste seul juge des droits :
/// une route masquée ici est aussi refusée côté API).
bool routeAllowed(String location, ProRole role) {
  bool starts(String p) => location == p || location.startsWith('$p/');
  if (starts('/ctrl')) return role == ProRole.controleur;
  if (starts('/conv')) return role == ProRole.convoyeur;
  if (starts('/chauf')) return role == ProRole.chauffeur;
  if (starts('/biz')) return role == ProRole.agentBusiness;
  if (starts('/manifeste')) {
    return role == ProRole.controleur || role == ProRole.convoyeur;
  }
  if (starts('/voyage')) return role != ProRole.agentBusiness;
  return true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      String? only(String target) => loc == target ? null : target;

      if (!s.onboarded) return only('/onboarding');
      if (!s.isAuthenticated) {
        if (!_guestRoutes.contains(loc)) return '/login';
        final pending = ref.read(pendingAuthProvider);
        // Code SMS / nouveau mot de passe : seulement si une vérification
        // est en cours (jamais par lien direct).
        if (loc == '/otp' && pending == null) return '/login';
        if (loc == '/nouveau-mot-de-passe' &&
            !(pending?.purpose == OtpPurpose.reset && pending!.verified)) {
          return '/login';
        }
        return null;
      }
      if (s.mustChangePassword) return only('/password');
      final role = s.activeRole;
      if (role == null) return only('/profil');
      if (_publicRoutes.contains(loc)) return '/home';
      if (!routeAllowed(loc, role)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/inscription', builder: (_, _) => const SignupPage()),
      GoRoute(path: '/otp', builder: (_, _) => const OtpPage()),
      GoRoute(
        path: '/mot-de-passe-oublie',
        builder: (_, s) =>
            ForgotPasswordPage(initialPhone: s.uri.queryParameters['tel']),
      ),
      GoRoute(
        path: '/nouveau-mot-de-passe',
        builder: (_, _) => const PasswordChangePage(reset: true),
      ),
      GoRoute(path: '/password', builder: (_, _) => const PasswordChangePage()),
      GoRoute(path: '/profil', builder: (_, _) => const ProfileChoicePage()),

      // Scan immersif plein écran (sans barre de navigation).
      GoRoute(path: '/ctrl/scan', builder: (_, _) => const ScanPage()),

      ShellRoute(
        builder: (context, state, child) => ProShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const DashboardPage()),
          GoRoute(path: '/voyage', builder: (_, _) => const VoyagePage()),
          GoRoute(
            path: '/manifeste',
            builder: (_, _) => const ManifestPage(),
            routes: [
              GoRoute(
                path: ':pid',
                builder: (_, s) =>
                    PassengerPage(passengerId: s.pathParameters['pid']!),
              ),
            ],
          ),
          GoRoute(
            path: '/alertes',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/sync', builder: (_, _) => const SyncPage()),
          GoRoute(path: '/help', builder: (_, _) => const HelpPage()),
          GoRoute(
            path: '/incidents',
            builder: (_, s) => IncidentsPage(
              openReport: s.uri.queryParameters['nouveau'] == '1',
            ),
          ),

          // Contrôleur
          GoRoute(
            path: '/ctrl/manuel',
            builder: (_, _) => const ManualEntryPage(),
          ),
          GoRoute(
            path: '/ctrl/historique',
            builder: (_, _) => const ScanHistoryPage(),
          ),
          GoRoute(
            path: '/ctrl/bagages',
            builder: (_, _) => const BaggageCheckPage(),
          ),

          // Convoyeur
          GoRoute(path: '/conv/arret', builder: (_, _) => const NextStopPage()),
          GoRoute(
            path: '/conv/bagages',
            builder: (_, _) => const BaggagePage(),
          ),
          GoRoute(path: '/conv/colis', builder: (_, _) => const ParcelsPage()),

          // Chauffeur
          GoRoute(path: '/chauf/actif', builder: (_, _) => const DrivePage()),
          GoRoute(
            path: '/chauf/itineraire',
            builder: (_, _) => const RouteMapPage(),
          ),
          GoRoute(
            path: '/chauf/cloture',
            builder: (_, _) => const CloseTripPage(),
          ),

          // Agents BUSINESS
          GoRoute(
            path: '/biz/missions',
            builder: (_, _) => const MissionsPage(),
          ),
          GoRoute(
            path: '/biz/mission/:id',
            builder: (_, s) => RentalFlowPage(taskId: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/home'),
          child: const Text('Page introuvable — retour à l’accueil'),
        ),
      ),
    ),
  );
});
