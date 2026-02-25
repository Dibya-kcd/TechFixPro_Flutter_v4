import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/m.dart';
import '../data/providers.dart';
import '../theme/t.dart';
import '../widgets/w.dart';

class POSScreen extends ConsumerStatefulWidget {
  const POSScreen({super.key});

  @override
  ConsumerState<POSScreen> createState() => _POSState();
}

class _POSState extends ConsumerState<POSScreen> {
  String _payment = 'Cash';
  double _discount = 0;
  bool _discPct = false;
  bool _done = false;
  final _discCtrl = TextEditingController(text: '0');
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _synced = false;
  bool _syncing = false;

  @override
  void dispose() {
    _discCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _syncProductsFromFirebase(String shopId) async {
    try {
      final db = FirebaseDatabase.instance;
      final snap = await db.ref('products')
          .orderByChild('shopId')
          .equalTo(shopId)
          .get();
      final list = <Product>[];
      if (snap.exists && snap.children.isNotEmpty) {
        for (final child in snap.children) {
          final key = child.key;
          final value = child.value;
          if (key == null || value is! Map) continue;
          final data = Map<String, dynamic>.from(value);
          list.add(Product(
            productId: key,
            shopId: (data['shopId'] as String?) ?? shopId,
            sku: (data['sku'] as String?) ?? '',
            productName: (data['productName'] as String?) ?? (data['name'] as String?) ?? '',
            category: (data['category'] as String?) ?? (data['cat'] as String?) ?? 'Spare Parts',
            brand: (data['brand'] as String?) ?? '',
            description: (data['description'] as String?) ?? '',
            supplierName: (data['supplierName'] as String?) ?? (data['supplier'] as String?) ?? '',
            costPrice: (data['costPrice'] as num?)?.toDouble() ?? (data['cost'] as num?)?.toDouble() ?? 0,
            sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? (data['price'] as num?)?.toDouble() ?? 0,
            stockQty: (data['stockQty'] as int?) ?? (data['qty'] as int?) ?? 0,
            reorderLevel: (data['reorderLevel'] as int?) ?? (data['reorder'] as int?) ?? 5,
            isActive: (data['isActive'] as bool?) ?? true,
            imageUrl: (data['imageUrl'] as String?) ?? '',
            createdAt: (data['createdAt'] as String?) ?? '',
            updatedAt: (data['updatedAt'] as String?) ?? '',
          ));
        }
      }
      ref.read(productsProvider.notifier).setAll(list);
    } catch (_) {}
  }

  Future<void> _processSale(List<CartItem> cart, String shopId) async {
    final db = FirebaseDatabase.instance;
    final batch = <String, dynamic>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toIso8601String();
    
    // Get latest products to ensure correct stock deduction
    final allProducts = ref.read(productsProvider);

    for (final item in cart) {
      // Find the latest product data
      final latestP = allProducts.firstWhere(
        (p) => p.productId == item.product.productId,
        orElse: () => item.product,
      );
      
      final newQty = (latestP.stockQty - item.qty).clamp(0, 99999);
      batch['products/${latestP.productId}/stockQty'] = newQty;
      batch['products/${latestP.productId}/updatedAt'] = nowIso;

      // Log transaction
      final txId = 'tx_${now}_${latestP.productId}';
      batch['transactions/$txId'] = {
        'shopId': shopId,
        'productId': latestP.productId,
        'productName': latestP.productName,
        'qty': item.qty,
        'price': latestP.sellingPrice,
        'cost': latestP.costPrice,
        'total': latestP.sellingPrice * item.qty,
        'type': 'sale',
        'payment': _payment,
        'time': now,
      };

      // Log stock history
      final histId = 'h_${now}_${latestP.productId}';
      batch['stock_history/$histId'] = {
        'shopId': shopId,
        'productId': latestP.productId,
        'productName': latestP.productName,
        'oldQty': latestP.stockQty,
        'newQty': newQty,
        'delta': -item.qty,
        'type': 'sale',
        'time': now,
        'by': 'POS',
      };
    }

    try {
      await db.ref().update(batch);
      // Update local state too
      for (final item in cart) {
        ref.read(productsProvider.notifier).adjustQty(item.product.productId, -item.qty);
      }
    } catch (e) {
      debugPrint('Error processing sale: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final sessionAsync = ref.watch(currentUserProvider);
    final session = sessionAsync.asData?.value;

    if (!_synced && !_syncing && session != null && session.shopId.isNotEmpty) {
      _syncing = true;
      _syncProductsFromFirebase(session.shopId).whenComplete(() {
        if (mounted) {
          setState(() {
            _synced = true;
            _syncing = false;
          });
        }
      });
    }

    if (_done) return _buildSuccess(cart);

    final available = products.where((p) =>
        p.stockQty > 0 && (_search.isEmpty ||
            p.productName.toLowerCase().contains(_search.toLowerCase()) ||
            p.sku.toLowerCase().contains(_search.toLowerCase()))).toList();

    final subtotal = cart.fold(0.0, (s, c) => s + c.product.sellingPrice * c.qty);
    final discAmt = _discPct ? subtotal * _discount / 100 : _discount;
    final taxAmt = (subtotal - discAmt) * 0.18;
    final total = subtotal - discAmt + taxAmt;

    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          // Search bar
          Container(
            color: C.bgElevated,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              style: GoogleFonts.syne(fontSize: 13, color: C.text),
              decoration: const InputDecoration(
                hintText: '🔍 Search or scan barcode...',
                prefixIcon: Icon(Icons.qr_code_scanner, color: C.textMuted, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          Expanded(
            child: CustomScrollView(
              slivers: [
                // Product grid
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final p = available[i];
                        final inCart = cart.any((c) => c.product.productId == p.productId);
                        final qty = inCart ? cart.firstWhere((c) => c.product.productId == p.productId).qty : 0;
                        final icon = p.category == 'Mobile Phones' ? '📱' : p.category == 'Spare Parts' ? '🔩' : '🔌';

                        return GestureDetector(
                          onTap: () => ref.read(cartProvider.notifier).add(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: inCart ? C.primary.withValues(alpha: 0.1) : C.bgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: inCart ? C.primary : C.border,
                                  width: inCart ? 2 : 1),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(icon, style: const TextStyle(fontSize: 22)),
                                    if (inCart) Container(
                                      width: 22, height: 22,
                                      decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                                      child: Center(child: Text('$qty', style: GoogleFonts.syne(fontSize: 11, fontWeight: FontWeight.w800, color: C.bg))),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(p.productName, style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12, color: C.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(fmtMoney(p.sellingPrice), style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14, color: C.primary)),
                                Text('${p.stockQty} in stock', style: GoogleFonts.syne(fontSize: 10, color: C.textMuted)),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: available.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                  ),
                ),

                // Cart section
                if (cart.isNotEmpty) SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  sliver: SliverToBoxAdapter(
                    child: SCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('🛒 Cart (${cart.length})', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 14, color: C.white)),
                          const SizedBox(height: 12),

                          // Cart items
                          ...cart.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.product.productName, style: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 13, color: C.text), overflow: TextOverflow.ellipsis),
                                      Text('${fmtMoney(item.product.sellingPrice)} each', style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    _qtyBtn(Icons.remove, () => ref.read(cartProvider.notifier).setQty(item.product.productId, item.qty - 1)),
                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('${item.qty}', style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: C.white))),
                                    _qtyBtn(Icons.add, () => ref.read(cartProvider.notifier).setQty(item.product.productId, item.qty + 1)),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 64,
                                  child: Text(fmtMoney(item.product.sellingPrice * item.qty),
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.syne(fontWeight: FontWeight.w700, color: C.primary, fontSize: 13)),
                                ),
                              ],
                            ),
                          )),

                          const Divider(color: C.border, height: 20),

                          // Discount
                          Text('DISCOUNT', style: GoogleFonts.syne(fontSize: 10, fontWeight: FontWeight.w700, color: C.textMuted, letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _toggleBtn('₹ Flat', !_discPct, () => setState(() => _discPct = false)),
                              const SizedBox(width: 8),
                              _toggleBtn('% Percent', _discPct, () => setState(() => _discPct = true)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _discCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setState(() => _discount = double.tryParse(v) ?? 0),
                                  style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700, color: C.text),
                                  decoration: InputDecoration(
                                    prefixText: _discPct ? '' : '₹',
                                    suffixText: _discPct ? '%' : null,
                                    prefixStyle: GoogleFonts.syne(color: C.textMuted),
                                    suffixStyle: GoogleFonts.syne(color: C.textMuted),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Totals
                          ...[ ['Subtotal', subtotal, null], ['Discount', -discAmt, C.red], ['GST 18%', taxAmt, null] ].map((row) {
                            final label = row[0] as String;
                            final val = row[1] as double;
                            final color = row[2] as Color?;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(label, style: GoogleFonts.syne(fontSize: 13, color: C.textMuted)),
                                  Text(val < 0 ? '-${fmtMoney(-val)}' : fmtMoney(val),
                                      style: GoogleFonts.syne(fontSize: 13, color: color ?? C.text)),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: C.border, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL', style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
                              Text(fmtMoney(total), style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 18, color: C.green)),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Payment methods
        Wrap(
          spacing: 6, runSpacing: 6,
          children: ['Cash', 'Card', 'UPI', 'Wallet', 'Bank Transfer'].map((m) {
            final sel = _payment == m;
            return GestureDetector(
              onTap: () => setState(() => _payment = m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? C.primary.withValues(alpha: 0.18) : C.bgElevated,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(color: sel ? C.primary : C.border),
                                  ),
                                  child: Text(m, style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? C.primary : C.textMuted)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Charge button
                          PBtn(
                            label: '💳 Charge ${fmtMoney(total)} · $_payment',
                            onTap: () async {
                              if (session != null) {
                                await _processSale(cart, session.shopId);
                                setState(() => _done = true);
                              }
                            },
                            color: C.green, full: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ) else const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(8), color: C.bgElevated),
      child: Icon(icon, size: 16, color: C.text),
    ),
  );

  Widget _toggleBtn(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? C.accent.withValues(alpha: 0.15) : C.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: sel ? C.accent : C.border),
      ),
      child: Text(label, style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? C.accent : C.textMuted)),
    ),
  );

  Widget _buildSuccess(cart) {
    return Scaffold(
      backgroundColor: C.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text('Payment Complete!', style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: C.green)),
            const SizedBox(height: 8),
            Text('Receipt sent to customer', style: GoogleFonts.syne(color: C.textMuted)),
            const SizedBox(height: 4),
            Text('via $_payment', style: GoogleFonts.syne(fontSize: 13, color: C.textMuted)),
            const SizedBox(height: 32),
            PBtn(
              label: 'New Sale',
              onTap: () {
                ref.read(cartProvider.notifier).clear();
                setState(() { _done = false; _discount = 0; _discCtrl.text = '0'; });
              },
              color: C.primary,
            ),
          ],
        ),
      ),
    );
  }
}
