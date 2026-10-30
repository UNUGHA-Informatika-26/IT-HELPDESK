import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/form_validators.dart';
import '../../models/app_user.dart';
import '../../models/app_notification.dart';
import '../../models/ticket.dart';
import '../../models/ticket_update.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/helpdesk_widgets.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  Stream<List<Ticket>>? _tickets;
  String? _uid;
  String? _countSignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user!;
    if (_uid != user.uid) {
      _uid = user.uid;
      _tickets = context.read<TicketProvider>().watchTickets(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final counts = context.watch<TicketProvider>().counts;
    final today = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Ticket>>(
          stream: _tickets,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Tiket gagal dimuat. Periksa koneksi internet.',
                onRetry: () => setState(
                  () => _tickets =
                      context.read<TicketProvider>().watchTickets(user),
                ),
              );
            }
            if (!snapshot.hasData) return const LoadingState();
            final tickets = snapshot.data!;
            final signature = tickets
                .map((ticket) => '${ticket.id}:${ticket.status}')
                .join('|');
            if (_countSignature != signature) {
              _countSignature = signature;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.read<TicketProvider>().loadCounts(user);
              });
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormatters.weekdayDate(today),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Halo, ${_firstName(user.name)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          _CompanyLine(name: auth.companyName),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pemberitahuan',
                      onPressed: () =>
                          context.go(AppRoutes.employeeNotifications),
                      icon: _NotificationBell(
                        unreadCount:
                            context.watch<NotificationProvider>().unreadCount,
                      ),
                    ),
                    _InitialAvatar(name: user.name),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x331769E0),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Butuh bantuan IT?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Laporkan kendala,\nkami siap membantu.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.createTicket),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(0, 42),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Tiket'),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Ringkasan tiket'),
                Row(
                  children: [
                    for (final status in [
                      TicketStatuses.waiting,
                      TicketStatuses.inProgress,
                      TicketStatuses.completed,
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: StatusSummaryCard(
                            status: status,
                            count: counts[status] ?? 0,
                          ),
                        ),
                      ),
                  ],
                ),
                SectionHeading(
                  title: 'Tiket terbaru',
                  action: TextButton(
                    onPressed: () => context.go(AppRoutes.employeeTickets),
                    child: const Text('Lihat semua'),
                  ),
                ),
                if (tickets.isEmpty)
                  const EmptyState(
                    title: 'Belum ada tiket',
                    message: 'Tiket yang Anda buat akan muncul di sini.',
                  )
                else
                  for (final ticket in tickets.take(2)) ...[
                    TicketCard(
                      ticket: ticket,
                      onTap: () => context.go(
                        '/employee/tickets/${ticket.id}',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                if (context.watch<TicketProvider>().error != null)
                  TextButton.icon(
                    onPressed: () =>
                        context.read<TicketProvider>().loadCounts(user),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      '${context.watch<TicketProvider>().error} · Coba lagi',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const TicketBottomNavigation(
        isAdmin: false,
        currentPath: AppRoutes.employeeHome,
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemberitahuan'),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => context.go(AppRoutes.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.isBusy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await context
                          .read<NotificationProvider>()
                          .markAllRead();
                      if (!context.mounted || ok) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                              context.read<NotificationProvider>().error ??
                                  'Pemberitahuan gagal diperbarui.'),
                        ),
                      );
                    },
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: provider.isLoading
          ? const LoadingState()
          : provider.error != null
              ? ErrorState(
                  message: provider.error!,
                  onRetry: context.read<NotificationProvider>().retry,
                )
              : provider.notifications.isEmpty
                  ? const EmptyState(title: 'Belum ada pemberitahuan')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: provider.notifications.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) => _NotificationTile(
                        notification: provider.notifications[index],
                      ),
                    ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unreadCount > 0)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: AppColors.cancelled,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    final message =
        'Tiket ${notification.ticketNumber} "${notification.ticketTitle}" '
        'dihapus oleh ${notification.adminName}. Alasan: ${notification.reason}';
    return ListTile(
      tileColor: notification.read ? null : AppColors.primarySoft,
      leading: notification.read
          ? const SizedBox(width: 10)
          : const Icon(Icons.circle, size: 9, color: AppColors.primary),
      title: Text(
        message,
        style: TextStyle(
          fontWeight: notification.read ? FontWeight.normal : FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          formatIndonesianDate(notification.createdAt),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
      trailing: IconButton(
        tooltip: 'Hapus pemberitahuan',
        icon: const Icon(Icons.delete_outline),
        color: AppColors.cancelled,
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final ok = await provider.deleteNotification(notification.id);
          if (!context.mounted || ok) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Pemberitahuan gagal dihapus.'),
            ),
          );
        },
      ),
      onTap: notification.read
          ? null
          : () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await provider.markRead(notification.id);
              if (!context.mounted || ok) return;
              messenger.showSnackBar(
                SnackBar(
                  content:
                      Text(provider.error ?? 'Pemberitahuan gagal diperbarui.'),
                ),
              );
            },
    );
  }
}

class EmployeeTicketsScreen extends StatefulWidget {
  const EmployeeTicketsScreen({super.key});

  @override
  State<EmployeeTicketsScreen> createState() => _EmployeeTicketsScreenState();
}

class _EmployeeTicketsScreenState extends State<EmployeeTicketsScreen> {
  final _search = TextEditingController();
  String _filter = 'Semua';
  Stream<List<Ticket>>? _tickets;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user!;
    if (_uid != user.uid) {
      _uid = user.uid;
      _tickets = context.read<TicketProvider>().watchTickets(user);
      context.read<TicketProvider>().loadCounts(user);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiket Saya'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Text(
                '${context.watch<TicketProvider>().counts.values.fold<int>(0, (total, count) => total + count)} tiket ditemukan',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Ticket>>(
        stream: _tickets,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              message: 'Tiket gagal dimuat. Periksa koneksi internet.',
              onRetry: () => setState(
                () => _tickets =
                    context.read<TicketProvider>().watchTickets(user),
              ),
            );
          }
          if (!snapshot.hasData) return const LoadingState();
          final tickets = snapshot.data!;
          final query = _search.text.trim().toLowerCase();
          final filtered = tickets.where((ticket) {
            final matchesStatus =
                _filter == 'Semua' || ticket.status == _filter;
            final matchesSearch = ticket.title.toLowerCase().contains(query) ||
                ticket.ticketNumber.toLowerCase().contains(query);
            return matchesStatus && matchesSearch;
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari judul atau nomor tiket',
                  ),
                ),
              ),
              SizedBox(
                height: 54,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  scrollDirection: Axis.horizontal,
                  children: [
                    'Semua',
                    ...TicketStatuses.all,
                  ]
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: filter == _filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} tiket',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Text(
                      'Terbaru',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'Tiket tidak ditemukan',
                        message: 'Coba ubah pencarian atau filter status.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 3, 18, 18),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ticket = filtered[index];
                          return TicketCard(
                            ticket: ticket,
                            onTap: () => context.go(
                              '/employee/tickets/${ticket.id}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const TicketBottomNavigation(
        isAdmin: false,
        currentPath: AppRoutes.employeeTickets,
      ),
    );
  }
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _category;
  String _priority = TicketPriorities.normal;
  String? _validationError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _validationError = null);
    if (_category == null ||
        _title.text.trim().isEmpty ||
        _description.text.trim().isEmpty) {
      setState(() {
        _validationError = 'Lengkapi semua field wajib sebelum mengirim.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthProvider>().user!;
    final id = await context.read<TicketProvider>().createTicket(
          user: user,
          title: _title.text,
          description: _description.text,
          category: _category!,
          priority: _priority,
        );
    if (!mounted) return;
    if (id != null) {
      final number = Ticket.ticketNumberForId(id);
      context.go(
        '/employee/tickets/$id',
        extra: 'Tiket $number berhasil dibuat',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Tiket'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            Text(
              'Ceritakan kendala Anda',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: const ValueKey('ticket-category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: TicketCategories.all
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              validator: (value) => value == null ? 'Pilih kategori.' : null,
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const ValueKey('ticket-priority'),
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Prioritas'),
              items: TicketPriorities.all
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 8),
            const _PriorityHelp(),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              maxLength: AppConstants.maxTicketTitleLength,
              decoration: const InputDecoration(
                labelText: 'Judul kendala',
                hintText: 'Ringkas dan spesifik',
              ),
              validator: FormValidators.ticketTitle,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 7,
              maxLength: AppConstants.maxTicketDescriptionLength,
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                alignLabelWithHint: true,
              ),
              validator: FormValidators.ticketDescription,
            ),
            if (_validationError != null || provider.error != null) ...[
              const SizedBox(height: 10),
              _MutationError(
                message: _validationError ?? provider.error!,
                onRetry: _submit,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: provider.isBusy ? null : _submit,
              child: Text(provider.isBusy ? 'Mengirim...' : 'Kirim Tiket'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditTicketScreen extends StatefulWidget {
  const EditTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<EditTicketScreen> createState() => _EditTicketScreenState();
}

class _EditTicketScreenState extends State<EditTicketScreen> {
  Stream<Ticket?>? _ticket;
  String? _uid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().user!.uid;
    if (_uid != userId) {
      _uid = userId;
      _ticket = context.read<TicketProvider>().watchTicket(widget.ticketId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit Tiket'),
          leading: IconButton(
            onPressed: () => context.go(
              '/employee/tickets/${widget.ticketId}',
            ),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: StreamBuilder<Ticket?>(
          stream: _ticket,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Tiket gagal dimuat.',
                onRetry: () => setState(
                  () => _ticket = context
                      .read<TicketProvider>()
                      .watchTicket(widget.ticketId),
                ),
              );
            }
            if (!snapshot.hasData) return const LoadingState();
            final ticket = snapshot.data;
            if (ticket == null) {
              return const EmptyState(title: 'Tiket tidak ditemukan');
            }
            if (!ticket.canEdit) {
              return const EmptyState(
                title: 'Tiket tidak dapat diedit',
                message: 'Edit hanya tersedia saat status Menunggu.',
              );
            }
            return _TicketForm(
              ticket: ticket,
              isEditing: true,
              onSubmit: (title, description, category, priority) async {
                final ok = await context.read<TicketProvider>().editTicket(
                      ticketId: ticket.id,
                      title: title,
                      description: description,
                      category: category,
                      priority: priority,
                    );
                if (!context.mounted || !ok) return;
                context.go(
                  '/employee/tickets/${ticket.id}',
                  extra: 'Perubahan tiket berhasil disimpan',
                );
              },
            );
          },
        ),
      );
}

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.isAdmin,
    this.successMessage,
  });

  final String ticketId;
  final bool isAdmin;
  final String? successMessage;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Stream<Ticket?>? _ticket;
  Stream<List<TicketUpdate>>? _updates;
  String? _uid;
  String? _reporterUid;
  Future<AppUser?>? _reporterProfile;
  String? _successMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().user!.uid;
    if (_uid != uid) {
      _uid = uid;
      _ticket = context.read<TicketProvider>().watchTicket(widget.ticketId);
      _updates = context.read<TicketProvider>().watchUpdates(widget.ticketId);
      _successMessage = widget.successMessage;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tiket'),
          leading: IconButton(
            onPressed: () => context.go(
              widget.isAdmin
                  ? AppRoutes.adminTickets
                  : AppRoutes.employeeTickets,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: StreamBuilder<Ticket?>(
          stream: _ticket,
          builder: (context, ticketSnapshot) {
            if (ticketSnapshot.hasError) {
              return ErrorState(
                message: 'Tiket gagal dimuat.',
                onRetry: () => setState(
                  () => _ticket = context
                      .read<TicketProvider>()
                      .watchTicket(widget.ticketId),
                ),
              );
            }
            if (!ticketSnapshot.hasData) return const LoadingState();
            final ticket = ticketSnapshot.data;
            if (ticket == null) {
              return widget.isAdmin
                  ? const EmptyState(title: 'Tiket tidak ditemukan')
                  : EmptyState(
                      title: 'Tiket ini sudah dihapus atau tidak tersedia',
                      actionLabel: 'Kembali ke Tiket Saya',
                      onAction: () => context.go(AppRoutes.employeeTickets),
                    );
            }
            return StreamBuilder<List<TicketUpdate>>(
              stream: _updates,
              builder: (context, updateSnapshot) {
                if (updateSnapshot.hasError) {
                  return ErrorState(
                    message: 'Riwayat status gagal dimuat.',
                    onRetry: () => setState(
                      () => _updates = context
                          .read<TicketProvider>()
                          .watchUpdates(widget.ticketId),
                    ),
                  );
                }
                if (!updateSnapshot.hasData) return const LoadingState();
                return _buildTicket(context, ticket, updateSnapshot.data!);
              },
            );
          },
        ),
      );

  Widget _buildTicket(
    BuildContext context,
    Ticket ticket,
    List<TicketUpdate> updates,
  ) {
    final isOwner = ticket.userId == context.read<AuthProvider>().user!.uid;
    if (widget.isAdmin && _reporterUid != ticket.userId) {
      _reporterUid = ticket.userId;
      _reporterProfile =
          context.read<AuthProvider>().getUserProfile(ticket.userId);
    }
    final history = _timeline(ticket, updates);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        if (_successMessage != null) ...[
          _SuccessBanner(message: _successMessage!),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PriorityBadge(priority: ticket.priority),
                  const SizedBox(width: 6),
                  StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ticket.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                'Dibuat ${formatIndonesianDate(ticket.createdAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi tiket',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _DetailRow(label: 'Kategori', value: ticket.category),
                if (widget.isAdmin) ...[
                  _DetailRow(label: 'Pelapor', value: ticket.userName),
                  FutureBuilder<AppUser?>(
                    future: _reporterProfile,
                    builder: (context, snapshot) => _DetailRow(
                      label: 'Departemen',
                      value: snapshot.hasError
                          ? 'Gagal dimuat'
                          : snapshot.data?.department ?? 'Memuat...',
                    ),
                  ),
                ],
                const Divider(height: 22),
                const Text(
                  'Deskripsi',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(ticket.description),
              ],
            ),
          ),
        ),
        if (!widget.isAdmin && updates.isNotEmpty) ...[
          Card(
            color: const Color(0xFFF3F7FD),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catatan penanganan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(updates.first.note.isEmpty ? '-' : updates.first.note),
                  const SizedBox(height: 8),
                  Text(
                    '— ${updates.first.adminName}, Admin IT',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        TicketPermissionActions(
          ticket: ticket,
          isAdmin: widget.isAdmin,
          isOwner: isOwner,
          onEdit: () => context.go('/employee/tickets/${ticket.id}/edit'),
          onCancel: () => _confirmCancel(context, ticket),
          adminActionBuilder: () => _AdminActionCard(
            key: ValueKey(ticket.status),
            ticket: ticket,
            onSaved: () => setState(
              () => _successMessage = 'Perubahan tiket berhasil disimpan',
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 15),
                for (var index = 0; index < history.length; index++)
                  _TimelineItem(
                    status: history[index].$1,
                    time: history[index].$2,
                    note: history[index].$3,
                    last: index == history.length - 1,
                  ),
              ],
            ),
          ),
        ),
        if ((widget.isAdmin &&
                (ticket.status == TicketStatuses.waiting ||
                    ticket.status == TicketStatuses.cancelled)) ||
            (!widget.isAdmin &&
                isOwner &&
                ticket.status == TicketStatuses.waiting)) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, ticket),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.cancelled,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus tiket'),
          ),
        ],
      ],
    );
  }

  List<(String, DateTime?, String?)> _timeline(
    Ticket ticket,
    List<TicketUpdate> updates,
  ) {
    final List<(String, DateTime?, String?)> items = updates
        .map<(String, DateTime?, String?)>(
          (update) => (update.newStatus, update.createdAt, update.note),
        )
        .toList();
    if (ticket.status == TicketStatuses.cancelled &&
        (items.isEmpty || items.first.$1 != ticket.status)) {
      items.insert(0, (ticket.status, ticket.updatedAt, null));
    }
    items.add((TicketStatuses.waiting, ticket.createdAt, null));
    return items;
  }

  Future<void> _confirmCancel(BuildContext context, Ticket ticket) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon:
            const Icon(Icons.warning_amber_rounded, color: AppColors.cancelled),
        title: const Text('Batalkan tiket?'),
        content: const Text(
          'Tiket tidak akan dihapus, tetapi statusnya berubah menjadi Dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !context.mounted) return;
    final ok = await context.read<TicketProvider>().cancelTicket(ticket.id);
    if (!context.mounted) return;
    if (ok) {
      setState(() => _successMessage = 'Tiket berhasil dibatalkan');
    } else {
      _showError(
        context,
        context.read<TicketProvider>().error,
        () => _retryCancel(ticket.id),
      );
    }
  }

  Future<void> _retryCancel(String ticketId) async {
    final ok = await context.read<TicketProvider>().cancelTicket(ticketId);
    if (!mounted) return;
    if (ok) {
      setState(() => _successMessage = 'Tiket berhasil dibatalkan');
    } else {
      _showError(
        context,
        context.read<TicketProvider>().error,
        () => _retryCancel(ticketId),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Ticket ticket) async {
    String? reason;
    if (widget.isAdmin) {
      final controller = TextEditingController();
      String? validationError;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            icon: const Icon(Icons.delete_outline, color: AppColors.cancelled),
            title: const Text('Hapus tiket?'),
            content: TextField(
              controller: controller,
              maxLength: 300,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan penghapusan',
                errorText: validationError,
                alignLabelWithHint: true,
              ),
              onChanged: (_) {
                if (validationError != null) {
                  setDialogState(() => validationError = null);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Kembali'),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    setDialogState(
                        () => validationError = 'Alasan wajib diisi.');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Ya, Hapus'),
              ),
            ],
          ),
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.delete_outline, color: AppColors.cancelled),
          title: const Text('Hapus tiket?'),
          content: const Text(
            'Tiket dan riwayatnya dihapus permanen dan tidak bisa dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ya, Hapus'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    await _deleteTicket(ticket, reason ?? '');
  }

  Future<void> _deleteTicket(Ticket ticket, String reason) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final provider = context.read<TicketProvider>();
    final ok = widget.isAdmin
        ? await provider.deleteTicketAsAdmin(
            ticket: ticket,
            admin: context.read<AuthProvider>().user!,
            reason: reason,
          )
        : await provider.deleteOwnTicket(ticket.id);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Tiket ${ticket.ticketNumber} berhasil dihapus')),
      );
      router.go(
          widget.isAdmin ? AppRoutes.adminTickets : AppRoutes.employeeTickets);
    } else {
      _showError(
        context,
        provider.error,
        () => _retryDelete(ticket, reason),
      );
    }
  }

  Future<void> _retryDelete(Ticket ticket, String reason) =>
      _deleteTicket(ticket, reason);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.isAdmin});

  final bool isAdmin;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _department = TextEditingController();
  String? _loadedUid;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user!;
    if (_loadedUid != user.uid) {
      _loadedUid = user.uid;
      _name.text = user.name;
      _department.text = user.department;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() {
        _message = 'Nama lengkap wajib diisi.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await context.read<AuthProvider>().updateProfile(
          name: _name.text,
          department: widget.isAdmin ? null : _department.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ok
          ? 'Profil berhasil diperbarui.'
          : context.read<AuthProvider>().error;
      _messageIsError = !ok;
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout, color: AppColors.cancelled),
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk kembali untuk mengakses IT Helpdesk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
    if (shouldLogout == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(23),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 20, bottom: 12),
              child: Text(
                'Kelola informasi akun Anda',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Column(
            children: [
              _InitialAvatar(name: user.name, large: true),
              const SizedBox(height: 10),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _RolePill(label: widget.isAdmin ? 'Admin IT' : 'Karyawan'),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Nama lengkap'),
                  ),
                  const SizedBox(height: 13),
                  _ReadOnlyValue(label: 'Email', value: user.email),
                  if (!widget.isAdmin) ...[
                    const SizedBox(height: 13),
                    TextField(
                      controller: _department,
                      decoration:
                          const InputDecoration(labelText: 'Departemen'),
                    ),
                  ],
                  const SizedBox(height: 13),
                  _ReadOnlyValue(
                    label: 'Perusahaan',
                    value: auth.companyName,
                  ),
                  const SizedBox(height: 13),
                  _ReadOnlyValue(
                    label: 'Role',
                    value: widget.isAdmin ? 'Admin IT' : 'Karyawan',
                  ),
                  if (!widget.isAdmin) ...[
                    const SizedBox(height: 13),
                    _ReadOnlyValue(
                      label: 'Company ID · Status akun',
                      value:
                          '${user.companyId} · ${user.status == AccountStatuses.active ? 'Aktif' : 'Tidak aktif'}',
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy ? 'Menyimpan...' : 'Simpan Perubahan',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _messageIsError
                            ? AppColors.cancelled
                            : AppColors.completed,
                      ),
                    ),
                    if (_messageIsError)
                      TextButton(
                        onPressed: _save,
                        child: const Text('Coba lagi'),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _logout,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cancelledSoft,
              foregroundColor: AppColors.cancelled,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar dari akun'),
          ),
        ],
      ),
      bottomNavigationBar: TicketBottomNavigation(
        isAdmin: widget.isAdmin,
        currentPath:
            widget.isAdmin ? AppRoutes.adminProfile : AppRoutes.employeeProfile,
      ),
    );
  }
}

class _TicketForm extends StatefulWidget {
  const _TicketForm({
    required this.ticket,
    required this.isEditing,
    required this.onSubmit,
  });

  final Ticket ticket;
  final bool isEditing;
  final Future<void> Function(
    String title,
    String description,
    String category,
    String priority,
  ) onSubmit;

  @override
  State<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<_TicketForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.ticket.category;
  late String _priority = widget.ticket.priority;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title.text = widget.ticket.title;
    _description.text = widget.ticket.description;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_category.isEmpty || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    await widget.onSubmit(
      _title.text,
      _description.text,
      _category,
      _priority,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (widget.isEditing) ...[
            const _InfoStrip(
              text: 'Tiket dapat diedit karena masih berstatus Menunggu.',
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: TicketCategories.all
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Prioritas'),
            items: TicketPriorities.all
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
          const SizedBox(height: 8),
          const _PriorityHelp(),
          const SizedBox(height: 14),
          TextFormField(
            controller: _title,
            maxLength: AppConstants.maxTicketTitleLength,
            decoration: const InputDecoration(
              labelText: 'Judul kendala',
              hintText: 'Ringkas dan spesifik',
            ),
            validator: FormValidators.ticketTitle,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 4,
            maxLines: 7,
            maxLength: AppConstants.maxTicketDescriptionLength,
            decoration: const InputDecoration(
              labelText: 'Deskripsi',
              alignLabelWithHint: true,
            ),
            validator: FormValidators.ticketDescription,
          ),
          if (provider.error != null) ...[
            const SizedBox(height: 12),
            _MutationError(
              message: provider.error!,
              onRetry: _submit,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || provider.isBusy ? null : _submit,
            child: Text(
              _busy || provider.isBusy
                  ? 'Menyimpan...'
                  : widget.isEditing
                      ? 'Simpan Perubahan'
                      : 'Kirim Tiket',
            ),
          ),
          if (widget.isEditing)
            TextButton(
              onPressed: () => context.go(
                '/employee/tickets/${widget.ticket.id}',
              ),
              child: const Text('Batal'),
            ),
        ],
      ),
    );
  }
}

class _PriorityHelp extends StatelessWidget {
  const _PriorityHelp();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriorityHelpRow(
            priority: TicketPriorities.emergency,
            text: 'Darurat, contoh: server utama mati',
          ),
          _PriorityHelpRow(
            priority: TicketPriorities.urgent,
            text: 'Perlu cepat, contoh: komputer tidak bisa digunakan',
          ),
          _PriorityHelpRow(
            priority: TicketPriorities.normal,
            text: 'Tidak mendesak, contoh: instalasi aplikasi',
          ),
        ],
      );
}

class _PriorityHelpRow extends StatelessWidget {
  const _PriorityHelpRow({required this.priority, required this.text});

  final String priority;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 63, child: PriorityBadge(priority: priority)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ),
          ],
        ),
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.status,
    required this.time,
    required this.last,
    this.note,
  });

  final String status;
  final DateTime? time;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TicketStatuses.waiting => AppColors.waiting,
      TicketStatuses.inProgress => AppColors.inProgress,
      TicketStatuses.completed => AppColors.completed,
      TicketStatuses.cancelled => AppColors.cancelled,
      _ => AppColors.muted,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: AppColors.line, spreadRadius: 1),
                    ],
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 1, color: AppColors.line),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    formatIndonesianDate(time),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (note != null && note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(note!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatefulWidget {
  const _AdminActionCard({
    super.key,
    required this.ticket,
    required this.onSaved,
  });

  final Ticket ticket;
  final VoidCallback onSaved;

  @override
  State<_AdminActionCard> createState() => _AdminActionCardState();
}

class _AdminActionCardState extends State<_AdminActionCard> {
  late String _status = widget.ticket.status;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tindakan admin',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Ubah status'),
                items: TicketStatuses.adminOptions
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Catatan penanganan',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : () => _save(context),
                  child: Text(_busy ? 'Menyimpan...' : 'Simpan Perubahan'),
                ),
              ),
              if (context.watch<TicketProvider>().error != null)
                _MutationError(
                  message: context.watch<TicketProvider>().error!,
                  onRetry: () => _save(context),
                ),
            ],
          ),
        ),
      );

  Future<void> _save(BuildContext context) async {
    if (_status == TicketStatuses.completed &&
        widget.ticket.status != TicketStatuses.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline,
              color: AppColors.completed),
          title: const Text('Selesaikan tiket?'),
          content: const Text(
            'Pastikan kendala pengguna sudah terselesaikan sebelum melanjutkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ya, Selesaikan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final ok = await context.read<TicketProvider>().handleTicket(
          ticket: widget.ticket,
          admin: auth.user!,
          status: _status,
          note: _note.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onSaved();
  }
}

class _CompanyLine extends StatelessWidget {
  const _CompanyLine({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.business_outlined, size: 15, color: AppColors.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        ],
      );
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, this.large = false});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
    final size = large ? 72.0 : 48.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(large ? 23 : 15),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: large ? 20 : 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(labelText: label),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.completedSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.completed),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.completed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.waitingSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.waiting),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFF9D5B09), fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _MutationError extends StatelessWidget {
  const _MutationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppColors.cancelled, fontSize: 12),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      );
}

void _showError(
  BuildContext context,
  String? error,
  VoidCallback onRetry,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error ?? 'Perubahan tidak berhasil disimpan.'),
      action: SnackBarAction(label: 'Coba lagi', onPressed: onRetry),
    ),
  );
}

String _firstName(String name) =>
    name.trim().split(RegExp(r'\s+')).firstOrNull ?? name;

abstract final class DateFormatters {
  static String weekdayDate(DateTime date) =>
      DateFormat('EEEE, d MMMM', 'id_ID').format(date);
}
