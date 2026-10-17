import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_formatter.dart';
import '../models/ticket.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      TicketStatuses.waiting => (const Color(0xFFB76500), AppColors.waitingSoft),
      TicketStatuses.inProgress => (AppColors.inProgress, AppColors.inProgressSoft),
      TicketStatuses.completed => (AppColors.completed, AppColors.completedSoft),
      TicketStatuses.cancelled => (AppColors.cancelled, AppColors.cancelledSoft),
      _ => (AppColors.muted, const Color(0xFFEDF2F7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (priority) {
      TicketPriorities.emergency =>
        (AppColors.cancelled, AppColors.cancelledSoft),
      TicketPriorities.urgent =>
        (const Color(0xFFAD6309), AppColors.waitingSoft),
      TicketPriorities.normal =>
        (const Color(0xFF60738D), const Color(0xFFEDF2F7)),
      _ => (AppColors.muted, const Color(0xFFEDF2F7)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.ticket,
    this.showReporter = false,
    this.onTap,
  });

  final Ticket ticket;
  final bool showReporter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.ticketNumber,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    PriorityBadge(priority: ticket.priority),
                    const SizedBox(width: 5),
                    StatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 11),
                Text(
                  ticket.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showReporter) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ticket.userName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ticket.category,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('·', style: TextStyle(color: AppColors.muted)),
                    const SizedBox(width: 8),
                    Text(
                      formatIndonesianDate(ticket.createdAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      size: 19,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class TicketPermissionActions extends StatelessWidget {
  const TicketPermissionActions({
    super.key,
    required this.ticket,
    required this.isAdmin,
    required this.isOwner,
    required this.onEdit,
    required this.onCancel,
    required this.adminActionBuilder,
  });

  final Ticket ticket;
  final bool isAdmin;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Widget Function() adminActionBuilder;

  @override
  Widget build(BuildContext context) {
    if (isAdmin) {
      if (ticket.status == TicketStatuses.cancelled) {
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: AppColors.muted),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiket telah dibatalkan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Status tiket ini tidak dapat diubah.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return adminActionBuilder();
    }

    if (!isOwner || ticket.status != TicketStatuses.waiting) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cancelledSoft,
                foregroundColor: AppColors.cancelled,
              ),
              onPressed: onCancel,
              child: const Text('Batalkan'),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 42,
              color: AppColors.muted,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        title: 'Data gagal dimuat',
        message: message,
        actionLabel: 'Coba lagi',
        onAction: onRetry,
      );
}

class TicketBottomNavigation extends StatelessWidget {
  const TicketBottomNavigation({
    super.key,
    required this.isAdmin,
    required this.currentPath,
  });

  final bool isAdmin;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final items = isAdmin
        ? [
            (AppRoutes.adminHome, Icons.home_outlined, 'Dashboard'),
            (AppRoutes.adminTickets, Icons.confirmation_number_outlined, 'Semua Tiket'),
            (AppRoutes.reports, Icons.bar_chart_outlined, 'Laporan'),
            (AppRoutes.adminProfile, Icons.person_outline, 'Profil'),
          ]
        : [
            (AppRoutes.employeeHome, Icons.home_outlined, 'Beranda'),
            (AppRoutes.employeeTickets, Icons.confirmation_number_outlined, 'Tiket Saya'),
            (AppRoutes.employeeProfile, Icons.person_outline, 'Profil'),
          ];
    final selected = items.indexWhere((item) => currentPath.startsWith(item.$1));
    return NavigationBar(
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) => context.go(items[index].$1),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.$2),
            label: item.$3,
          ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

class StatusSummaryCard extends StatelessWidget {
  const StatusSummaryCard({
    super.key,
    required this.status,
    required this.count,
  });

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TicketStatuses.waiting => AppColors.waiting,
      TicketStatuses.inProgress => AppColors.inProgress,
      TicketStatuses.completed => AppColors.completed,
      TicketStatuses.cancelled => AppColors.cancelled,
      _ => AppColors.muted,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              status,
              style: const TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
