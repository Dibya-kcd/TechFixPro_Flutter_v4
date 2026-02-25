import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/m.dart';
import '../data/providers.dart';
import '../theme/t.dart';
import '../widgets/w.dart';
import '../data/photo_service.dart';

class AddRepairScreen extends ConsumerStatefulWidget {
  final Customer? preselectedCustomer;
  const AddRepairScreen({super.key, this.preselectedCustomer});

  @override
  ConsumerState<AddRepairScreen> createState() => _AddRepairState();
}

class _AddRepairState extends ConsumerState<AddRepairScreen> {
  int _step = 0;
  static const _steps = ['Customer', 'Device', 'Problem', 'Schedule', 'Photos', 'Review'];

  // Form state
  late String _custId;
  late final TextEditingController _custName, _custPhone;
  String _brand = '';
  final _model = TextEditingController();
  final _imei = TextEditingController();
  final _color = TextEditingController();
  final _problem = TextEditingController();
  final _notes = TextEditingController();
  String _priority = 'Normal';
  String _techId = '';
  final _startDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final _endDate = TextEditingController();
  final _parts = TextEditingController(text: '0');
  final _labor = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _taxRate = TextEditingController(text: '18');
  List<String> _intakePhotos = [];
  bool _techSynced = false;
  bool _techSyncing = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.preselectedCustomer;
    _custId    = pre?.customerId ?? '';
    _custName  = TextEditingController(text: pre?.name ?? '');
    _custPhone = TextEditingController(text: pre?.phone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_custName, _custPhone, _model, _imei, _color, _problem,
      _notes, _startDate, _endDate, _parts, _labor, _discount, _taxRate]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _sub => (double.tryParse(_parts.text) ?? 0) + (double.tryParse(_labor.text) ?? 0);
  double get _disc => double.tryParse(_discount.text) ?? 0;
  double get _tax => (_sub - _disc) * (double.tryParse(_taxRate.text) ?? 18) / 100;
  double get _total => _sub - _disc + _tax;
  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _syncTechsFromFirebase(String shopId) async {
    try {
      final db = FirebaseDatabase.instance;
      final snap = await db.ref('users')
          .orderByChild('shopId')
          .equalTo(shopId)
          .get();
      final list = <Technician>[];
      if (snap.exists && snap.children.isNotEmpty) {
        for (final child in snap.children) {
          final key = child.key;
          final value = child.value;
          if (key == null || value is! Map) continue;
          final data = Map<String, dynamic>.from(value);
          list.add(Technician(
            techId: key,
            shopId: shopId,
            name: (data['displayName'] as String?) ?? (data['name'] as String?) ?? '',
            phone: (data['phone'] as String?) ?? '',
            specialization: (data['specialization'] as String?) ?? 'General',
            isActive: (data['isActive'] as bool?) ?? true,
            totalJobs: (data['totalJobs'] as int?) ?? (data['jobs'] as int?) ?? 0,
            completedJobs: (data['completedJobs'] as int?) ?? 0,
            rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
            joinedAt: (data['joinedAt'] as String?) ?? '',
          ));
        }
      }
      ref.read(techsProvider.notifier).setAll(list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now();
      final ts = '${now.year}-${_p(now.month)}-${_p(now.day)} ${_p(now.hour)}:${_p(now.minute)}';
      final jId = 'j${now.millisecondsSinceEpoch}';
      final jNum = 'JOB-2025-${1000 + now.millisecond % 8999}';
      final techs = ref.read(techsProvider);
      final custs = ref.read(customersProvider);
      final session = ref.read(currentUserProvider).asData?.value;
      final shopId = session?.shopId ?? '';

      // Upload intake photos to Firebase Storage
      final uploadedPhotos = await PhotoService.uploadPhotos(_intakePhotos, 'jobs/$jId/intake');

      String cName = _custName.text.trim();
      String cPhone = _custPhone.text.trim();
      if (_custId.isNotEmpty) {
        try {
          final existing = custs.firstWhere((c) => c.customerId == _custId);
          cName  = existing.name;
          cPhone = existing.phone;
        } catch (_) {}
      }

      final tech = _techId.isEmpty
          ? Technician(techId: '', shopId: '', name: 'Unassigned')
          : techs.firstWhere((t) => t.techId == _techId,
              orElse: () => Technician(techId: '', shopId: '', name: 'Unassigned'));

      final job = Job(
        jobId: jId, jobNumber: jNum, shopId: shopId,
        customerId: _custId.isEmpty ? jId : _custId,
        customerName: cName, customerPhone: cPhone,
        brand: _brand.isEmpty ? 'Unknown' : _brand,
        model: _model.text.trim().isEmpty ? 'Unknown' : _model.text.trim(),
        imei: _imei.text.trim(), color: _color.text.trim(),
        problem: _problem.text.trim(), notes: _notes.text.trim(),
        status: 'Checked In', priority: _priority,
        technicianId: _techId, technicianName: tech.name,
        createdAt: ts, estimatedEndDate: _endDate.text,
        partsCost: double.tryParse(_parts.text) ?? 0,
        laborCost: double.tryParse(_labor.text) ?? 0,
        discountAmount: double.tryParse(_discount.text) ?? 0,
        totalAmount: 0,
        intakePhotos: uploadedPhotos,
        timeline: [TimelineEntry(status: 'Checked In', time: ts, by: 'Reception',
            note: 'New job created', type: 'flow')],
        updatedAt: ts,
      );
      
      // Calculate totalAmount based on parts, labor, discount, and taxRate
      final subtotal = job.laborCost + job.partsCost;
      final disc = job.discountAmount;
      final taxRate = double.tryParse(_taxRate.text) ?? 18;
      final taxAmount = (subtotal - disc) * taxRate / 100;
      job.taxAmount = taxAmount;
      job.totalAmount = subtotal - disc + taxAmount;

      final db = FirebaseDatabase.instance;
      await db.ref('jobs/$jId').set({
        'jobId': job.jobId,
        'jobNumber': job.jobNumber,
        'shopId': job.shopId,
        'customerId': job.customerId,
        'customerName': job.customerName,
        'customerPhone': job.customerPhone,
        'brand': job.brand,
        'model': job.model,
        'imei': job.imei,
        'color': job.color,
        'problem': job.problem,
        'notes': job.notes,
        'status': job.status,
        'previousStatus': job.previousStatus,
        'holdReason': job.holdReason,
        'priority': job.priority,
        'technicianId': job.technicianId,
        'technicianName': job.technicianName,
        'laborCost': job.laborCost,
        'partsCost': job.partsCost,
        'discountAmount': job.discountAmount,
        'taxAmount': job.taxAmount,
        'totalAmount': job.totalAmount,
        'intakePhotos': job.intakePhotos,
        'completionPhotos': job.completionPhotos,
        'partsUsed': job.partsUsed.map((p) => {
          'productId': p.productId,
          'name': p.name,
          'quantity': p.quantity,
          'price': p.price,
        }).toList(),
        'timeline': job.timeline.map((t) => {
          'status': t.status,
          'time': t.time,
          'by': t.by,
          'note': t.note,
          'type': t.type,
        }).toList(),
        'notificationSent': job.notificationSent,
        'notificationChannel': job.notificationChannel,
        'reopenCount': job.reopenCount,
        'warrantyExpiry': job.warrantyExpiry,
        'invoiceId': job.invoiceId,
        'createdAt': job.createdAt,
        'updatedAt': job.updatedAt,
        'estimatedEndDate': job.estimatedEndDate,
      });
      ref.read(jobsProvider.notifier).addJob(job);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $jNum created!',
              style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
          backgroundColor: C.green, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e',
              style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
          backgroundColor: C.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _canAdvance() {
    switch (_step) {
      case 0: return _custName.text.trim().isNotEmpty && _custPhone.text.trim().isNotEmpty;
      case 1: return _model.text.trim().isNotEmpty;
      case 2: return _problem.text.trim().isNotEmpty;
      case 3: return _endDate.text.isNotEmpty;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(currentUserProvider);
    final session = sessionAsync.asData?.value;
    if (!_techSynced && !_techSyncing && session != null && session.shopId.isNotEmpty) {
      _techSyncing = true;
      _syncTechsFromFirebase(session.shopId).whenComplete(() {
        if (mounted) {
          setState(() {
            _techSynced = true;
            _techSyncing = false;
          });
        }
      });
    }
    assert(() {
      debugPrint(
        '[AddRepairScreen] step=$_step cust="${_custName.text}" device="$_brand ${_model.text}"',
      );
      return true;
    }());

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('New Repair Job', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: Column(children: [
        // Step indicator bar
        Container(
          color: C.bgElevated,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(children: [
            Row(children: List.generate(_steps.length, (i) => Expanded(
              child: Container(
                height: 3, margin: EdgeInsets.only(right: i < _steps.length - 1 ? 3 : 0),
                decoration: BoxDecoration(
                  color: i < _step ? C.primary : i == _step ? C.primary : C.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Step ${_step + 1} of ${_steps.length}',
                  style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
              Text(_steps[_step], style: GoogleFonts.syne(
                  fontSize: 12, fontWeight: FontWeight.w700, color: C.primary)),
            ]),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: _buildStep(),
        )),

        // Nav buttons
        Container(
          color: C.bgElevated,
          padding: EdgeInsets.fromLTRB(16, 12, 16,
              MediaQuery.of(context).padding.bottom + 12),
          child: Row(children: [
            Expanded(child: PBtn(
              label: _step == 0 ? '✕ Cancel' : '← Back',
              onTap: _step == 0 ? () => Navigator.of(context).pop() : () => setState(() => _step--),
              outline: true, color: C.textMuted, full: true,
            )),
            const SizedBox(width: 12),
            Expanded(child: _step < _steps.length - 1
                ? PBtn(
                    label: 'Next →',
                    onTap: _canAdvance() ? () => setState(() => _step++) : null,
                    full: true,
                    color: _canAdvance() ? C.primary : C.border,
                  )
                : PBtn(
                    label: _isSubmitting ? '⌛ Uploading...' : '🎉 Create Job',
                    onTap: _isSubmitting ? null : _submit,
                    color: _isSubmitting ? C.border : C.green,
                    full: true,
                  )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _step1Customer();
      case 1: return _step2Device();
      case 2: return _step3Problem();
      case 3: return _step4Schedule();
      case 4: return _step5Photos();
      case 5: return _step6Review();
      default: return const SizedBox.shrink();
    }
  }

  // ── Step 1: Customer Details ────────────────────────────────
  Widget _step1Customer() {
    final custs = ref.watch(customersProvider);
    return SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('👤 Customer', style: GoogleFonts.syne(
          fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
      const SizedBox(height: 4),
      Text('Select existing or enter a new customer',
          style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
      const SizedBox(height: 16),

      // Existing customer dropdown
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SELECT EXISTING CUSTOMER', style: GoogleFonts.syne(
            fontSize: 10, fontWeight: FontWeight.w700, color: C.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: _custId.isEmpty ? null : _custId,
          hint: Text('Walk-in / New customer', style: GoogleFonts.syne(fontSize: 13, color: C.textDim)),
          dropdownColor: C.bgElevated,
          style: GoogleFonts.syne(fontSize: 13, color: C.text),
          decoration: const InputDecoration(),
          isExpanded: true,
          onChanged: (v) {
            setState(() {
              _custId = v ?? '';
              if (v != null && v.isNotEmpty) {
                try {
                  final c = custs.firstWhere((c) => c.customerId == v);
                  _custName.text  = c.name;
                  _custPhone.text = c.phone;
                } catch (_) {}
              }
            });
          },
          items: custs.map((c) => DropdownMenuItem(
            value: c.customerId,
            child: Row(children: [
              CircleAvatar(radius: 12, backgroundColor: C.primary.withValues(alpha: 0.2),
                  child: Text(c.name[0], style: GoogleFonts.syne(
                      fontSize: 10, fontWeight: FontWeight.w800, color: C.primary))),
              const SizedBox(width: 8),
              Expanded(child: Text('${c.name} · ${c.phone}',
                  style: GoogleFonts.syne(fontSize: 12), overflow: TextOverflow.ellipsis)),
            ]),
          )).toList(),
        ),
      ]),
      const SizedBox(height: 16),
      Center(child: Text('— or enter manually —',
          style: GoogleFonts.syne(fontSize: 12, color: C.textMuted))),
      const SizedBox(height: 12),
      _textField('Full Name', _custName, hint: 'Walk-in customer name', required: true,
          onChanged: (_) => setState(() { _custId = ''; })),
      _textField('Phone Number', _custPhone, hint: '+91 XXXXX XXXXX',
          type: TextInputType.phone, required: true,
          onChanged: (_) => setState(() { _custId = ''; })),
    ]));
  }

  // ── Step 2: Device Details ──────────────────────────────────
  Widget _step2Device() => SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('📱 Device Details', style: GoogleFonts.syne(
        fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
    const SizedBox(height: 16),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('BRAND', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700,
          color: C.textMuted, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      DropdownButtonFormField<String>(
        initialValue: _brand.isEmpty ? null : _brand,
        hint: Text('Select brand...', style: GoogleFonts.syne(fontSize: 13, color: C.textDim)),
        dropdownColor: C.bgElevated,
        style: GoogleFonts.syne(fontSize: 13, color: C.text),
        decoration: const InputDecoration(),
        isExpanded: true,
        onChanged: (v) => setState(() => _brand = v ?? ''),
        items: ['Apple', 'Samsung', 'OnePlus', 'Xiaomi', 'Realme', 'Oppo', 'Vivo',
          'Google', 'Nokia', 'Motorola', 'Other']
            .map((b) => DropdownMenuItem(value: b, child: Text(b,
            style: GoogleFonts.syne(fontSize: 13)))).toList(),
      ),
      const SizedBox(height: 12),
    ]),
    _textField('Model', _model, hint: 'e.g. iPhone 15 Pro, Galaxy S24', required: true),
    Row(children: [
      Expanded(child: _textField('Color', _color, hint: 'Black')),
      const SizedBox(width: 10),
      Expanded(child: _textField('IMEI / Serial', _imei, hint: '*#06#')),
    ]),
    Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.primary.withValues(alpha: 0.2))),
      child: Text('💡 Dial *#06# to get the IMEI number',
          style: GoogleFonts.syne(fontSize: 12, color: C.primary))),
  ]));

  // ── Step 3: Problem Description ─────────────────────────────
  Widget _step3Problem() => Column(children: [
    SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('🔍 Problem & Estimate', style: GoogleFonts.syne(
          fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
      const SizedBox(height: 16),
      _textField('Problem Description', _problem, hint: 'Describe what customer reported...',
          maxLines: 3, required: true),
      _textField('Internal Notes', _notes, hint: 'Notes for technician (optional)', maxLines: 2),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PRIORITY', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700,
            color: C.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Row(children: ['Normal', 'Urgent', 'Express'].map((p) {
          final sel = _priority == p;
          final color = p == 'Normal' ? C.primary : p == 'Urgent' ? C.yellow : C.red;
          return Expanded(child: Padding(
            padding: EdgeInsets.only(right: p == 'Express' ? 0 : 8),
            child: GestureDetector(
              onTap: () => setState(() => _priority = p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? color.withValues(alpha: 0.15) : C.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? color : C.border, width: sel ? 2 : 1),
                ),
                child: Text(p, textAlign: TextAlign.center,
                    style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700,
                        color: sel ? color : C.textMuted)),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 12),
      ]),
    ])),
    const SizedBox(height: 12),
    SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('💰 Initial Cost Estimate', style: GoogleFonts.syne(
          fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _textField('Parts Cost', _parts,
            prefix: '₹', type: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: _textField('Labor Cost', _labor,
            prefix: '₹', type: TextInputType.number)),
      ]),
      Row(children: [
        Expanded(child: _textField('Discount', _discount,
            prefix: '₹', type: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: _textField('Tax %', _taxRate, type: TextInputType.number)),
      ]),
      StatefulBuilder(builder: (_, ss) => CostSummary(
        parts: double.tryParse(_parts.text) ?? 0,
        labor: double.tryParse(_labor.text) ?? 0,
        discount: double.tryParse(_discount.text) ?? 0,
        taxRate: double.tryParse(_taxRate.text) ?? 18,
      )),
    ])),
  ]);

  // ── Step 4: Schedule ───────────────────────────────────────
  Widget _step4Schedule() {
    final techs = ref.watch(techsProvider);
    final activeTechs = techs.where((t) => t.isActive).toList();
      return SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('📅 Schedule', style: GoogleFonts.syne(
          fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _textField('Start Date', _startDate, hint: 'YYYY-MM-DD')),
        const SizedBox(width: 10),
        Expanded(child: _textField('Expected End *', _endDate, hint: 'YYYY-MM-DD',
            required: true)),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ASSIGN TECHNICIAN', style: GoogleFonts.syne(fontSize: 10,
            fontWeight: FontWeight.w700, color: C.textMuted, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: _techId.isEmpty ? null : _techId,
          hint: Text('Unassigned', style: GoogleFonts.syne(fontSize: 13, color: C.textDim)),
          dropdownColor: C.bgElevated,
          style: GoogleFonts.syne(fontSize: 13, color: C.text),
          decoration: const InputDecoration(),
          isExpanded: true,
          onChanged: (v) => setState(() => _techId = v ?? ''),
        items: activeTechs.map((t) => DropdownMenuItem(
          value: t.techId,
          child: Text('${t.name} · ${t.totalJobs} jobs · ${t.specialization} · ⭐${t.rating}',
              style: GoogleFonts.syne(fontSize: 12), overflow: TextOverflow.ellipsis),
        )).toList(),
      ),
      const SizedBox(height: 12),
    ]),
    if (_techId.isNotEmpty) () {
      try {
        final t = ref.read(techsProvider).firstWhere((t) => t.techId == _techId);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.primary.withValues(alpha: 0.2))),
          child: Row(children: [
            CircleAvatar(backgroundColor: C.primary.withValues(alpha: 0.2), radius: 20,
                child: Text(t.name[0], style: GoogleFonts.syne(
                    fontWeight: FontWeight.w800, color: C.primary))),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: C.text)),
              Text('${t.totalJobs} jobs · ${t.specialization} · ⭐${t.rating}',
                  style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
            ]),
          ]),
        );
      } catch (_) { return const SizedBox.shrink(); }
    }(),
    ]));
  }

  // ── Step 5: Photos ─────────────────────────────────────────
  Widget _step5Photos() => SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('📷 Intake Photos', style: GoogleFonts.syne(
        fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
    Text('Document the device condition before repair starts',
        style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
    const SizedBox(height: 16),
    PhotoRow(
      photos: _intakePhotos,
      label: 'Device photos (front, back, damage areas)',
      onPhotoAdded: (path) => setState(() => _intakePhotos = [..._intakePhotos, path]),
      onPhotoRemoved: (idx) => setState(() {
        final list = [..._intakePhotos]..removeAt(idx);
        _intakePhotos = list;
      }),
    ),
    const SizedBox(height: 10),
    Container(
      padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.accent.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📋 Intake Checklist', style: GoogleFonts.syne(
            fontWeight: FontWeight.w700, color: C.accent, fontSize: 13)),
        const SizedBox(height: 8),
        ...['Screen condition documented', 'All buttons functioning noted',
          'Accessories listed (charger, case, earphones)', 'Battery % noted',
          'Existing damage/scratches noted', 'IMEI verified with customer']
          .map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: C.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(item, style: GoogleFonts.syne(fontSize: 12, color: C.text))),
            ]),
          )),
      ]),
    ),
  ]));

  // ── Step 6: Review ─────────────────────────────────────────
  Widget _step6Review() {
    final techs = ref.read(techsProvider);
    final techName = _techId.isEmpty ? 'Unassigned'
        : techs.firstWhere((t) => t.techId == _techId,
            orElse: () => Technician(techId: '', shopId: '', name: 'Unassigned')).name;

    return SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('✅ Review & Confirm', style: GoogleFonts.syne(
          fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
      const SizedBox(height: 16),
      ...[
        ['👤 Customer', _custName.text, ''],
        ['📱 Device', '${_brand.isEmpty ? "" : "$_brand "} ${_model.text.trim()}', _color.text],
        ['🔍 Problem', _problem.text, ''],
        ['📅 Schedule', '${_startDate.text} → ${_endDate.text}', '$_priority priority'],
        ['👨‍🔧 Technician', techName, ''],
        ['💰 Estimate', fmtMoney(_total), 'Parts: ${fmtMoney(double.tryParse(_parts.text) ?? 0)} · Labor: ${fmtMoney(double.tryParse(_labor.text) ?? 0)}'],
        ['📷 Photos', '${_intakePhotos.length} intake photo(s)', ''],
      ].map((row) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(row[0], style: GoogleFonts.syne(
              fontSize: 12, color: C.textMuted))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row[1].trim().isEmpty ? '⚠️ Not filled' : row[1],
                style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 13,
                    color: row[1].trim().isEmpty ? C.red : C.text)),
            if (row[2].isNotEmpty) Text(row[2], style: GoogleFonts.syne(
                fontSize: 11, color: C.textMuted)),
          ])),
        ]),
      )),
      if (_endDate.text.isEmpty)
        Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: C.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.red.withValues(alpha: 0.3))),
          child: Text('⚠️ Please go back and set an Expected End Date',
              style: GoogleFonts.syne(fontSize: 12, color: C.red))),
    ]));
  }

  Widget _textField(String label, TextEditingController ctrl, {
    String? hint, String? prefix, TextInputType? type,
    int maxLines = 1, bool required = false, ValueChanged<String>? onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(text: TextSpan(
          text: label.toUpperCase(),
          style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700,
              color: C.textMuted, letterSpacing: 0.5),
          children: required ? [TextSpan(text: ' *',
              style: GoogleFonts.syne(color: C.accent))] : [],
        )),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl, keyboardType: type, maxLines: maxLines,
          onChanged: (v) { onChanged?.call(v); setState(() {}); },
          style: GoogleFonts.syne(fontSize: 13, color: C.text),
          decoration: InputDecoration(hintText: hint, prefixText: prefix,
              prefixStyle: GoogleFonts.syne(color: C.textMuted, fontSize: 13)),
        ),
        const SizedBox(height: 12),
      ]);
}
