import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/ticket.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ticket_provider.dart';
import '../../widgets/helpdesk_widgets.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
            final signature =
                tickets.map((ticket) => '${ticket.id}:${ticket.status}').join('|');
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
                            DateFormat('EEEE, d MMMM', 'id_ID')
                                .format(DateTime.now()),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Halo, ${user.name.trim().split(RegExp(r'\s+')).first}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.business_outlined,
                                size: 15,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                auth.companyName,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        _initials(user.name),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 20, bottom: 2),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    border: Border.all(color: const Color(0xFFCFE0FB)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.headset_mic_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin IT',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Kelola dan selesaikan tiket perusahaan',
                              style: TextStyle(
                                color: Color(0xFF58749A),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Ringkasan tiket'),
                                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                  ),
                  children: [
                    for (final status in TicketStatuses.all)
                      StatusSummaryCard(
                        status: status,
                        count: counts[status] ?? 0,
                      ),
                  ],
                ),
                SectionHeading(
                  title: 'Tiket terbaru',
                  action: TextButton(
                    onPressed: () => context.go(AppRoutes.adminTickets),
                    child: const Text('Lihat semua'),
                  ),
                ),
                if (tickets.isEmpty)
                  const EmptyState(
                    title: 'Belum ada tiket',
                    message: 'Tiket perusahaan akan muncul di sini.',
                  )
                else
                  for (final ticket in tickets.take(2)) ...[
                    TicketCard(
                      ticket: ticket,
                      showReporter: true,
                      onTap: () => context.go(
                        '/admin/tickets/${ticket.id}',
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
        isAdmin: true,
        currentPath: AppRoutes.adminHome,
      ),
    );
  }
}

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
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
        title: const Text('Semua Tiket'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 11),
              child: Text(
                'Tiket ${context.watch<AuthProvider>().companyName}',
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
          final query = _search.text.trim().toLowerCase();
          final filtered = snapshot.data!.where((ticket) {
            final statusMatches =
                _filter == 'Semua' || ticket.status == _filter;
            final textMatches =
                ticket.title.toLowerCase().contains(query) ||
                    ticket.ticketNumber.toLowerCase().contains(query) ||
                    ticket.userName.toLowerCase().contains(query);
            return statusMatches && textMatches;
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  scrollDirection: Axis.horizontal,
                  children: ['Semua', ...TicketStatuses.all]
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: status == _filter,
                            onSelected: (_) =>
                                setState(() => _filter = status),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
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
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ticket = filtered[index];
                          return TicketCard(
                            ticket: ticket,
                            showReporter: true,
                            onTap: () => context.go(
                              '/admin/tickets/${ticket.id}',
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
        isAdmin: true,
        currentPath: AppRoutes.adminTickets,
      ),
    );
  }
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime? _start;
  DateTime? _endExclusive;
  String? _companyId;
  Future<_ReportData?>? _report;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final companyId = context.read<AuthProvider>().user!.companyId;
    if (_companyId != companyId) {
      _companyId = companyId;
      final now = DateTime.now();
      _start = DateTime(now.year, now.month);
      _endExclusive = DateTime(now.year, now.month, now.day + 1);
      _loadReport();
    }
  }

  void _loadReport() {
    final start = _start!;
    final end = _endExclusive!;
    final periodLength = end.difference(start);
    final previousStart = start.subtract(periodLength);
    _report = _fetchReport(
      currentStart: start,
      currentEnd: end,
      previousStart: previousStart,
      previousEnd: start,
    );
  }

  Future<_ReportData?> _fetchReport({
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime previousStart,
    required DateTime previousEnd,
  }) async {
    final provider = context.read<TicketProvider>();
    final current = await provider.ticketsInRange(
      companyId: _companyId!,
      start: currentStart,
      end: currentEnd,
    );
    if (current == null) return null;
    final previous = await provider.ticketsInRange(
      companyId: _companyId!,
      start: previousStart,
      end: previousEnd,
    );
    if (previous == null) return null;
    return _ReportData(current, previous);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _start!,
        end: _endExclusive!.subtract(const Duration(days: 1)),
      ),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _endExclusive = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day + 1,
      );
      _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Laporan'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 20, bottom: 11),
                child: Text(
                  'Performa layanan IT perusahaan',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<_ReportData?>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: 'Laporan gagal dimuat.',
                onRetry: () => setState(_loadReport),
              );
            }
            if (!snapshot.hasData &&
                snapshot.connectionState != ConnectionState.done) {
              return const LoadingState();
            }
            final data = snapshot.data;
            if (data == null) {
              final error = context.watch<TicketProvider>().error;
              return ErrorState(
                message: error ?? 'Laporan gagal dimuat.',
                onRetry: () => setState(_loadReport),
              );
            }
            final tickets = data.current;
            final categories = {
              for (final category in TicketCategories.all) category: 0,
            };
            for (final ticket in tickets) {
              categories.update(
                ticket.category,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
            final orderedCategories = categories.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final maxCategory =
                orderedCategories.isEmpty ? 0 : orderedCategories.first.value;
            final topCategory =
                orderedCategories.isEmpty ? null : orderedCategories.first;
            final previousCount = data.previous.length;
            final percentage = previousCount == 0
                ? null
                : ((tickets.length - previousCount) / previousCount * 100)
                    .round();
            final endInclusive =
                _endExclusive!.subtract(const Duration(days: 1));
            final statuses = {
              for (final status in TicketStatuses.all)
                status: tickets.where((ticket) => ticket.status == status).length,
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              children: [
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rentang tanggal',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              formatIndonesianDateRange(
                                _start!,
                                endInclusive,
                              ),
                              style: const TextStyle(color: AppColors.text),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 4),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total tiket',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .76),
                        ),
                      ),
                      Text(
                        '${tickets.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (percentage != null)
                        Text(
                          '${percentage >= 0 ? '+' : ''}$percentage% dibanding periode sebelumnya',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SectionHeading(title: 'Ringkasan status'),
                                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 9,
                    mainAxisSpacing: 9,
                  ),
                  children: [
                    for (final status in TicketStatuses.all)
                      StatusSummaryCard(
                        status: status,
                        count: statuses[status] ?? 0,
                      ),
                  ],
                ),
                Card(
                  margin: const EdgeInsets.only(top: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Kategori terbanyak',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${tickets.length} tiket',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        for (final category in orderedCategories) ...[
                          Row(
                            children: [
                              Expanded(child: Text(category.key)),
                              Text('${category.value}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: maxCategory == 0
                                  ? 0
                                  : category.value / maxCategory,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFEDF1F6),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
                if (tickets.isNotEmpty && topCategory != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bar_chart_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${topCategory.key} paling sering dilaporkan — ${(topCategory.value / tickets.length * 100).round()}% dari total tiket pada periode ini.',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: const TicketBottomNavigation(
          isAdmin: true,
          currentPath: AppRoutes.reports,
        ),
      );
}

class _ReportData {
  const _ReportData(this.current, this.previous);

  final List<Ticket> current;
  final List<Ticket> previous;
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
    .join();
