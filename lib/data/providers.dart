import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/m.dart';

// ── Time helper ───────────────────────────────────────────────
String _ts() {
  final n = DateTime.now();
  String p(int v) => v.toString().padLeft(2,'0');
  return '${n.year}-${p(n.month)}-${p(n.day)} ${p(n.hour)}:${p(n.minute)}';
}

// ── Jobs ──────────────────────────────────────────────────────
class JobsNotifier extends StateNotifier<List<Job>> {
  JobsNotifier() : super([]);

  void setAll(List<Job> list) => state = list;

  void addJob(Job job) => state = [job, ...state];

  void updateJob(Job updated) =>
      state = state.map((j) => j.jobId == updated.jobId ? updated : j).toList();

  void updateStatus(String id, String status, String by, {String note = '', String type = 'flow'}) {
    state = state.map((j) {
      if (j.jobId != id) return j;
      return j.copyWith(
        status: status,
        timeline: [...j.timeline, TimelineEntry(status: status, time: _ts(), by: by, note: note, type: type)],
        updatedAt: _ts(),
      );
    }).toList();
  }

  void putOnHold(String id, String reason, String by) {
    state = state.map((j) {
      if (j.jobId != id) return j;
      return j.copyWith(
        previousStatus: j.status,
        status: 'On Hold',
        holdReason: reason,
        timeline: [...j.timeline, TimelineEntry(
          status: 'On Hold', time: _ts(), by: by,
          note: 'HOLD: $reason', type: 'hold',
        )],
        updatedAt: _ts(),
      );
    }).toList();
  }

  void cancel(String id, String reason, String by) {
    state = state.map((j) {
      if (j.jobId != id) return j;
      return j.copyWith(
        previousStatus: j.status,
        status: 'Cancelled',
        holdReason: reason,
        timeline: [...j.timeline, TimelineEntry(
          status: 'Cancelled', time: _ts(), by: by,
          note: 'CANCELLED: $reason', type: 'cancel',
        )],
        updatedAt: _ts(),
      );
    }).toList();
  }

  void resumeFromHold(String id, String by) {
    state = state.map((j) {
      if (j.jobId != id) return j;
      final resumeTo = j.previousStatus ?? 'Checked In';
      return j.copyWith(
        status: resumeTo,
        previousStatus: null,
        holdReason: null,
        timeline: [...j.timeline, TimelineEntry(
          status: resumeTo, time: _ts(), by: by,
          note: 'Resumed from hold → $resumeTo', type: 'flow',
        )],
        updatedAt: _ts(),
      );
    }).toList();
  }

  void reopen(String id, String reason, String by) {
    state = state.map((j) {
      if (j.jobId != id) return j;
      return j.copyWith(
        status: 'In Repair',
        previousStatus: j.status,
        holdReason: null,
        notificationSent: false,
        reopenCount: j.reopenCount + 1,
        timeline: [...j.timeline, TimelineEntry(
          status: 'In Repair', time: _ts(), by: by,
          note: 'REOPENED (×${j.reopenCount + 1}): $reason', type: 'reopen',
        )],
        updatedAt: _ts(),
      );
    }).toList();
  }

  void addTimelineNote(String id, String note, String by) {
    final job = state.firstWhere((j) => j.jobId == id);
    updateJob(job.copyWith(
      timeline: [...job.timeline, TimelineEntry(status: job.status, time: _ts(), by: by, note: note, type: 'note')],
      updatedAt: _ts(),
    ));
  }

  void markNotified(String id, String via) {
    final job = state.firstWhere((j) => j.jobId == id);
    updateJob(job.copyWith(
      notificationSent: true,
      notificationChannel: via,
      timeline: [...job.timeline, TimelineEntry(
        status: job.status, time: _ts(), by: 'System',
        note: 'Pickup notification sent via $via', type: 'note',
      )],
      updatedAt: _ts(),
    ));
  }
}

final jobsProvider = StateNotifierProvider<JobsNotifier, List<Job>>((_) => JobsNotifier());

// ── Customers ─────────────────────────────────────────────────
class CustomersNotifier extends StateNotifier<List<Customer>> {
  CustomersNotifier() : super([]);

  void setAll(List<Customer> list) => state = list;

  void add(Customer c) => state = [c, ...state];

  void update(Customer updated) =>
      state = state.map((c) => c.customerId == updated.customerId ? updated : c).toList();

  void delete(String id) => state = state.where((c) => c.customerId != id).toList();
}

final customersProvider = StateNotifierProvider<CustomersNotifier, List<Customer>>(
  (_) => CustomersNotifier(),
);

// ── Products ──────────────────────────────────────────────────
class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier() : super([]);

  void setAll(List<Product> list) => state = list;

  void add(Product p) => state = [p, ...state];

  void update(Product updated) =>
      state = state.map((p) => p.productId == updated.productId ? updated : p).toList();

  void delete(String id) => state = state.where((p) => p.productId != id).toList();

  void adjustQty(String id, int delta) {
    state = state.map((p) {
      if (p.productId != id) return p;
      final newQty = (p.stockQty + delta).clamp(0, 99999);
      return p.copyWith(stockQty: newQty);
    }).toList();
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
  (_) => ProductsNotifier(),
);

// ── Technicians ───────────────────────────────────────────────
class TechsNotifier extends StateNotifier<List<Technician>> {
  TechsNotifier() : super([]);
  void setAll(List<Technician> list) => state = list;
  void add(Technician t) => state = [...state, t];
  void update(Technician updated) =>
      state = state.map((t) => t.techId == updated.techId ? updated : t).toList();
  void delete(String id) => state = state.where((t) => t.techId != id).toList();
}

final techsProvider = StateNotifierProvider<TechsNotifier, List<Technician>>(
  (_) => TechsNotifier(),
);

// ── Cart ──────────────────────────────────────────────────────
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void add(Product p) {
    final i = state.indexWhere((c) => c.product.productId == p.productId);
    if (i >= 0) {
      final updated = [...state];
      updated[i] = CartItem(product: updated[i].product, qty: updated[i].qty + 1);
      state = updated;
    } else {
      state = [...state, CartItem(product: p)];
    }
  }

  void setQty(String id, int qty) {
    if (qty <= 0) {
      state = state.where((c) => c.product.productId != id).toList();
    } else {
      final updated = state.map((c) {
        if (c.product.productId != id) return c;
        return CartItem(product: c.product, qty: qty);
      }).toList();
      state = updated;
    }
  }

  void removeItem(String id) => setQty(id, 0);

  void updateQty(String id, int qty) => setQty(id, qty);

  void clear() => state = [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);

// ── Shop Settings ─────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<ShopSettings> {
  SettingsNotifier() : super(ShopSettings());
  void update(ShopSettings s) => state = s;
  Future<void> loadFromFirebase(String shopId) async {
    try {
      final db = FirebaseDatabase.instance;
      final snap = await db.ref('shops/$shopId').get();
      if (!snap.exists || snap.value is! Map) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      state = state.copyWith(
        shopId: shopId,
        shopName: data['shopName'] as String? ?? (data['name'] as String? ?? state.shopName),
        ownerName: data['ownerName'] as String? ?? state.ownerName,
        phone: data['phone'] as String? ?? state.phone,
        email: data['email'] as String? ?? state.email,
        address: data['address'] as String? ?? state.address,
        gstNumber: data['gstNumber'] as String? ?? state.gstNumber,
        logoUrl: data['logoUrl'] as String? ?? state.logoUrl,
        invoicePrefix: data['invoicePrefix'] as String? ?? state.invoicePrefix,
        defaultTaxRate: (data['defaultTaxRate'] as num?)?.toDouble() ?? state.defaultTaxRate,
        defaultWarrantyDays: data['defaultWarrantyDays'] as int? ?? (data['warrantyDays'] as int? ?? state.defaultWarrantyDays),
        requireIntakePhoto: data['requireIntakePhoto'] as bool? ?? state.requireIntakePhoto,
        requireCompletionPhoto: data['requireCompletionPhoto'] as bool? ?? state.requireCompletionPhoto,
        settings: data['settings'] != null ? Map<String, dynamic>.from(data['settings'] as Map) : state.settings,
        createdAt: data['createdAt'] as String? ?? state.createdAt,
        plan: data['plan'] as String? ?? state.plan,
        darkMode: data['darkMode'] as bool? ?? state.darkMode,
        enabledPayments: data['enabledPayments'] != null ? List<String>.from(data['enabledPayments'] as List) : state.enabledPayments,
        workflowStages: data['workflowStages'] != null 
            ? (data['workflowStages'] as List).map((e) => Map<String, String>.from(e as Map)).toList() 
            : state.workflowStages,
      );
    } catch (_) {}
  }

  Future<void> saveToFirebase(String shopId) async {
    try {
      final db = FirebaseDatabase.instance;
      final s = state;
      await db.ref('shops/$shopId').set({
        'shopId': shopId,
        'shopName': s.shopName,
        'ownerName': s.ownerName,
        'phone': s.phone,
        'email': s.email,
        'address': s.address,
        'gstNumber': s.gstNumber,
        'logoUrl': s.logoUrl,
        'invoicePrefix': s.invoicePrefix,
        'defaultTaxRate': s.defaultTaxRate,
        'defaultWarrantyDays': s.defaultWarrantyDays,
        'requireIntakePhoto': s.requireIntakePhoto,
        'requireCompletionPhoto': s.requireCompletionPhoto,
        'settings': s.settings,
        'createdAt': s.createdAt,
        'plan': s.plan,
        'darkMode': s.darkMode,
        'enabledPayments': s.enabledPayments,
        'workflowStages': s.workflowStages,
      });
    } catch (_) {}
  }
  void toggle(String field) {
    switch (field) {
      case 'requireIntakePhoto':
        state = state.copyWith(requireIntakePhoto: !state.requireIntakePhoto); break;
      case 'requireCompletionPhoto':
        state = state.copyWith(requireCompletionPhoto: !state.requireCompletionPhoto); break;
      case 'darkMode':
        state = state.copyWith(darkMode: !state.darkMode); break;
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, ShopSettings>(
  (_) => SettingsNotifier(),
);

// ── UI state ──────────────────────────────────────────────────
final searchJobProvider = StateProvider<String>((_) => '');
final searchCustProvider = StateProvider<String>((_) => '');
final searchInvProvider = StateProvider<String>((_) => '');
final jobTabProvider = StateProvider<String>((_) => 'All');
final repairTabIndexProvider = StateProvider.family<int, String>((_, __) => 0);

final transactionsProvider = StateProvider<List<Map<String, dynamic>>>((_) => []);

final currentUserProvider = StreamProvider<SessionUser?>((ref) {
  final auth = FirebaseAuth.instance;
  final db = FirebaseDatabase.instance;
  return auth.authStateChanges().asyncMap((user) async {
    if (user == null) return null;
    try {
      final snap = await db.ref('users/${user.uid}').get();
      if (snap.exists && snap.value is Map) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        return SessionUser(
          uid: user.uid,
          email: (data['email'] as String?) ?? (user.email ?? ''),
          displayName: (data['displayName'] as String?) ?? (data['name'] as String?) ?? (user.displayName ?? 'User'),
          role: (data['role'] as String?) ?? 'technician',
          shopId: (data['shopId'] as String?) ?? '',
          phone: (data['phone'] as String?) ?? '',
          pin_hash: (data['pin_hash'] as String?) ?? '',
          biometricEnabled: (data['biometricEnabled'] as bool?) ?? false,
          isActive: (data['isActive'] as bool?) ?? true,
          lastLoginAt: (data['lastLoginAt'] as String?) ?? '',
          createdAt: (data['createdAt'] as String?) ?? '',
        );
      }
    } catch (_) {}
    return SessionUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? 'User',
      role: 'technician',
      shopId: '',
      phone: '',
      pin_hash: '',
      biometricEnabled: false,
      isActive: true,
      lastLoginAt: '',
      createdAt: '',
    );
  });
});
