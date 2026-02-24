import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'theme/t.dart';
import 'data/providers.dart';
import 'widgets/w.dart';
import 'models/m.dart';
import 'screens/dash.dart';
import 'screens/repairs.dart';
import 'screens/customers.dart';
import 'screens/inventory.dart';
import 'screens/pos.dart';
import 'screens/reports.dart';
import 'screens/settings.dart';
import 'screens/repair_detail.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDe-XjqOon900QGyA81CsgCgsz0_41i5pQ',
        authDomain: 'techfixv1.firebaseapp.com',
        databaseURL: 'https://techfixv1-default-rtdb.firebaseio.com',
        projectId: 'techfixv1',
        storageBucket: 'techfixv1.firebasestorage.app',
        messagingSenderId: '709235793243',
        appId: '1:709235793243:web:0d6ed7c436e01a2dec8e7e',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  }
  runApp(const ProviderScope(child: TechFixApp()));
}

class TechFixApp extends StatelessWidget {
  const TechFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechFix Pro',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: C.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TechFix Pro',
                    style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: C.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const _LoginScreen();
        }
        return const RootShell();
      },
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen();

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _email = TextEditingController(text: 'owner@techfix.com');
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Sign in failed';
      });
    } catch (_) {
      setState(() {
        _error = 'Sign in failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [C.primary, C.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'T',
                            style: GoogleFonts.syne(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: C.bg,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TechFix Pro',
                            style: GoogleFonts.syne(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: C.white,
                            ),
                          ),
                          Text(
                            'Secure login',
                            style: GoogleFonts.syne(
                              fontSize: 12,
                              color: C.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppField(
                    label: 'Email',
                    hint: 'owner@techfix.com',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    required: true,
                  ),
                  AppField(
                    label: 'Password',
                    hint: 'Enter password',
                    controller: _password,
                    keyboardType: TextInputType.visiblePassword,
                    required: true,
                    suffix: IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: C.textMuted),
                      onPressed: () => _password.clear(),
                    ),
                  ),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: GoogleFonts.syne(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  PBtn(
                    label: _loading ? 'Signing in...' : 'Sign In',
                    onTap: _loading ? null : _signIn,
                    full: true,
                    icon: Icons.lock_open_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use your TechFix owner or staff account to access all shops and data.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(
                      fontSize: 11,
                      color: C.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ROOT SHELL – bottom nav + indexed stack
// ═══════════════════════════════════════════════════════════════
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _idx = 0;
  bool _initialized = false;

  static const _navItems = [
    _NavItem(index: 0, icon: Icons.home_outlined,        activeIcon: Icons.home,            label: 'Home'),
    _NavItem(index: 1, icon: Icons.build_outlined,       activeIcon: Icons.build,           label: 'Repairs'),
    _NavItem(index: 2, icon: Icons.people_outline,       activeIcon: Icons.people,          label: 'Customers'),
    _NavItem(index: 4, icon: Icons.point_of_sale_outlined,activeIcon: Icons.point_of_sale, label: 'POS'),
    _NavItem(index: -1, icon: Icons.menu,                activeIcon: Icons.menu_open,       label: 'More'),
  ];

  Future<void> _initAppData(String shopId) async {
    if (_initialized) return;
    try {
      final db = FirebaseDatabase.instance;
      
      // Load settings
      await ref.read(settingsProvider.notifier).loadFromFirebase(shopId);
      
      // Load technicians
      final techSnap = await db.ref('users')
          .orderByChild('shopId')
          .equalTo(shopId)
          .get();
      final techs = <Technician>[];
      if (techSnap.exists && techSnap.children.isNotEmpty) {
        for (final child in techSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          final role = data['role'] as String? ?? 'technician';
          if (role == 'technician' || role == 'manager' || role == 'reception') {
            techs.add(Technician(
              techId: child.key!,
              shopId: shopId,
              name: data['name'] as String? ?? '',
              phone: data['phone'] as String? ?? '',
              specialization: data['specialization'] as String? ?? 'General',
              isActive: data['isActive'] as bool? ?? true,
              totalJobs: data['totalJobs'] as int? ?? (data['jobs'] as int? ?? 0),
              rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
              pin: data['pin'] as String? ?? '',
              joinedAt: data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            ));
          }
        }
      }
      ref.read(techsProvider.notifier).setAll(techs);

      // Load products
      final prodSnap = await db.ref('products')
          .orderByChild('shopId')
          .equalTo(shopId)
          .get();
      final products = <Product>[];
      if (prodSnap.exists && prodSnap.children.isNotEmpty) {
        for (final child in prodSnap.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          products.add(Product(
            productId: child.key!,
            shopId: shopId,
            sku: (data['sku'] as String?) ?? '',
            productName: (data['productName'] as String?) ?? (data['name'] as String?) ?? '',
            category: (data['category'] as String?) ?? (data['cat'] as String?) ?? 'Accessories',
            brand: (data['brand'] as String?) ?? '',
            description: (data['description'] as String?) ?? '',
            supplierName: (data['supplierName'] as String?) ?? (data['supplier'] as String?) ?? '',
            costPrice: (data['costPrice'] as num?)?.toDouble() ?? (data['cost'] as num?)?.toDouble() ?? 0,
            sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0,
            stockQty: (data['stockQty'] as int?) ?? (data['qty'] as int?) ?? 0,
            reorderLevel: (data['reorderLevel'] as int?) ?? (data['reorder'] as int?) ?? 5,
            isActive: (data['isActive'] as bool?) ?? true,
            imageUrl: (data['imageUrl'] as String?) ?? '',
            createdAt: (data['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
            updatedAt: (data['updatedAt'] as String?) ?? DateTime.now().toIso8601String(),
          ));
        }
      }
      ref.read(productsProvider.notifier).setAll(products);

      // Load transactions
      final txSnap = await db.ref('transactions')
          .orderByChild('shopId')
          .equalTo(shopId)
          .get();
      final txs = <Map<String, dynamic>>[];
      if (txSnap.exists && txSnap.children.isNotEmpty) {
        for (final child in txSnap.children) {
          txs.add(Map<String, dynamic>.from(child.value as Map));
        }
      }
      ref.read(transactionsProvider.notifier).state = txs;

      if (mounted) setState(() => _initialized = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final session = userAsync.asData?.value;
    
    if (session != null && session.shopId.isNotEmpty && !_initialized) {
      _initAppData(session.shopId);
    }

    final jobs = ref.watch(jobsProvider);
    final overdue = jobs.where((j) => j.isOverdue).length;
    final ready   = jobs.where((j) => j.status == 'Ready for Pickup').length;
    final onHold  = jobs.where((j) => j.isOnHold).length;
    final settings = ref.watch(settingsProvider);
     final cart = ref.watch(cartProvider);
    final cartCount = cart.fold<int>(0, (s, c) => s + c.qty);

    // Build screens – use callbacks so DashScreen can switch tabs
    final screens = <Widget>[
      DashScreen(
        onRepairs: () => setState(() => _idx = 1),
        onInventory: () => setState(() => _idx = 3),
        onOpenJob: (jobId) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RepairDetailScreen(jobId: jobId),
            ),
          );
        },
      ),
      const RepairsScreen(),
      const CustomersScreen(),
      const InventoryScreen(),
      const POSScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    final shopName = settings.shopName.isEmpty ? 'TechFix Pro' : settings.shopName;
    final appBarTitle = switch (_idx) {
      0 => 'Dashboard',
      1 => 'Repairs',
      2 => 'Customers',
      3 => 'Stock',
      4 => 'POS',
      5 => 'Reports',
      6 => 'Settings',
      _ => shopName,
    };

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bgElevated,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [C.primary, C.primaryDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('T', style: GoogleFonts.syne(
                  fontWeight: FontWeight.w900, fontSize: 18, color: C.bg)),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ]),
        actions: [
          // Overdue badge
          if (overdue > 0)
            _AppBarBadge(icon: '⏰', count: overdue, color: C.red,
                onTap: () {
                  setState(() => _idx = 1);
                  ref.read(jobTabProvider.notifier).state = 'Active';
                }),
          // On Hold badge
          if (onHold > 0)
            _AppBarBadge(icon: '⏸️', count: onHold, color: C.yellow,
                onTap: () {
                  setState(() => _idx = 1);
                  ref.read(jobTabProvider.notifier).state = 'On Hold';
                }),
          // Ready for pickup badge
          if (ready > 0)
            _AppBarBadge(icon: '✅', count: ready, color: C.green,
                onTap: () {
                  setState(() => _idx = 1);
                  ref.read(jobTabProvider.notifier).state = 'Ready';
                }),
          if (_idx == 4)
            _CartAction(
              count: cartCount,
              onTap: () => _openCart(cart),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _idx, children: screens),
      bottomNavigationBar: _buildBottomNav(),
      endDrawer: _CartDrawer(onGoToPos: _goToPosFromCart),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: C.bgElevated,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.map((item) {
              final sel = item.index >= 0
                  ? _idx == item.index
                  : _idx == 3 || _idx == 5 || _idx == 6;
              return GestureDetector(
                onTap: () {
                  if (item.index >= 0) {
                    setState(() => _idx = item.index);
                  } else {
                    _openMoreSheet();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? C.primary.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(sel ? item.activeIcon : item.icon,
                        color: sel ? C.primary : C.textDim,
                        size: 22),
                    const SizedBox(height: 3),
                    Text(item.label, style: GoogleFonts.syne(
                        fontSize: 9,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel ? C.primary : C.textDim,
                        letterSpacing: 0.2)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
  
  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bgElevated,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: C.text),
              title: const Text('Stock'),
              onTap: () {
                setState(() => _idx = 3);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: C.text),
              title: const Text('Reports'),
              onTap: () {
                setState(() => _idx = 5);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: C.text),
              title: const Text('Settings'),
              onTap: () {
                setState(() => _idx = 6);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _goToPosFromCart() {
    Navigator.of(context).maybePop();
    setState(() => _idx = 4);
  }

  void _openCart(List<CartItem> cart) {
    final width = MediaQuery.of(context).size.width;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cart is empty', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
          backgroundColor: C.bgElevated,
        ),
      );
      return;
    }
    if (width < 700) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CartSheet(onGoToPos: _goToPosFromCart),
      );
    } else {
      Scaffold.of(context).openEndDrawer();
    }
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.index, required this.icon, required this.activeIcon, required this.label});
}

// ── App bar badge widget ───────────────────────────────────────
class _AppBarBadge extends StatelessWidget {
  final String icon;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _AppBarBadge({required this.icon, required this.count,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text('$count', style: GoogleFonts.syne(
            fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );
}

class _CartAction extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartAction({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;
    return Semantics(
      label: hasItems ? 'Cart, $count item(s)' : 'Cart, empty',
      button: true,
      child: IconButton(
        onPressed: onTap,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_cart_outlined, color: C.textDim),
            if (hasItems)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: C.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: GoogleFonts.syne(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: C.bg,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CartDrawer extends ConsumerWidget {
  final VoidCallback onGoToPos;
  const _CartDrawer({required this.onGoToPos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold<double>(0, (s, c) => s + c.product.sellingPrice * c.qty);
    return Drawer(
      backgroundColor: C.bgElevated,
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cart', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: C.white)),
                      IconButton(
                        icon: const Icon(Icons.close, color: C.textDim),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (cart.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Your cart is empty',
                          style: GoogleFonts.syne(fontSize: 13, color: C.textMuted),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: cart.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = cart[i];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: C.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: C.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.productName,
                                        style: GoogleFonts.syne(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: C.text,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${fmtMoney(item.product.sellingPrice)} each',
                                        style: GoogleFonts.syne(fontSize: 11, color: C.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        ref.read(cartProvider.notifier).setQty(
                                          item.product.productId,
                                          item.qty - 1,
                                        );
                                      },
                                      icon: const Icon(Icons.remove, size: 18, color: C.textDim),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(
                                        '${item.qty}',
                                        style: GoogleFonts.syne(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: C.white,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => ref.read(cartProvider.notifier).updateQty(item.product.productId, item.qty + 1),
                                      icon: const Icon(Icons.add, size: 18, color: C.textDim),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  fmtMoney(item.product.sellingPrice * item.qty),
                                  style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: C.primary),
                                ),
                                IconButton(
                                  onPressed: () {
                                    ref.read(cartProvider.notifier).setQty(item.product.productId, 0);
                                  },
                                  icon: const Icon(Icons.close, size: 18, color: C.textDim),
                                  padding: const EdgeInsets.only(left: 4),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (cart.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
                        Text(fmtMoney(total), style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: C.green)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PBtn(
                      label: 'Go to POS',
                      onTap: onGoToPos,
                      full: true,
                      color: C.primary,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: C.bgElevated,
                            title: Text(
                              'Clear cart?',
                              style: GoogleFonts.syne(
                                fontWeight: FontWeight.w800,
                                color: C.white,
                              ),
                            ),
                            content: Text(
                              'This will remove all items from the cart.',
                              style: GoogleFonts.syne(color: C.textMuted, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.syne(color: C.textMuted),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text(
                                  'Clear',
                                  style: GoogleFonts.syne(color: C.red, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          ref.read(cartProvider.notifier).clear();
                        }
                      },
                      child: Text(
                        'Clear cart',
                        style: GoogleFonts.syne(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: C.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartSheet extends ConsumerWidget {
  final VoidCallback onGoToPos;
  const _CartSheet({required this.onGoToPos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold<double>(0, (s, c) => s + c.product.sellingPrice * c.qty);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: C.bgElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cart', style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: C.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: C.textDim),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (cart.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Your cart is empty',
                    style: GoogleFonts.syne(fontSize: 13, color: C.textMuted),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = cart[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.productName,
                                  style: GoogleFonts.syne(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: C.text,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${fmtMoney(item.product.sellingPrice)} each',
                                  style: GoogleFonts.syne(fontSize: 11, color: C.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  ref.read(cartProvider.notifier).setQty(
                                    item.product.productId,
                                    item.qty - 1,
                                  );
                                },
                                icon: const Icon(Icons.remove, size: 18, color: C.textDim),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${item.qty}',
                                  style: GoogleFonts.syne(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: C.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ref.read(cartProvider.notifier).setQty(
                                    item.product.productId,
                                    item.qty + 1,
                                  );
                                },
                                icon: const Icon(Icons.add, size: 18, color: C.textDim),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            fmtMoney(item.product.sellingPrice * item.qty),
                            style: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: C.primary),
                          ),
                          IconButton(
                            onPressed: () {
                              ref.read(cartProvider.notifier).setQty(item.product.productId, 0);
                            },
                            icon: const Icon(Icons.close, size: 18, color: C.textDim),
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              if (cart.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: C.text)),
                    Text(fmtMoney(total), style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w800, color: C.green)),
                  ],
                ),
                const SizedBox(height: 12),
                PBtn(
                  label: 'Go to POS',
                  onTap: onGoToPos,
                  full: true,
                  color: C.primary,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: C.bgElevated,
                        title: Text(
                          'Clear cart?',
                          style: GoogleFonts.syne(
                            fontWeight: FontWeight.w800,
                            color: C.white,
                          ),
                        ),
                        content: Text(
                          'This will remove all items from the cart.',
                          style: GoogleFonts.syne(color: C.textMuted, fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.syne(color: C.textMuted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Clear',
                              style: GoogleFonts.syne(color: C.red, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(cartProvider.notifier).clear();
                    }
                  },
                  child: Text(
                    'Clear cart',
                    style: GoogleFonts.syne(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: C.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
