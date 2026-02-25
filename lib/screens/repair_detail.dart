import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/m.dart';
import '../data/providers.dart';
import '../theme/t.dart';
import '../widgets/w.dart';
import '../data/photo_service.dart';
import 'notify.dart';

class RepairDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const RepairDetailScreen({super.key, required this.jobId});
  @override
  ConsumerState<RepairDetailScreen> createState() => _RDState();
}

class _RDState extends ConsumerState<RepairDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialIndex = ref.read(repairTabIndexProvider(widget.jobId));
    _tabs = TabController(length: 5, vsync: this, initialIndex: initialIndex);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final idx = _tabs.index;
      ref.read(repairTabIndexProvider(widget.jobId).notifier).state = idx;
      _persistTabIndex(widget.jobId, idx);
    });
    _loadSavedTabIndex();
  }

  Future<void> _loadSavedTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'repairTab_${widget.jobId}';
    final saved = prefs.getInt(key);
    if (!mounted || saved == null) return;
    final clamped = saved.clamp(0, 3);
    if (_tabs.index == clamped) return;
    _tabs.index = clamped;
    ref.read(repairTabIndexProvider(widget.jobId).notifier).state = clamped;
  }

  Future<void> _persistTabIndex(String jobId, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'repairTab_$jobId';
    await prefs.setInt(key, index);
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openNotify(Job job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotifySheet(job: job),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Hold ─────────────────────────────────────────────────────
  Future<void> _doHold(Job job) async {
    final reason = await showReasonDialog(
      context,
      title: 'Put Job On Hold',
      icon: '⏸️',
      hint: 'Describe why this job is paused...',
      color: C.yellow,
      presets: [
        'Waiting for customer approval',
        'Customer travelling / unavailable',
        'Awaiting payment / deposit',
        'Part not available locally',
        'Customer changed mind temporarily',
      ],
    );
    if (reason != null && mounted) {
      ref.read(jobsProvider.notifier).putOnHold(job.jobId, reason, 'Current User');
      _snack('Job put on hold', C.yellow);
    }
  }

  // ── Cancel ───────────────────────────────────────────────────
  Future<void> _doCancel(Job job) async {
    final reason = await showReasonDialog(
      context,
      title: 'Cancel Job',
      icon: '❌',
      hint: 'Reason for cancellation...',
      color: C.red,
      presets: [
        'Customer cancelled - bought new device',
        'Customer no show / unresponsive',
        'Part unavailable - cannot repair',
        'Beyond economical repair (BER)',
        'Warranty voided',
        'Customer dispute',
      ],
    );
    if (reason != null && mounted) {
      ref.read(jobsProvider.notifier).cancel(job.jobId, reason, 'Current User');
      _snack('Job cancelled', C.red);
    }
  }

  // ── Reopen ───────────────────────────────────────────────────
  Future<void> _doReopen(Job job) async {
    final reason = await showReasonDialog(
      context,
      title: 'Re-open Job',
      icon: '🔓',
      hint: 'Why is this job being re-opened?',
      color: C.green,
      presets: [
        'Same issue returned (warranty)',
        'Customer reported new problem',
        'QC failed after customer pickup',
        'Additional repair requested',
        'Part failed - replacement needed',
      ],
    );
    if (reason != null && mounted) {
      ref.read(jobsProvider.notifier).reopen(job.jobId, reason, 'Current User');
      _snack('Job re-opened → In Repair', C.green);
    }
  }

  // ── Resume from hold ─────────────────────────────────────────
  void _doResume(Job job) {
    ref.read(jobsProvider.notifier).resumeFromHold(job.jobId, 'Current User');
    _snack('Job resumed from hold', C.primary);
  }

  void _advanceStatus(Job job) {
    final next = C.statusNext(job.status);
    if (next == null) return;
    ref.read(jobsProvider.notifier).updateStatus(job.jobId, next, 'Current User');
  }

  void _addNote(Job job) {
    if (_noteCtrl.text.trim().isEmpty) return;
    ref.read(jobsProvider.notifier).addTimelineNote(job.jobId, _noteCtrl.text.trim(), 'Current User');
    _noteCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider);
    final job = jobs.firstWhere((j) => j.jobId == widget.jobId);
    final sc = C.statusColor(job.status);
    final next = C.statusNext(job.status);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text(job.jobNumber, style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(icon: const Icon(Icons.print_outlined), onPressed: () {}),
          PopupMenuButton<String>(
            color: C.bgElevated,
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'hold') _doHold(job);
              if (v == 'cancel') _doCancel(job);
              if (v == 'resume') _doResume(job);
              if (v == 'reopen') _doReopen(job);
            },
            itemBuilder: (_) => [
              if (job.isActive)
                PopupMenuItem(value: 'hold', child: _menuItem('⏸️', 'Put On Hold', C.yellow)),
              if (job.isActive || job.isOnHold)
                PopupMenuItem(value: 'cancel', child: _menuItem('❌', 'Cancel Job', C.red)),
              if (job.isOnHold)
                PopupMenuItem(value: 'resume', child: _menuItem('▶️', 'Resume Job', C.green)),
              if (job.canBeReopened)
                PopupMenuItem(value: 'reopen', child: _menuItem('🔓', 'Re-open Job', C.green)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(job, sc, next),
          if (job.isUnderWarranty)
            Container(
              width: double.infinity,
              color: C.green.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, size: 14, color: C.green),
                  const SizedBox(width: 8),
                  Text(
                    'This device is currently covered by shop warranty.',
                    style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w600, color: C.green),
                  ),
                ],
              ),
            ),
          Container(
            color: C.bgElevated,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.customerName,
                        style: GoogleFonts.syne(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: C.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${fmtMoney(job.totalAmount)} · ${job.technicianName.isEmpty ? "Unassigned" : job.technicianName}',
                        style: GoogleFonts.syne(
                          fontSize: 11,
                          color: C.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.isOverdue)
                  Text(
                    'Overdue',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: C.red,
                    ),
                  )
                else if (job.isUnderWarranty)
                  Text(
                    'Under Warranty',
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: C.green,
                    ),
                  )
                else if (job.estimatedEndDate.isNotEmpty)
                  Text(
                    job.estimatedEndDate,
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      color: C.textMuted,
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    final phone = job.customerPhone;
                    if (phone.isEmpty) return;
                    _callCustomer(phone);
                  },
                  icon: const Icon(Icons.call, size: 18, color: C.green),
                  tooltip: 'Call customer',
                ),
                IconButton(
                  onPressed: () => _openNotify(job),
                  icon: const Icon(Icons.campaign_outlined, size: 18, color: C.primary),
                  tooltip: 'Notify customer',
                ),
              ],
            ),
          ),
          Container(
            color: C.bgElevated,
            child: TabBar(
              controller: _tabs,
              indicatorColor: C.primary,
              indicatorWeight: 3,
              labelColor: C.primary,
              unselectedLabelColor: C.textMuted,
              labelStyle: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle: GoogleFonts.syne(fontSize: 11),
              tabs: const [
                Tab(text: '📋 Overview'),
                Tab(text: '🧩 Parts'),
                Tab(text: '✏️ Edit'),
                Tab(text: '📷 Photos'),
                Tab(text: '📅 Timeline'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(job: job),
                _PartsTab(job: job),
                _EditTab(job: job),
                _PhotosTab(job: job),
                _TimelineTab(
                  job: job,
                  noteCtrl: _noteCtrl,
                  onAddNote: () => _addNote(job),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(String icon, String label, Color color) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 16)),
    const SizedBox(width: 10),
    Text(label, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
  ]);

  Widget _buildHeader(Job job, Color sc, String? next) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: C.bgElevated,
        boxShadow: [BoxShadow(color: sc.withValues(alpha: 0.08), blurRadius: 20)],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${job.brand} ${job.model}',
                style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 17, color: C.white)),
            if (job.color.isNotEmpty || job.imei.isNotEmpty)
              Text('${job.color}${job.imei.isNotEmpty ? " · IMEI: ${job.imei}" : ""}',
                  style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill('${C.statusIcon(job.status)} ${job.status}', color: sc),
            if (job.reopenCount > 0) ...[
              const SizedBox(height: 4),
              Pill('Re-opened ×${job.reopenCount}', color: C.green, small: true),
            ],
          ]),
        ]),
        const SizedBox(height: 10),
        StatusProgress(job.status),

        if (job.holdReason != null && job.holdReason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sc.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Text(C.statusIcon(job.status), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(job.holdReason!,
                  style: GoogleFonts.syne(fontSize: 12, color: sc))),
            ]),
          ),
        ],

        const SizedBox(height: 10),
        // Info chips
        Row(children: [
          _chip('👤', job.customerName),
          const SizedBox(width: 6),
          _chip('📅', '${job.createdAt.split('T')[0]}→${job.estimatedEndDate}'),
          const SizedBox(width: 6),
          _chip('💰', fmtMoney(job.totalAmount)),
        ]),
        const SizedBox(height: 10),

        // Action buttons
        Row(children: [
          // Primary action based on status
          if (job.isOnHold) ...[
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _doResume(job),
              icon: const Text('▶️', style: TextStyle(fontSize: 14)),
              label: Text('Resume Job', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: C.green, foregroundColor: C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _doCancel(job),
              icon: const Text('❌', style: TextStyle(fontSize: 13)),
              label: Text('Cancel', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: C.red, side: const BorderSide(color: C.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
          ] else if (job.canBeReopened) ...[
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _doReopen(job),
              icon: const Text('🔓', style: TextStyle(fontSize: 14)),
              label: Text('Re-open Job', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: C.green, foregroundColor: C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            if (job.status == 'Completed') ...[
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(context: context,
                    isScrollControlled: true, backgroundColor: Colors.transparent,
                    builder: (_) => NotifySheet(job: job)),
                icon: const Icon(Icons.notifications_outlined, size: 16),
                label: Text('Notify', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: C.primary, side: const BorderSide(color: C.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
            ],
          ] else if (job.isActive) ...[
            if (next != null) Expanded(child: ElevatedButton.icon(
              onPressed: () => _advanceStatus(job),
              icon: Text(C.statusIcon(next), style: const TextStyle(fontSize: 13)),
              label: Text('→ $next',
                  style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                  backgroundColor: sc, foregroundColor: C.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            )),
            if (next != null) const SizedBox(width: 8),
            Expanded(child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _doHold(job),
                icon: const Text('⏸️', style: TextStyle(fontSize: 13)),
                label: Text('Hold', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: C.yellow, side: const BorderSide(color: C.yellow),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              )),
              const SizedBox(width: 6),
              if (job.status == 'Ready for Pickup')
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => showModalBottomSheet(context: context,
                      isScrollControlled: true, backgroundColor: Colors.transparent,
                      builder: (_) => NotifySheet(job: job)),
                  icon: const Icon(Icons.notifications_active_outlined, size: 14),
                  label: Text(job.notificationSent ? 'Resend' : 'Notify',
                      style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: C.green, foregroundColor: C.bg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ))
              else
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _doCancel(job),
                  icon: const Text('❌', style: TextStyle(fontSize: 12)),
                  label: Text('Cancel', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: C.red, side: const BorderSide(color: C.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                )),
            ])),
          ],
        ]),
      ]),
    );
  }

  Widget _chip(String icon, String val) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 10)),
        Text(val, style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, color: C.text),
            overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
//  OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Job job;
  const _OverviewTab({required this.job});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    child: Column(children: [
      // Problem
      SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🔧 Problem', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.bgElevated, borderRadius: BorderRadius.circular(10)),
            child: Text(job.problem, style: GoogleFonts.syne(fontSize: 13, color: C.text, height: 1.6))),
        if (job.notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: C.yellow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.yellow.withValues(alpha: 0.3))),
              child: Text('📝 ${job.notes}',
                  style: GoogleFonts.syne(fontSize: 12, color: C.yellow))),
        ],
      ])),
      const SizedBox(height: 12),
      // Device details
      SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📱 Device', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
        const SizedBox(height: 10),
        ...[['Brand', job.brand], ['Model', job.model], if (job.color.isNotEmpty) ['Color', job.color],
            if (job.imei.isNotEmpty) ['IMEI', job.imei], ['Priority', job.priority],
            ['Technician', job.technicianName.isEmpty ? 'Unassigned' : job.technicianName],
            ['Start Date', job.createdAt.split('T')[0]], ['Expected End', job.estimatedEndDate]]
          .map((r) => Padding(padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              SizedBox(width: 90, child: Text(r[0], style: GoogleFonts.syne(fontSize: 12, color: C.textMuted))),
              Expanded(child: Text(r[1], style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w600, color: C.text))),
            ]))),
        if (job.isOverdue)
          Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: C.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.red.withValues(alpha: 0.3))),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: C.red, size: 16),
                const SizedBox(width: 6),
                Text('This job is OVERDUE!', style: GoogleFonts.syne(fontSize: 12, color: C.red, fontWeight: FontWeight.w700)),
              ])),
      ])),
      const SizedBox(height: 12),
      // Parts
      SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🧩 Parts Used', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
        const SizedBox(height: 10),
        if (job.partsUsed.isEmpty)
          Text('No parts recorded yet', style: GoogleFonts.syne(fontSize: 13, color: C.textDim))
        else ...job.partsUsed.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 13, color: C.text)),
              Text('Qty: ${p.quantity}', style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
            ])),
            Text(fmtMoney(p.price * p.quantity), style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.primary)),
          ]))),
      ])),
      const SizedBox(height: 12),
      CostSummary(parts: job.partsCost, labor: job.laborCost, discount: job.discountAmount, taxRate: 18),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: PBtn(label: '🖨️ Print', onTap: () {}, outline: true, full: true)),
        const SizedBox(width: 10),
        Expanded(child: PBtn(label: '📄 Invoice', onTap: () {}, full: true)),
      ]),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
//  PARTS TAB
// ═══════════════════════════════════════════════════════════════
class _PartsTab extends ConsumerWidget {
  final Job job;
  const _PartsTab({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🧩 Parts Used', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
                    PBtn(
                      label: '+ Add from Inventory',
                      onTap: () => _showAddPartDialog(context, ref, job),
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (job.partsUsed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No parts added from inventory yet.',
                          style: GoogleFonts.syne(fontSize: 13, color: C.textDim)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: job.partsUsed.length,
                    separatorBuilder: (_, __) => const Divider(color: C.border, height: 20),
                    itemBuilder: (_, i) {
                      final p = job.partsUsed[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 13, color: C.text)),
                                Text('Qty: ${p.quantity} · ${fmtMoney(p.price)} each',
                                    style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
                              ],
                            ),
                          ),
                          Text(fmtMoney(p.price * p.quantity),
                              style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.primary)),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removePart(context, ref, job, p),
                            icon: const Icon(Icons.delete_outline, size: 18, color: C.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Parts Cost', style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 13, color: C.textMuted)),
                Text(fmtMoney(job.partsCost), style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 16, color: C.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPartDialog(BuildContext context, WidgetRef ref, Job job) {
    showDialog(
      context: context,
      builder: (context) => _AddPartDialog(job: job),
    );
  }

  Future<void> _removePart(BuildContext context, WidgetRef ref, Job job, PartUsed part) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.bgElevated,
        title: Text('Remove Part?', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: C.white)),
        content: Text('This will also return ${part.quantity} unit(s) back to inventory.',
            style: GoogleFonts.syne(fontSize: 13, color: C.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: C.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = FirebaseDatabase.instance;
        final batch = <String, dynamic>{};
        
        // 1. Update Job partsUsed
        final newList = job.partsUsed.where((p) => p != part).toList();
        final newPartsCost = newList.fold<double>(0, (s, p) => s + (p.price * p.quantity));
        
        // Calculate new total
        final subtotal = job.laborCost + newPartsCost;
        final disc = job.discountAmount;
        const taxRate = 18.0; // Default or from settings
        final taxAmount = (subtotal - disc) * taxRate / 100;
        final newTotal = subtotal - disc + taxAmount;

        final updatedJob = job.copyWith(
          partsUsed: newList,
          partsCost: newPartsCost,
          taxAmount: taxAmount,
          totalAmount: newTotal,
          updatedAt: DateTime.now().toIso8601String(),
        );

        batch['jobs/${job.jobId}/partsUsed'] = newList.map((p) => {
          'productId': p.productId,
          'name': p.name,
          'quantity': p.quantity,
          'price': p.price,
        }).toList();
        batch['jobs/${job.jobId}/partsCost'] = newPartsCost;
        batch['jobs/${job.jobId}/taxAmount'] = taxAmount;
        batch['jobs/${job.jobId}/totalAmount'] = newTotal;
        batch['jobs/${job.jobId}/updatedAt'] = updatedJob.updatedAt;

        // 2. Return stock to inventory
        final products = ref.read(productsProvider);
        final product = products.firstWhere((p) => p.productId == part.productId);
        final newStockQty = product.stockQty + part.quantity;
        
        batch['products/${part.productId}/stockQty'] = newStockQty;
        batch['products/${part.productId}/updatedAt'] = updatedJob.updatedAt;

        // 3. Log stock history
        final histId = 'h_${DateTime.now().millisecondsSinceEpoch}_${part.productId}';
        batch['stock_history/$histId'] = {
          'shopId': job.shopId,
          'productId': part.productId,
          'productName': part.name,
          'oldQty': product.stockQty,
          'newQty': newStockQty,
          'delta': part.quantity,
          'type': 'return_from_job',
          'time': DateTime.now().millisecondsSinceEpoch,
          'by': 'System',
          'jobId': job.jobId,
        };

        await db.ref().update(batch);
        
        // Update local state
        ref.read(jobsProvider.notifier).updateJob(updatedJob);
        ref.read(productsProvider.notifier).adjustQty(part.productId, part.quantity);
        
      } catch (e) {
        debugPrint('Error removing part: $e');
      }
    }
  }
}

class _AddPartDialog extends ConsumerStatefulWidget {
  final Job job;
  const _AddPartDialog({required this.job});

  @override
  ConsumerState<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends ConsumerState<_AddPartDialog> {
  String _search = '';
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final filtered = products.where((p) =>
        p.stockQty > 0 && (_search.isEmpty ||
            p.productName.toLowerCase().contains(_search.toLowerCase()) ||
            p.sku.toLowerCase().contains(_search.toLowerCase()))).toList();

    return AlertDialog(
      backgroundColor: C.bgElevated,
      title: Text('Add Part from Inventory', style: GoogleFonts.syne(fontWeight: FontWeight.w800, color: C.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.syne(fontSize: 13, color: C.text),
              decoration: const InputDecoration(
                hintText: 'Search parts...',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: filtered.isEmpty
                  ? Center(child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('No matching parts in stock.', style: GoogleFonts.syne(color: C.textDim)),
                  ))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.productName, style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.stockQty} in stock · ${fmtMoney(p.sellingPrice)}',
                              style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: C.primary),
                            onPressed: () => _confirmAdd(p),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }

  void _confirmAdd(Product p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: C.bgElevated,
        title: Text('Quantity for ${p.productName}', style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Available: ${p.stockQty}', style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Enter Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(_qtyCtrl.text) ?? 0;
              if (qty > 0 && qty <= p.stockQty) {
                Navigator.pop(context); // Close qty dialog
                Navigator.pop(context); // Close search dialog
                _addPartToJob(p, qty);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid quantity')));
              }
            },
            child: const Text('Add Part'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPartToJob(Product product, int qty) async {
    try {
      final db = FirebaseDatabase.instance;
      final batch = <String, dynamic>{};
      final job = widget.job;
      
      // 1. Update Job partsUsed
      final part = PartUsed(
        productId: product.productId,
        name: product.productName,
        quantity: qty,
        price: product.sellingPrice,
      );
      
      final newList = [...job.partsUsed, part];
      final newPartsCost = newList.fold<double>(0, (s, p) => s + (p.price * p.quantity));
      
      // Calculate new total
      final subtotal = job.laborCost + newPartsCost;
      final disc = job.discountAmount;
      const taxRate = 18.0; // Default
      final taxAmount = (subtotal - disc) * taxRate / 100;
      final newTotal = subtotal - disc + taxAmount;

      final updatedJob = job.copyWith(
        partsUsed: newList,
        partsCost: newPartsCost,
        taxAmount: taxAmount,
        totalAmount: newTotal,
        updatedAt: DateTime.now().toIso8601String(),
      );

      batch['jobs/${job.jobId}/partsUsed'] = newList.map((p) => {
        'productId': p.productId,
        'name': p.name,
        'quantity': p.quantity,
        'price': p.price,
      }).toList();
      batch['jobs/${job.jobId}/partsCost'] = newPartsCost;
      batch['jobs/${job.jobId}/taxAmount'] = taxAmount;
      batch['jobs/${job.jobId}/totalAmount'] = newTotal;
      batch['jobs/${job.jobId}/updatedAt'] = updatedJob.updatedAt;

      // 2. Deduct stock from inventory
      final newStockQty = product.stockQty - qty;
      batch['products/${product.productId}/stockQty'] = newStockQty;
      batch['products/${product.productId}/updatedAt'] = updatedJob.updatedAt;

      // 3. Log stock history
      final histId = 'h_${DateTime.now().millisecondsSinceEpoch}_${product.productId}';
      batch['stock_history/$histId'] = {
        'shopId': job.shopId,
        'productId': product.productId,
        'productName': product.productName,
        'oldQty': product.stockQty,
        'newQty': newStockQty,
        'delta': -qty,
        'type': 'use_in_job',
        'time': DateTime.now().millisecondsSinceEpoch,
        'by': 'System',
        'jobId': job.jobId,
      };

      await db.ref().update(batch);
      
      // Update local state
      ref.read(jobsProvider.notifier).updateJob(updatedJob);
      ref.read(productsProvider.notifier).adjustQty(product.productId, -qty);
      
    } catch (e) {
      debugPrint('Error adding part: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  EDIT TAB
// ═══════════════════════════════════════════════════════════════
class _EditTab extends ConsumerStatefulWidget {
  final Job job;
  const _EditTab({required this.job});
  @override
  ConsumerState<_EditTab> createState() => _EditTabState();
}

class _EditTabState extends ConsumerState<_EditTab>
    with AutomaticKeepAliveClientMixin<_EditTab> {
  late TextEditingController _brand, _model, _imei, _color, _problem, _notes;
  late TextEditingController _parts, _labor, _discount, _tax, _start, _end;
  late String _priority, _techId;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _brand = TextEditingController(text: j.brand);
    _model = TextEditingController(text: j.model);
    _imei = TextEditingController(text: j.imei);
    _color = TextEditingController(text: j.color);
    _problem = TextEditingController(text: j.problem);
    _notes = TextEditingController(text: j.notes);
    _parts = TextEditingController(text: j.partsCost.toStringAsFixed(0));
    _labor = TextEditingController(text: j.laborCost.toStringAsFixed(0));
    _discount = TextEditingController(text: j.discountAmount.toStringAsFixed(0));
    _tax = TextEditingController(text: j.taxAmount.toStringAsFixed(0));
    _start = TextEditingController(text: j.createdAt.split('T')[0]);
    _end = TextEditingController(text: j.estimatedEndDate);
    _priority = j.priority;
    _techId = j.technicianId;
  }

  @override
  void didUpdateWidget(_EditTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.job.partsCost != oldWidget.job.partsCost) {
      _parts.text = widget.job.partsCost.toStringAsFixed(0);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [_brand, _model, _imei, _color, _problem, _notes, _parts, _labor, _discount, _tax, _start, _end]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final techs = ref.read(techsProvider);
    final session = ref.read(currentUserProvider).asData?.value;
    final shopId = session?.shopId ?? '';
    
    final labor = double.tryParse(_labor.text) ?? 0;
    final parts = widget.job.partsCost;
    final disc = double.tryParse(_discount.text) ?? 0;
    final taxRate = double.tryParse(_tax.text) ?? 18;
    
    final subtotal = labor + parts;
    final taxAmount = (subtotal - disc) * taxRate / 100;
    final total = subtotal - disc + taxAmount;

    final updated = widget.job.copyWith(
      brand: _brand.text, model: _model.text, imei: _imei.text, color: _color.text,
      problem: _problem.text, notes: _notes.text, priority: _priority, technicianId: _techId,
      technicianName: techs.firstWhere((t) => t.techId == _techId, orElse: () => Technician(techId: '', shopId: shopId, name: 'Unassigned')).name,
      estimatedEndDate: _end.text,
      laborCost: labor,
      partsCost: parts,
      discountAmount: disc,
      taxAmount: taxAmount,
      totalAmount: total,
      updatedAt: DateTime.now().toIso8601String(),
    );

    // Save to Firebase
    try {
      final db = FirebaseDatabase.instance;
      db.ref('jobs/${widget.job.jobId}').update({
        'brand': updated.brand,
        'model': updated.model,
        'imei': updated.imei,
        'color': updated.color,
        'problem': updated.problem,
        'notes': updated.notes,
        'priority': updated.priority,
        'technicianId': updated.technicianId,
        'technicianName': updated.technicianName,
        'estimatedEndDate': updated.estimatedEndDate,
        'laborCost': updated.laborCost,
        'partsCost': updated.partsCost,
        'discountAmount': updated.discountAmount,
        'taxAmount': updated.taxAmount,
        'totalAmount': updated.totalAmount,
        'updatedAt': updated.updatedAt,
      });
    } catch (e) {
      debugPrint('Error saving job: $e');
    }

    ref.read(jobsProvider.notifier).updateJob(updated);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final techs = ref.watch(techsProvider);
    final parts = double.tryParse(_parts.text) ?? 0;
    final labor = double.tryParse(_labor.text) ?? 0;
    final disc = double.tryParse(_discount.text) ?? 0;
    final tax = double.tryParse(_tax.text) ?? 18;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        const SLabel('DEVICE INFO'),
        Row(children: [
          Expanded(child: AppField(label: 'Brand', controller: _brand, required: true)),
          const SizedBox(width: 10),
          Expanded(child: AppField(label: 'Model', controller: _model, required: true)),
        ]),
        Row(children: [
          Expanded(child: AppField(label: 'IMEI / Serial', controller: _imei, hint: '*#06#')),
          const SizedBox(width: 10),
          Expanded(child: AppField(label: 'Color', controller: _color)),
        ]),
        AppField(label: 'Problem Description', controller: _problem, maxLines: 3, required: true),
        AppField(label: 'Internal Notes', controller: _notes, maxLines: 2),

        const SLabel('SCHEDULE & ASSIGNMENT'),
        Row(children: [
          Expanded(child: AppField(label: 'Start Date', controller: _start, hint: 'YYYY-MM-DD')),
          const SizedBox(width: 10),
          Expanded(child: AppField(label: 'End Date', controller: _end, hint: 'YYYY-MM-DD')),
        ]),
        AppDropdown<String>(
          label: 'Priority',
          value: _priority,
          onChanged: (v) => setState(() => _priority = v ?? 'Normal'),
          items: ['Normal', 'Urgent', 'Express'].map((p) => DropdownMenuItem(value: p,
              child: Text(p, style: GoogleFonts.syne(fontSize: 13)))).toList(),
        ),
        AppDropdown<String>(
          label: 'Technician',
          value: _techId.isEmpty ? '' : (techs.any((t) => t.techId == _techId) ? _techId : ''),
          onChanged: (v) => setState(() => _techId = v ?? ''),
          items: [
            DropdownMenuItem(value: '', child: Text('Unassigned', style: GoogleFonts.syne(fontSize: 13))),
            ...techs.where((t) => t.isActive).map((t) => DropdownMenuItem(value: t.techId,
                child: Text('${t.name} · ⭐${t.rating}', style: GoogleFonts.syne(fontSize: 13)))),
          ],
        ),

        const SLabel('COSTS & BILLING'),
        Row(children: [
          Expanded(child: AppField(label: 'Parts Cost', controller: _parts, prefixText: '₹',
              readOnly: true, hint: 'Manage in Parts tab',
              keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: AppField(label: 'Labor Cost', controller: _labor, prefixText: '₹',
              keyboardType: TextInputType.number)),
        ]),
        Row(children: [
          Expanded(child: AppField(label: 'Discount', controller: _discount, prefixText: '₹',
              keyboardType: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: AppField(label: 'Tax Rate %', controller: _tax,
              keyboardType: TextInputType.number)),
        ]),
        StatefulBuilder(builder: (_, ss) => CostSummary(parts: parts, labor: labor, discount: disc, taxRate: tax)),
        const SizedBox(height: 16),
        PBtn(label: _saved ? '✅ Saved!' : '💾 Save Changes', onTap: _save, full: true,
            color: _saved ? C.green : C.primary),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PHOTOS TAB
// ═══════════════════════════════════════════════════════════════
class _PhotosTab extends ConsumerStatefulWidget {
  final Job job;
  const _PhotosTab({required this.job});
  @override
  ConsumerState<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends ConsumerState<_PhotosTab> {
  bool _isUploading = false;

  Future<void> _addPhoto(bool isIntake, String path) async {
    setState(() => _isUploading = true);
    try {
      final folder = isIntake ? 'intake' : 'completion';
      final url = await PhotoService.uploadPhoto(path, 'jobs/${widget.job.jobId}/$folder');
      if (url != null) {
        final newJob = isIntake
            ? widget.job.copyWith(intakePhotos: [...widget.job.intakePhotos, url])
            : widget.job.copyWith(completionPhotos: [...widget.job.completionPhotos, url]);
        
        // Update in RTDB
        final db = FirebaseDatabase.instance;
        await db.ref('jobs/${widget.job.jobId}').update({
          isIntake ? 'intakePhotos' : 'completionPhotos': isIntake ? newJob.intakePhotos : newJob.completionPhotos,
        });
        
        // Update in Provider
        ref.read(jobsProvider.notifier).updateJob(newJob);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Upload failed: $e', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
          backgroundColor: C.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removePhoto(bool isIntake, int index) async {
    final list = isIntake ? [...widget.job.intakePhotos] : [...widget.job.completionPhotos];
    list.removeAt(index);
    final newJob = isIntake
        ? widget.job.copyWith(intakePhotos: list)
        : widget.job.copyWith(completionPhotos: list);

    try {
      final db = FirebaseDatabase.instance;
      await db.ref('jobs/${widget.job.jobId}').update({
        isIntake ? 'intakePhotos' : 'completionPhotos': list,
      });
      ref.read(jobsProvider.notifier).updateJob(newJob);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Stack(children: [
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(children: [
          SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📥 Intake Photos', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
            Text('${job.intakePhotos.length} photo(s) at check-in',
                style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
            const SizedBox(height: 12),
            PhotoRow(
              photos: job.intakePhotos,
              label: 'Device condition at intake',
              onPhotoAdded: (path) => _addPhoto(true, path),
              onPhotoRemoved: (idx) => _removePhoto(true, idx),
            ),
          ])),
          const SizedBox(height: 12),
          SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🏁 Completion Photos', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
            Text('${job.completionPhotos.length} photo(s) after repair',
                style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
            const SizedBox(height: 12),
            PhotoRow(
              photos: job.completionPhotos,
              label: 'Device after repair',
              onPhotoAdded: (path) => _addPhoto(false, path),
              onPhotoRemoved: (idx) => _removePhoto(false, idx),
            ),
            if (job.completionPhotos.isEmpty)
              Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: C.yellow.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.yellow.withValues(alpha: 0.3))),
                  child: Text(
                      '⚠️ Add completion photos before marking Ready for Pickup',
                      style: GoogleFonts.syne(fontSize: 12, color: C.yellow))),
          ])),
        ]),
      ),
      if (_isUploading)
        Container(
          color: Colors.black54,
          child: Center(
            child: SCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Uploading Photo...', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
                  Text('Optimizing for < 100 KB', style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
//  TIMELINE TAB
// ═══════════════════════════════════════════════════════════════
class _TimelineTab extends StatelessWidget {
  final Job job;
  final TextEditingController noteCtrl;
  final VoidCallback onAddNote;
  const _TimelineTab({required this.job, required this.noteCtrl, required this.onAddNote});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    child: SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📅 Job Timeline', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
      const SizedBox(height: 14),
      ...job.timeline.asMap().entries.map((e) {
        final i = e.key;
        final entry = e.value;
        final entryColor = C.timelineTypeColor(entry.type);
        final isLast = i == job.timeline.length - 1;
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: entryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: entryColor, width: 2)),
              child: Center(
                  child: Text(_entryIcon(entry.type),
                      style: const TextStyle(fontSize: 12))),
            ),
            if (!isLast) Container(width: 2, height: 36, color: C.border),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(entry.status,
                    style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 13, color: entryColor))),
                Text(entry.time, style: GoogleFonts.syne(fontSize: 10, color: C.textMuted)),
              ]),
              Text('by ${entry.by}', style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: C.bgElevated, borderRadius: BorderRadius.circular(8)),
                    child: Text(entry.note, style: GoogleFonts.syne(fontSize: 12, color: C.text, height: 1.5))),
              ],
              const SizedBox(height: 8),
            ]),
          )),
        ]);
      }),
      const Divider(color: C.border, height: 24),
      Text('ADD NOTE', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, color: C.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      TextFormField(controller: noteCtrl, maxLines: 2,
          style: GoogleFonts.syne(fontSize: 12, color: C.text),
          decoration: const InputDecoration(hintText: 'Add an update or observation...')),
      const SizedBox(height: 10),
      PBtn(label: '+ Add Note', onTap: onAddNote, small: true),
    ])),
  );

  String _entryIcon(String type) {
    const map = {'flow': '→', 'note': '📝', 'hold': '⏸', 'cancel': '✕', 'reopen': '🔓'};
    return map[type] ?? '•';
  }
}
