import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_formatter.dart';
import '../models/ticket.dart';

enum AlertBannerVariant { error, success, info }

class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.message,
    this.variant = AlertBannerVariant.error,
  });

  final String message;
  final AlertBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (variant) {
      AlertBannerVariant.error => (
          AppColors.cancelled,
          AppColors.cancelledSoft,
          Icons.warning_amber_rounded,
        ),
      AlertBannerVariant.success => (
          AppColors.completed,
          AppColors.completedSoft,
          Icons.check_circle_outline,
        ),
      AlertBannerVariant.info => (
          AppColors.primary,
          AppColors.primarySoft,
          Icons.info_outline,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class RetryableAlertBanner extends StatelessWidget {
  const RetryableAlertBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBanner(message: message),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ),
        ],
      );
}

class RequiredFieldLabel extends StatelessWidget {
  const RequiredFieldLabel(
    this.text, {
    super.key,
    this.isRequired = true,
  });

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          text: text,
          children: isRequired
              ? [
                  TextSpan(
                    text: ' *',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ]
              : null,
        ),
      );
}

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  Widget? content,
  Widget Function(
    BuildContext context,
    String? validationError,
    VoidCallback clearValidationError,
  )? contentBuilder,
  String cancelLabel = 'Kembali',
  IconData? icon,
  Color? iconColor,
  String? Function()? validate,
}) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? validationError;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: icon == null ? null : Icon(icon, color: iconColor),
            title: Text(title),
            content: contentBuilder?.call(
                  context,
                  validationError,
                  () => setDialogState(() => validationError = null),
                ) ??
                content,
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final error = validate?.call();
                        if (error != null) {
                          setDialogState(() => validationError = error);
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      },
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

class TicketActionButton extends StatelessWidget {
  const TicketActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: color),
        ),
        icon: Icon(icon),
        label: Text(label),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      TicketStatuses.waiting => (
          const Color(0xFFB76500),
          AppColors.waitingSoft
        ),
      TicketStatuses.inProgress => (
          AppColors.inProgress,
          AppColors.inProgressSoft
        ),
      TicketStatuses.completed => (
          AppColors.completed,
          AppColors.completedSoft
        ),
      TicketStatuses.cancelled => (
          AppColors.cancelled,
          AppColors.cancelledSoft
        ),
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
      TicketPriorities.emergency => (
          AppColors.cancelled,
          AppColors.cancelledSoft
        ),
      TicketPriorities.urgent => (
          const Color(0xFFAD6309),
          AppColors.waitingSoft
        ),
      TicketPriorities.normal => (
          const Color(0xFF60738D),
          const Color(0xFFEDF2F7)
        ),
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

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.onChanged,
    this.fieldKey,
    this.hint,
    this.errorText,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final String? hint;
  final String? errorText;
  final Widget? prefixIcon;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: widget.fieldKey,
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: !_isVisible,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        autofillHints: widget.autofillHints,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          label: RequiredFieldLabel(widget.label),
          hintText: widget.hint,
          errorText: widget.errorText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: Focus(
            canRequestFocus: false,
            child: IconButton(
              tooltip:
                  _isVisible ? 'Sembunyikan password' : 'Tampilkan password',
              onPressed: widget.enabled
                  ? () => setState(() => _isVisible = !_isVisible)
                  : null,
              icon: Icon(
                _isVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      );
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
            child: Row(
              children: [
                Expanded(
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
                          const Text(
                            '·',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              formatIndonesianDate(ticket.createdAt),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 19,
                  color: AppColors.muted,
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
            child: TicketActionButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              onPressed: onEdit,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TicketActionButton(
              label: 'Batalkan',
              icon: Icons.cancel_outlined,
              color: AppColors.cancelled,
              onPressed: onCancel,
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
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
      ));
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
  });

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final currentPath =
        GoRouter.of(context).routeInformationProvider.value.uri.path;
    final items = isAdmin
        ? [
            (AppRoutes.adminHome, Icons.home_outlined, 'Dashboard'),
            (
              AppRoutes.adminTickets,
              Icons.confirmation_number_outlined,
              'Semua Tiket'
            ),
            (AppRoutes.reports, Icons.bar_chart_outlined, 'Laporan'),
            (AppRoutes.adminProfile, Icons.person_outline, 'Profil'),
          ]
        : [
            (AppRoutes.employeeHome, Icons.home_outlined, 'Beranda'),
            (
              AppRoutes.employeeTickets,
              Icons.confirmation_number_outlined,
              'Tiket Saya'
            ),
            (AppRoutes.employeeProfile, Icons.person_outline, 'Profil'),
          ];
    final homePath = isAdmin ? AppRoutes.adminHome : AppRoutes.employeeHome;
    final selected = items.indexWhere(
      (item) => item.$1 == homePath
          ? currentPath == homePath
          : currentPath.startsWith(item.$1),
    );
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
