import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'features/auth/auth_screens.dart';
import 'features/admin/admin_screens.dart';
import 'features/employee/employee_screens.dart';
import 'providers/auth_provider.dart';

GoRouter createAppRouter(AuthProvider authProvider) => GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (authProvider.isChecking) {
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        }

        final isAuthRoute = {
          AppRoutes.splash,
          AppRoutes.onboarding,
          AppRoutes.login,
          AppRoutes.register,
          AppRoutes.resetPassword,
        }.contains(location);
        if (!authProvider.isSignedIn) {
          return location.startsWith('/employee') ||
                  location.startsWith('/admin')
              ? AppRoutes.login
              : null;
        }

        if (isAuthRoute) {
          return authProvider.user!.isAdmin
              ? AppRoutes.adminHome
              : AppRoutes.employeeHome;
        }
        if (location.startsWith('/admin') && !authProvider.user!.isAdmin) {
          return AppRoutes.accessDenied;
        }
        if (location.startsWith('/employee') && authProvider.user!.isAdmin) {
          return AppRoutes.accessDenied;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.register,
          builder: (context, state) => const RegisterEmployeeScreen(),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          builder: (context, state) => const ResetPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.accessDenied,
          builder: (context, state) => const AccessDeniedScreen(),
        ),
        GoRoute(
          path: AppRoutes.employeeHome,
          builder: (context, state) => const EmployeeDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.employeeTickets,
          builder: (context, state) => const EmployeeTicketsScreen(),
        ),
        GoRoute(
          path: AppRoutes.employeeNotifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.createTicket,
          builder: (context, state) => const CreateTicketScreen(),
        ),
        GoRoute(
          path: AppRoutes.editTicket,
          builder: (context, state) =>
              EditTicketScreen(ticketId: state.pathParameters['ticketId']!),
        ),
        GoRoute(
          path: AppRoutes.employeeTicketDetail,
          builder: (context, state) => TicketDetailScreen(
            ticketId: state.pathParameters['ticketId']!,
            isAdmin: false,
            successMessage: state.extra as String?,
          ),
        ),
        GoRoute(
          path: AppRoutes.employeeProfile,
          builder: (context, state) => const ProfileScreen(isAdmin: false),
        ),
        GoRoute(
          path: AppRoutes.adminHome,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminTickets,
          builder: (context, state) => const AdminTicketsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminTicketDetail,
          builder: (context, state) => TicketDetailScreen(
            ticketId: state.pathParameters['ticketId']!,
            isAdmin: true,
            successMessage: state.extra as String?,
          ),
        ),
        GoRoute(
          path: AppRoutes.reports,
          builder: (context, state) => const AdminReportsScreen(),
        ),
        GoRoute(
          path: AppRoutes.adminProfile,
          builder: (context, state) => const ProfileScreen(isAdmin: true),
        ),
      ],
    );
