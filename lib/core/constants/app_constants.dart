abstract final class AppConstants {
  static const appName = 'IT Helpdesk';
  static const companyCodesCollection = 'company_codes';
  static const companiesCollection = 'companies';
  static const usersCollection = 'users';
  static const ticketsCollection = 'tickets';
  static const updatesCollection = 'updates';
  static const notificationsCollection = 'notifications';
  static const maxTicketTitleLength = 100;
  static const maxTicketDescriptionLength = 1000;
  static const minimumPasswordLength = 8;
  static final emailVerificationEnforcedFrom =
      DateTime.utc(2026, 10, 29, 15, 30);
}

abstract final class UserRoles {
  static const employee = 'user';
  static const admin = 'admin';
  static const all = [employee, admin];
}

abstract final class AccountStatuses {
  static const active = 'active';
  static const inactive = 'inactive';
  static const all = [active, inactive];
}

abstract final class TicketStatuses {
  static const waiting = 'Menunggu';
  static const inProgress = 'Diproses';
  static const completed = 'Selesai';
  static const cancelled = 'Dibatalkan';
  static const all = [waiting, inProgress, completed, cancelled];
  static const adminOptions = [waiting, inProgress, completed];
}

abstract final class TicketPriorities {
  static const emergency = 'CITO';
  static const urgent = 'Segera';
  static const normal = 'Biasa';
  static const all = [emergency, urgent, normal];
}

abstract final class TicketCategories {
  static const computer = 'Komputer/Laptop';
  static const printer = 'Printer';
  static const network = 'Jaringan';
  static const software = 'Aplikasi/Software';
  static const other = 'Lainnya';
  static const all = [computer, printer, network, software, other];
}

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const resetPassword = '/reset-password';
  static const accessDenied = '/access-denied';
  static const employeeHome = '/employee';
  static const employeeTickets = '/employee/tickets';
  static const employeeNotifications = '/employee/notifications';
  static const createTicket = '/employee/tickets/new';
  static const employeeTicketDetail = '/employee/tickets/:ticketId';
  static const editTicket = '/employee/tickets/:ticketId/edit';
  static const employeeProfile = '/employee/profile';
  static const adminHome = '/admin';
  static const adminTickets = '/admin/tickets';
  static const adminTicketDetail = '/admin/tickets/:ticketId';
  static const reports = '/admin/reports';
  static const adminProfile = '/admin/profile';
}
