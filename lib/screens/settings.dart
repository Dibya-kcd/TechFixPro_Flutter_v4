import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/providers.dart';
import '../models/m.dart';
import '../theme/t.dart';
import '../widgets/w.dart';
import 'demo_data.dart';

// ─────────────────────────────────────────────────────────────
// CONSISTENT PAGE SCAFFOLD
// ─────────────────────────────────────────────────────────────
class _Page extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? fab;
  final List<Widget>? actions;

  const _Page({
    required this.title,
    this.subtitle,
    required this.children,
    this.fab,
    this.actions,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: AppBar(
      backgroundColor: C.bgElevated,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: C.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.syne(
              fontWeight: FontWeight.w800, fontSize: 16, color: C.white)),
          if (subtitle != null)
            Text(subtitle!, style: GoogleFonts.syne(
                fontSize: 11, color: C.textMuted)),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: C.border),
      ),
    ),
    floatingActionButton: fab,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: children,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Consistent Save Button with loading state
// ─────────────────────────────────────────────────────────────
class _SaveBtn extends StatefulWidget {
  final VoidCallback onSave;
  final String label;
  const _SaveBtn({required this.onSave, this.label = '💾  Save Changes'});

  @override
  State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn> {
  bool _loading = false;
  bool _done = false;

  Future<void> _handle() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onSave();
    setState(() { _loading = false; _done = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: _loading ? null : _handle,
      style: ElevatedButton.styleFrom(
        backgroundColor: _done ? C.green : C.primary,
        foregroundColor: C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: C.bg))
          : Text(_done ? '✅  Saved!' : widget.label,
              style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Consistent info banner
// ─────────────────────────────────────────────────────────────
Widget _infoBanner(String text, {Color color = C.primary}) => Container(
  padding: const EdgeInsets.all(12),
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: color.withValues(alpha: 0.3)),
  ),
  child: Text(text, style: GoogleFonts.syne(fontSize: 12, color: color, height: 1.5)),
);

// ─────────────────────────────────────────────────────────────
// MAIN SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final session = userAsync.asData?.value;
    final role = session?.role ?? 'technician';
    final isSuperAdmin = role == 'super_admin';
    final isManager = role == 'manager';
    final isReception = role == 'reception';
    final isTechnician = role == 'technician';
    final canManageShopSettings = isSuperAdmin || isManager;
    final canSeeUserRoles = isSuperAdmin || isManager;
    final roleLabel = isSuperAdmin
        ? 'Super Admin'
        : isManager
            ? 'Manager'
            : isReception
                ? 'Reception'
                : isTechnician
                    ? 'Technician'
                    : 'Staff';

    if (session != null && session.shopId.isNotEmpty && s.shopName == 'TechFix Pro' && s.ownerName == 'Admin') {
      ref.read(settingsProvider.notifier).loadFromFirebase(session.shopId);
    }

    void go(Widget page) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [

          // ── Profile card ─────────────────────────────────────
          GestureDetector(
            onTap: () => go(const ShopProfilePage()),
            child: SCard(
              glowColor: C.primary,
              child: Row(children: [
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [C.primary, C.primaryDark],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(
                        color: C.primary.withValues(alpha: 0.3), blurRadius: 12)],
                  ),
                  child: Center(child: Text(
                    (s.ownerName.isEmpty ? 'A' : s.ownerName[0]).toUpperCase(),
                    style: GoogleFonts.syne(fontWeight: FontWeight.w900,
                        fontSize: 24, color: C.bg),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(s.ownerName.isEmpty ? 'Admin User' : s.ownerName,
                      style: GoogleFonts.syne(fontWeight: FontWeight.w800,
                          fontSize: 17, color: C.white)),
                  Text(s.shopName.isEmpty ? 'TechFix Pro' : s.shopName,
                      style: GoogleFonts.syne(fontSize: 13, color: C.primary)),
                  Text(s.email.isEmpty ? 'Tap to set up profile →' : s.email,
                      style: GoogleFonts.syne(fontSize: 12, color: C.textMuted)),
                  const SizedBox(height: 6),
                  Pill(roleLabel, small: true),
                ])),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: C.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_outlined, color: C.primary, size: 18),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick toggles ────────────────────────────────────
          SettingsGroup(title: 'QUICK CONTROLS', tiles: [
            SettingsTile(
              icon: '🌙', title: 'Dark Mode',
              subtitle: s.darkMode ? 'Currently using dark theme' : 'Currently using light theme',
              trailing: Switch(value: s.darkMode,
                  onChanged: (_) => ref.read(settingsProvider.notifier).toggle('darkMode')),
            ),
            SettingsTile(
              icon: '📸', title: 'Require Intake Photos',
              subtitle: s.requireIntakePhoto ? 'Mandatory at job check-in' : 'Optional at check-in',
              trailing: Switch(value: s.requireIntakePhoto,
                  onChanged: (_) => ref.read(settingsProvider.notifier).toggle('requireIntakePhoto')),
            ),
            SettingsTile(
              icon: '🏁', title: 'Require Completion Photos',
              subtitle: s.requireCompletionPhoto ? 'Mandatory before pickup' : 'Optional before pickup',
              trailing: Switch(value: s.requireCompletionPhoto,
                  onChanged: (_) => ref.read(settingsProvider.notifier).toggle('requireCompletionPhoto')),
            ),
          ]),

          if (canManageShopSettings)
            SettingsGroup(title: 'SHOP', tiles: [
              SettingsTile(icon: '🏪', title: 'Shop Profile',
                  subtitle: s.shopName.isEmpty ? 'Not configured' : s.shopName,
                  onTap: () => go(const ShopProfilePage())),
              SettingsTile(icon: '🧾', title: 'Invoice & Receipts',
                  subtitle: 'Prefix: ${s.invoicePrefix}  ·  Format & logo',
                  onTap: () => go(const InvoicePage())),
              SettingsTile(icon: '📊', title: 'Tax & GST',
                  subtitle: 'Default rate: ${s.defaultTaxRate.toStringAsFixed(0)}%',
                  onTap: () => go(const TaxPage())),
              SettingsTile(icon: '💳', title: 'Payment Methods',
                  subtitle: 'Cash, Card, UPI, Wallet',
                  onTap: () => go(const PaymentMethodsPage())),
            ]),

          SettingsGroup(title: 'TEAM & WORKFLOW', tiles: [
            SettingsTile(icon: '👨‍🔧', title: 'Technicians',
                subtitle: '${ref.watch(techsProvider).where((t) => t.isActive).length} active team members',
                onTap: () => go(const TechniciansPage())),
            if (!isTechnician)
              SettingsTile(icon: '🔄', title: 'Repair Workflow',
                  subtitle: '9 stages from check-in to completion',
                  onTap: () => go(const WorkflowPage())),
            if (!isTechnician)
              SettingsTile(icon: '🛡️', title: 'Warranty Rules',
                  subtitle: 'Default: ${s.defaultWarrantyDays} days post-repair',
                  onTap: () => go(const WarrantyPage())),
            if (canSeeUserRoles)
              SettingsTile(icon: '👥', title: 'User Roles & Access',
                  subtitle: 'Staff permissions and PIN access',
                  onTap: () => go(const UserRolesPage())),
          ]),

          // ── Notifications ────────────────────────────────────
          SettingsGroup(title: 'NOTIFICATIONS', tiles: [
            SettingsTile(icon: '💬', title: 'WhatsApp Business',
                subtitle: 'API key & message templates',
                onTap: () => go(const WhatsappPage())),
            SettingsTile(icon: '📱', title: 'SMS Gateway',
                subtitle: 'Twilio / MSG91 configuration',
                onTap: () => go(const SmsPage())),
            SettingsTile(icon: '🔔', title: 'Push Notifications',
                subtitle: 'Overdue alerts, low stock warnings',
                onTap: () => go(const PushNotifPage())),
            SettingsTile(icon: '📧', title: 'Email Settings',
                subtitle: 'SMTP configuration & templates',
                onTap: () => go(const EmailPage())),
          ]),

          // ── Integrations ─────────────────────────────────────
          SettingsGroup(title: 'INTEGRATIONS', tiles: [
            SettingsTile(icon: '💳', title: 'Payment Gateway',
                subtitle: 'Razorpay / Stripe / PayTM',
                onTap: () => go(const PaymentGatewayPage())),
            SettingsTile(icon: '📚', title: 'Accounting Export',
                subtitle: 'Tally, Zoho Books, QuickBooks',
                onTap: () => go(const AccountingPage())),
            SettingsTile(icon: '📦', title: 'Supplier Integration',
                subtitle: 'Auto-reorder on low stock',
                onTap: () => go(const SupplierPage())),
            SettingsTile(icon: '🤖', title: 'AI Diagnostics',
                subtitle: 'Claude AI for repair suggestions',
                onTap: () => go(const AiPage())),
          ]),

          // ── Data & Security ──────────────────────────────────
          SettingsGroup(title: 'DATA & SECURITY', tiles: [
            SettingsTile(icon: '🔒', title: 'App Lock & Biometrics',
                subtitle: 'PIN, fingerprint, Face ID',
                onTap: () => go(const AppLockPage())),
            SettingsTile(icon: '📋', title: 'Audit Logs',
                subtitle: 'Full activity & change history',
                onTap: () => go(const AuditLogsPage())),
            SettingsTile(icon: '☁️', title: 'Cloud Backup',
                subtitle: 'Auto-backup & restore',
                onTap: () => go(const BackupPage())),
            SettingsTile(icon: '📤', title: 'Export Data',
                subtitle: 'CSV / Excel / PDF reports',
                onTap: () => go(const ExportPage())),
            if (isSuperAdmin)
              SettingsTile(icon: '🧪', title: 'Demo Data Tools',
                  subtitle: 'Seed or clear demo data for this shop',
                  onTap: () => go(const DemoDataPage())),
            SettingsTile(icon: '🧪', title: 'Firebase Diagnostics',
                subtitle: 'Test connection and permissions',
                onTap: () => go(const FirebaseDiagnosticsPage())),
          ]),

          // ── About ────────────────────────────────────────────
          SettingsGroup(title: 'ABOUT', tiles: [
            SettingsTile(icon: '📄', title: 'Terms & Privacy Policy',
                subtitle: 'Legal information', onTap: () => _showInfoDialog(context,
                    'Terms & Privacy Policy',
                    'TechFix Pro stores all data locally on your device. '
                    'No data is sent to third parties without your explicit consent. '
                    'By using this app you agree to these terms.')),
            SettingsTile(icon: '💡', title: 'Send Feedback',
                subtitle: 'Help us improve the app',
                onTap: () => _showInfoDialog(context, 'Send Feedback',
                    'Email your feedback to: feedback@techfixpro.app\n'
                    'We read every message and aim to respond within 48 hours.')),
            SettingsTile(icon: '📱', title: 'App Version',
                subtitle: 'v3.0.0  ·  Build 2025.02'),
          ]),

          // ── Sign out ─────────────────────────────────────────
          GestureDetector(
            onTap: () => _confirmSignOut(context),
            child: SCard(
              borderColor: C.red.withValues(alpha: 0.3),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: C.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11)),
                  child: const Center(child: Text('🚪', style: TextStyle(fontSize: 20)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Sign Out', style: GoogleFonts.syne(
                      fontWeight: FontWeight.w700, fontSize: 15, color: C.red)),
                  Text('Log out of this account', style: GoogleFonts.syne(
                      fontSize: 12, color: C.textMuted)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Center(child: Text('TechFix Pro v3.0  ·  Made with ❤️ in India',
              style: GoogleFonts.syne(fontSize: 11, color: C.textDim))),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String body) =>
      showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.syne(
            fontWeight: FontWeight.w800, color: C.white)),
        content: Text(body, style: GoogleFonts.syne(
            fontSize: 13, color: C.textMuted, height: 1.6)),
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.syne(
                color: C.primary, fontWeight: FontWeight.w700)))],
      ));

  void _confirmSignOut(BuildContext context) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: C.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Sign Out?', style: GoogleFonts.syne(
          fontWeight: FontWeight.w800, color: C.white)),
      content: Text('You will need to log in again to access TechFix Pro.',
          style: GoogleFonts.syne(fontSize: 13, color: C.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.syne(color: C.textMuted))),
        ElevatedButton(onPressed: () async {
          Navigator.of(context).pop();
          await FirebaseAuth.instance.signOut();
        },
          style: ElevatedButton.styleFrom(backgroundColor: C.red,
              foregroundColor: C.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: Text('Sign Out', style: GoogleFonts.syne(fontWeight: FontWeight.w800))),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// 1. SHOP PROFILE
// ═════════════════════════════════════════════════════════════
class ShopProfilePage extends ConsumerStatefulWidget {
  const ShopProfilePage({super.key});
  @override
  ConsumerState<ShopProfilePage> createState() => _ShopProfileState();
}

class _ShopProfileState extends ConsumerState<ShopProfilePage> {
  late final TextEditingController _shopName, _owner, _phone, _email, _address, _gst;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _shopName = TextEditingController(text: s.shopName);
    _owner    = TextEditingController(text: s.ownerName);
    _phone    = TextEditingController(text: s.phone);
    _email    = TextEditingController(text: s.email);
    _address  = TextEditingController(text: s.address);
    _gst      = TextEditingController(text: s.gstNumber);
  }

  @override
  void dispose() {
    for (final c in [_shopName, _owner, _phone, _email, _address, _gst]) c.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsProvider.notifier).update(
        ref.read(settingsProvider).copyWith(
          shopName: _shopName.text.trim(),
          ownerName: _owner.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
          gstNumber: _gst.text.trim(),
        ));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Shop Profile', subtitle: 'Business info shown on invoices',
    children: [
      // Logo picker
      Center(child: Column(children: [
        GestureDetector(
          onTap: () async {
            final path = await pickPhoto(context);
            if (path != null) setState(() => _logoPath = path);
          },
        child: Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
              color: C.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.primary.withValues(alpha: 0.5), width: 2),
            ),
            child: _logoPath != null
                ? ClipRRect(borderRadius: BorderRadius.circular(18),
                    child: Image.file(File(_logoPath!), fit: BoxFit.cover))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.store_outlined, color: C.primary, size: 34),
                    const SizedBox(height: 4),
                    Text('Shop Logo', style: GoogleFonts.syne(
                        fontSize: 10, color: C.textMuted)),
                  ]),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final path = await pickPhoto(context);
            if (path != null) setState(() => _logoPath = path);
          },
          icon: const Icon(Icons.upload_outlined, size: 16, color: C.primary),
          label: Text('Upload Logo', style: GoogleFonts.syne(
              fontSize: 13, color: C.primary, fontWeight: FontWeight.w700)),
        ),
      ])),
      const SizedBox(height: 8),
      const SLabel('BUSINESS DETAILS'),
      AppField(label: 'Shop Name', controller: _shopName, required: true,
          hint: 'e.g. TechFix Pro'),
      AppField(label: 'Owner / Manager Name', controller: _owner, required: true,
          hint: 'Your full name'),
      AppField(label: 'Business Phone', controller: _phone,
          keyboardType: TextInputType.phone, hint: '+91 XXXXX XXXXX'),
      AppField(label: 'Business Email', controller: _email,
          keyboardType: TextInputType.emailAddress, hint: 'shop@email.com'),
      AppField(label: 'Full Address', controller: _address,
          maxLines: 3, hint: 'Shop number, Street, Area, City, PIN'),
      const SLabel('GST & LEGAL'),
      AppField(label: 'GSTIN Number', controller: _gst,
          hint: '29ABCDE1234F1Z5'),
      _infoBanner('GSTIN will appear on all invoices and receipts.'),
      _SaveBtn(onSave: _save),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 2. INVOICE & RECEIPTS
// ═════════════════════════════════════════════════════════════
class InvoicePage extends ConsumerStatefulWidget {
  const InvoicePage({super.key});
  @override
  ConsumerState<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends ConsumerState<InvoicePage> {
  late final TextEditingController _prefix, _footer;
  String _template = 'Standard';
  bool _showQR = true, _showLogo = true, _showTerms = false;

  @override
  void initState() {
    super.initState();
    _prefix = TextEditingController(text: ref.read(settingsProvider).invoicePrefix);
    _footer = TextEditingController(text: 'Thank you for choosing TechFix Pro!');
  }

  @override
  void dispose() { _prefix.dispose(); _footer.dispose(); super.dispose(); }

  void _save() {
    ref.read(settingsProvider.notifier).update(
        ref.read(settingsProvider).copyWith(invoicePrefix: _prefix.text.trim()));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Invoice & Receipts', subtitle: 'Customise invoice appearance',
    children: [
      const SLabel('NUMBER FORMAT'),
      AppField(label: 'Invoice Number Prefix', controller: _prefix, hint: 'INV'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.bgElevated,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: C.textMuted),
          const SizedBox(width: 8),
          Text('Preview: ${_prefix.text.isEmpty ? "INV" : _prefix.text}-2025-0042',
              style: GoogleFonts.syne(fontSize: 13, color: C.text,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SLabel('TEMPLATE STYLE'),
      ...['Standard', 'Branded', 'Minimal', 'Thermal Print'].map((t) {
        final sel = _template == t;
        return GestureDetector(
          onTap: () => setState(() => _template = t),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? C.primary.withValues(alpha: 0.08) : C.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? C.primary : C.border, width: sel ? 2 : 1),
            ),
            child: Row(children: [
              Text(_templateIcon(t), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                    fontSize: 14, color: sel ? C.primary : C.white)),
                Text(_templateDesc(t), style: GoogleFonts.syne(
                    fontSize: 12, color: C.textMuted)),
              ])),
              if (sel) const Icon(Icons.check_circle, color: C.primary, size: 22),
            ]),
          ),
        );
      }),
      const SLabel('INVOICE OPTIONS'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '📱', title: 'Show QR Code',
            subtitle: 'Payment QR on invoice',
            trailing: Switch(value: _showQR,
                onChanged: (v) => setState(() => _showQR = v))),
        SettingsTile(icon: '🖼️', title: 'Show Shop Logo',
            subtitle: 'Display logo at top',
            trailing: Switch(value: _showLogo,
                onChanged: (v) => setState(() => _showLogo = v))),
        SettingsTile(icon: '📝', title: 'Show T&C',
            subtitle: 'Terms and conditions section',
            trailing: Switch(value: _showTerms,
                onChanged: (v) => setState(() => _showTerms = v))),
      ]),
      AppField(label: 'Invoice Footer Text', controller: _footer, maxLines: 2,
          hint: 'Thank you message or return policy'),
      _SaveBtn(onSave: _save),
    ],
  );

  String _templateIcon(String t) =>
      {'Standard': '📄', 'Branded': '🎨', 'Minimal': '📋', 'Thermal Print': '🖨️'}[t] ?? '📄';
  String _templateDesc(String t) => {
    'Standard': 'Clean professional layout with all details',
    'Branded': 'With shop logo, colors and custom header',
    'Minimal': 'Simple list — fast to print and read',
    'Thermal Print': '58mm/80mm thermal printer compatible',
  }[t] ?? '';
}

// ═════════════════════════════════════════════════════════════
// 3. TAX & GST
// ═════════════════════════════════════════════════════════════
class TaxPage extends ConsumerStatefulWidget {
  const TaxPage({super.key});
  @override
  ConsumerState<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends ConsumerState<TaxPage> {
  late final TextEditingController _rate;
  String _taxType = 'GST';
  bool _priceInclusive = false;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(
        text: ref.read(settingsProvider).defaultTaxRate.toStringAsFixed(0));
  }
  @override
  void dispose() { _rate.dispose(); super.dispose(); }

  double get _half => (double.tryParse(_rate.text) ?? 18) / 2;

  void _save() {
    ref.read(settingsProvider.notifier).update(ref.read(settingsProvider)
        .copyWith(defaultTaxRate: double.tryParse(_rate.text) ?? 18));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Tax & GST', subtitle: 'Applied to all repair jobs and POS sales',
    children: [
      const SLabel('TAX TYPE'),
      Row(children: ['GST', 'VAT', 'No Tax'].map((t) {
        final sel = _taxType == t;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: t == 'No Tax' ? 0 : 8),
          child: GestureDetector(
            onTap: () => setState(() => _taxType = t),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? C.primary.withValues(alpha: 0.15) : C.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? C.primary : C.border, width: sel ? 2 : 1),
              ),
              child: Column(children: [
                Text(t == 'GST' ? '🇮🇳' : t == 'VAT' ? '💶' : '🚫',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(t, style: GoogleFonts.syne(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? C.primary : C.textMuted)),
              ]),
            ),
          ),
        ));
      }).toList()),
      const SizedBox(height: 16),
      if (_taxType != 'No Tax') ...[
        AppField(label: 'Default Tax Rate (%)', controller: _rate,
            keyboardType: TextInputType.number,
            hint: '18', suffix: const Icon(Icons.percent, size: 16, color: C.textMuted),
            onChanged: (_) => setState(() {})),
        SettingsGroup(title: '', tiles: [
          SettingsTile(icon: '💰', title: 'Prices are tax-inclusive',
              subtitle: 'Tax is extracted from selling price',
              trailing: Switch(value: _priceInclusive,
                  onChanged: (v) => setState(() => _priceInclusive = v))),
        ]),
        SCard(child: Column(children: [
          _taxRow('CGST (Central)',  '${_half}%', _half),
          const Divider(color: C.border, height: 16),
          _taxRow('SGST (State)',    '${_half}%', _half),
          const Divider(color: C.border, height: 16),
          _taxRow('Total GST',      '${_rate.text}%',
              double.tryParse(_rate.text) ?? 18,  bold: true),
        ])),
        const SizedBox(height: 16),
        _infoBanner(
          'On ₹1,000 service:  CGST = ₹${(_half * 10).toStringAsFixed(0)}  +  '
          'SGST = ₹${(_half * 10).toStringAsFixed(0)}  =  '
          'Total ₹${((double.tryParse(_rate.text) ?? 18) * 10).toStringAsFixed(0)} tax',
        ),
      ],
      _SaveBtn(onSave: _save),
    ],
  );

  Widget _taxRow(String l, String r, double v, {bool bold = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: GoogleFonts.syne(fontSize: 13,
            color: bold ? C.white : C.textMuted,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(r, style: GoogleFonts.syne(fontSize: 14,
            fontWeight: FontWeight.w800, color: C.primary)),
      ]);
}

// ═════════════════════════════════════════════════════════════
// 4. PAYMENT METHODS
// ═════════════════════════════════════════════════════════════
class PaymentMethodsPage extends ConsumerStatefulWidget {
  const PaymentMethodsPage({super.key});
  @override
  ConsumerState<PaymentMethodsPage> createState() => _PayMethodsState();
}

class _PayMethodsState extends ConsumerState<PaymentMethodsPage> {
  late Map<String, bool> _methods;
  final _allOptions = [
    'Cash', 'Card (Debit/Credit)', 'UPI (GPay/PhonePe)',
    'Paytm Wallet', 'Net Banking', 'Bank Transfer (NEFT)',
    'EMI', 'Store Credit',
  ];
  final _icons = <String, String>{
    'Cash': '💵', 'Card (Debit/Credit)': '💳', 'UPI (GPay/PhonePe)': '📱',
    'Paytm Wallet': '👛', 'Net Banking': '🏦', 'Bank Transfer (NEFT)': '🔄',
    'EMI': '📆', 'Store Credit': '🎁',
  };

  @override
  void initState() {
    super.initState();
    final enabled = ref.read(settingsProvider).enabledPayments;
    _methods = { for (var opt in _allOptions) opt : enabled.contains(opt) };
  }

  void _save() {
    final enabled = _methods.entries.where((e) => e.value).map((e) => e.key).toList();
    ref.read(settingsProvider.notifier).update(
        ref.read(settingsProvider).copyWith(enabledPayments: enabled));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Payment Methods', subtitle: 'Enable methods at POS checkout',
    children: [
      _infoBanner('Enabled methods will appear on the POS screen and invoices.'),
      SettingsGroup(title: 'PAYMENT OPTIONS', tiles: _methods.entries.map((e) =>
          SettingsTile(
            icon: _icons[e.key] ?? '💰',
            title: e.key,
            subtitle: e.value ? 'Enabled at POS' : 'Disabled',
            trailing: Switch(value: e.value,
                onChanged: (v) => setState(() => _methods[e.key] = v)),
          )).toList()),
      _SaveBtn(onSave: _save),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 5. TECHNICIANS
// ═════════════════════════════════════════════════════════════
class TechniciansPage extends ConsumerStatefulWidget {
  const TechniciansPage({super.key});
  @override
  ConsumerState<TechniciansPage> createState() => _TechniciansState();
}

class _TechniciansState extends ConsumerState<TechniciansPage> {
  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final techs = ref.watch(techsProvider);
    final active = techs.where((t) => t.isActive).length;

    return _Page(
      title: 'Technicians', subtitle: '$active active · ${techs.length} total',
      fab: FloatingActionButton.extended(
        backgroundColor: C.primary, foregroundColor: C.bg,
        icon: const Icon(Icons.person_add_outlined),
        label: Text('Add Technician', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TechFormPage())),
      ),
      children: [
        if (techs.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(children: [
              const Text('👨‍🔧', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('No technicians added', style: GoogleFonts.syne(
                  fontSize: 16, color: C.textMuted)),
            ]),
          )),
        ...techs.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TechFormPage(tech: t))),
            child: SCard(
              borderColor: t.isActive ? null : C.red.withValues(alpha: 0.3),
              child: Row(children: [
                Stack(children: [
                  CircleAvatar(radius: 26,
                    backgroundColor: (t.isActive ? C.primary : C.textDim).withValues(alpha: 0.15),
                    child: Text(t.name[0], style: GoogleFonts.syne(
                        fontWeight: FontWeight.w800, fontSize: 18,
                        color: t.isActive ? C.primary : C.textMuted)),
                  ),
                  Positioned(bottom: 0, right: 0, child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: t.isActive ? C.green : C.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.bgCard, width: 2),
                    ),
                  )),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t.name, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                      fontSize: 15, color: C.white)),
                  Text(t.specialization, style: GoogleFonts.syne(
                      fontSize: 12, color: C.primary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    _statChip('🔧', '${t.totalJobs} jobs'),
                    const SizedBox(width: 8),
                    _statChip('⭐', t.rating.toStringAsFixed(1)),
                    if (t.phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _statChip('📞', t.phone),
                    ],
                  ]),
                ])),
                Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_outlined, color: C.primary, size: 16)),
              ]),
            ),
          ),
        )),
      ],
    );
  }

  Widget _statChip(String icon, String val) => Row(children: [
    Text(icon, style: const TextStyle(fontSize: 11)),
    const SizedBox(width: 3),
    Text(val, style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
  ]);
}

class TechFormPage extends ConsumerStatefulWidget {
  final Technician? tech;
  const TechFormPage({super.key, this.tech});
  @override
  ConsumerState<TechFormPage> createState() => _TechFormState();
}

class _TechFormState extends ConsumerState<TechFormPage> {
  late final TextEditingController _name, _phone, _spec, _rating, _pin;
  late bool _isActive;
  bool get _isEdit => widget.tech != null;

  @override
  void initState() {
    super.initState();
    _name   = TextEditingController(text: widget.tech?.name ?? '');
    _phone  = TextEditingController(text: widget.tech?.phone ?? '');
    _spec   = TextEditingController(text: widget.tech?.specialization ?? 'General');
    _rating = TextEditingController(text: widget.tech?.rating.toStringAsFixed(1) ?? '5.0');
    _pin    = TextEditingController(text: widget.tech?.pin ?? '');
    _isActive = widget.tech?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _spec, _rating, _pin]) c.dispose();
    super.dispose();
  }

  void _save() async {
    if (_name.text.trim().isEmpty) return;
    final n = ref.read(techsProvider.notifier);
    final existing = widget.tech;
    final id = existing?.techId ?? 'staff_${DateTime.now().millisecondsSinceEpoch}';
    final tech = (existing ?? Technician(
      techId: id,
      shopId: '',
      name: '',
    )).copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      specialization: _spec.text.trim(),
      isActive: _isActive,
      rating: double.tryParse(_rating.text) ?? 5.0,
      pin: _pin.text.trim(),
    );

    try {
      final session = ref.read(currentUserProvider).asData?.value;
      final shopId = session?.shopId ?? '';
      final db = FirebaseDatabase.instance;
      await db.ref('users/$id').set({
        'userId': id,
        'displayName': tech.name,
        'phone': tech.phone,
        'specialization': tech.specialization,
        'isActive': tech.isActive,
        'totalJobs': tech.totalJobs,
        'completedJobs': tech.completedJobs,
        'rating': tech.rating,
        'pin': tech.pin,
        'role': 'technician',
        'shopId': shopId,
        'joinedAt': tech.joinedAt.isEmpty ? DateTime.now().toIso8601String() : tech.joinedAt,
      });
      if (_isEdit) {
        n.update(tech);
      } else {
        n.add(tech);
      }
    } catch (_) {
      if (_isEdit) {
        n.update(tech);
      } else {
        n.add(tech);
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: _isEdit ? 'Edit Technician' : 'New Technician',
    subtitle: _isEdit ? widget.tech!.name : 'Add a team member',
    actions: [TextButton(onPressed: _save,
        child: Text('Save', style: GoogleFonts.syne(
            fontWeight: FontWeight.w800, color: C.primary, fontSize: 15)))],
    children: [
      // Avatar preview
      Center(child: CircleAvatar(radius: 36,
        backgroundColor: C.primary.withValues(alpha: 0.15),
        child: Text(_name.text.isEmpty ? '?' : _name.text[0].toUpperCase(),
            style: GoogleFonts.syne(fontWeight: FontWeight.w900,
                fontSize: 28, color: C.primary)),
      )),
      const SizedBox(height: 20),
      const SLabel('TECHNICIAN DETAILS'),
      AppField(label: 'Full Name', controller: _name, required: true,
          hint: 'e.g. Suresh Kumar', onChanged: (_) => setState(() {})),
      AppField(label: 'Phone Number', controller: _phone,
          keyboardType: TextInputType.phone, hint: '+91 XXXXX XXXXX'),
      AppField(label: 'Staff Login PIN (4 digits)', controller: _pin,
          keyboardType: TextInputType.number, hint: '1234', obscureText: true),
      AppField(label: 'Specialization', controller: _spec,
          hint: 'iOS Repair, Screen Replacement, Water Damage...'),
      AppField(label: 'Rating (0–5)', controller: _rating,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: '5.0'),
      SettingsGroup(title: 'STATUS', tiles: [
        SettingsTile(icon: '✅', title: 'Active Technician',
            subtitle: _isActive
                ? 'Can be assigned to jobs'
                : 'Inactive — not shown in job assignment',
            trailing: Switch(value: _isActive,
                onChanged: (v) => setState(() => _isActive = v))),
      ]),
      _SaveBtn(onSave: _save, label: _isEdit ? '💾  Update Technician' : '➕  Add Technician'),
      if (_isEdit) ...[
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 50,
          child: OutlinedButton(
            onPressed: () {
              ref.read(techsProvider.notifier).delete(widget.tech!.techId);
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(foregroundColor: C.red,
                side: const BorderSide(color: C.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('🗑️  Remove Technician', style: GoogleFonts.syne(
                fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
      ],
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 6. REPAIR WORKFLOW
// ═════════════════════════════════════════════════════════════
class WorkflowPage extends ConsumerStatefulWidget {
  const WorkflowPage({super.key});
  @override
  ConsumerState<WorkflowPage> createState() => _WorkflowState();
}

class _WorkflowState extends ConsumerState<WorkflowPage> {
  late List<Map<String, String>> _stages;

  @override
  void initState() {
    super.initState();
    _stages = List.from(ref.read(settingsProvider).workflowStages);
  }

  void _save() {
    ref.read(settingsProvider.notifier).update(
        ref.read(settingsProvider).copyWith(workflowStages: _stages));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Repair Workflow', subtitle: '${_stages.length} customizable stages',
    children: [
      _infoBanner('These stages appear in the status dropdown when managing repair jobs.'),
      ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIdx, newIdx) {
          setState(() {
            if (newIdx > oldIdx) newIdx -= 1;
            final item = _stages.removeAt(oldIdx);
            _stages.insert(newIdx, item);
          });
        },
        children: _stages.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final sc = C.statusColor(s['title'] ?? '');
          return SCard(
            key: ValueKey(i),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 32, height: 32,
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(child: Text(s['icon'] ?? '⚙️', style: const TextStyle(fontSize: 16)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(s['title'] ?? '', style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                    fontSize: 14, color: C.white)),
                Text(s['desc'] ?? '', style: GoogleFonts.syne(
                    fontSize: 11, color: C.textMuted)),
              ])),
              const Icon(Icons.drag_indicator, color: C.textDim, size: 20),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      _SaveBtn(onSave: _save),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 7. WARRANTY RULES
// ═════════════════════════════════════════════════════════════
class WarrantyPage extends ConsumerStatefulWidget {
  const WarrantyPage({super.key});
  @override
  ConsumerState<WarrantyPage> createState() => _WarrantyPageState();
}

class _WarrantyPageState extends ConsumerState<WarrantyPage> {
  late final TextEditingController _days;

  final _rules = <String, TextEditingController>{
    'Screen Replacement':   TextEditingController(text: '90'),
    'Battery Replacement':  TextEditingController(text: '180'),
    'Water Damage Repair':  TextEditingController(text: '30'),
    'Charging Port Repair': TextEditingController(text: '60'),
    'Software Repair':      TextEditingController(text: '7'),
    'Camera Repair':        TextEditingController(text: '60'),
    'Speaker / Mic Repair': TextEditingController(text: '45'),
    'Back Glass Repair':    TextEditingController(text: '30'),
  };

  @override
  void initState() {
    super.initState();
    _days = TextEditingController(
        text: ref.read(settingsProvider).defaultWarrantyDays.toString());
  }

  @override
  void dispose() {
    _days.dispose();
    for (final c in _rules.values) c.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(settingsProvider.notifier).update(ref.read(settingsProvider)
        .copyWith(defaultWarrantyDays: int.tryParse(_days.text) ?? 30));
    final session = ref.read(currentUserProvider).asData?.value;
    if (session != null && session.shopId.isNotEmpty) {
      ref.read(settingsProvider.notifier).saveToFirebase(session.shopId);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Warranty Rules', subtitle: 'Post-repair warranty periods',
    children: [
      AppField(label: 'Global Default Warranty (Days)', controller: _days,
          keyboardType: TextInputType.number, hint: '30'),
      _infoBanner('This default applies when no specific rule matches the repair type.'),
      const SLabel('BY REPAIR TYPE'),
      ..._rules.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(e.key, style: GoogleFonts.syne(
              fontSize: 13, color: C.text))),
          SizedBox(width: 90,
            child: TextFormField(
              controller: e.value,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(fontSize: 13, color: C.white,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixText: 'days',
                  suffixStyle: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
            ),
          ),
        ]),
      )),
      const SizedBox(height: 16),
      _SaveBtn(onSave: _save),
    ],
  );
}

class FirebaseDiagnosticsPage extends ConsumerStatefulWidget {
  const FirebaseDiagnosticsPage({super.key});

  @override
  ConsumerState<FirebaseDiagnosticsPage> createState() => _FirebaseDiagnosticsPageState();
}

class _FirebaseDiagnosticsPageState extends ConsumerState<FirebaseDiagnosticsPage> {
  bool _running = false;
  String _connection = 'Not checked yet';
  String _user = 'Not checked yet';
  String _permissions = 'Not checked yet';

  Future<void> _runDiagnostics() async {
    setState(() {
      _running = true;
      _connection = 'Checking...';
      _user = 'Checking...';
      _permissions = 'Checking...';
    });

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final db = FirebaseDatabase.instance;
      final connectionSnap = await db.ref('.info/connected').get();
      final connected = connectionSnap.value == true;

      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'firebase_auth',
          code: 'no-current-user',
          message: 'No signed-in user; run diagnostics after logging in.',
        );
      }

      final uid = user.uid;
      final diagRef = db.ref('diagnostics/$uid');

      String permissionsResult;
      try {
        await diagRef.set({
          'lastRunAt': DateTime.now().toUtc().toIso8601String(),
          'platform': Platform.operatingSystem,
        });
        final snap = await diagRef.get();
        permissionsResult = 'Read/write OK at diagnostics/$uid (value: ${snap.value})';
      } on FirebaseException catch (e) {
        permissionsResult = 'Error code: ${e.code}. ${e.message ?? ''}';
      } catch (e) {
        permissionsResult = 'Unexpected error: $e';
      }

      if (!mounted) return;

      setState(() {
        _connection = connected ? 'Online (/.info/connected = true)' : 'Offline or unreachable';
        _user = 'UID: $uid  ·  anonymous: ${user.isAnonymous == true}';
        _permissions = permissionsResult;
        _running = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _connection = 'Firebase error: ${e.code}';
        _user = e.message ?? 'Failed to initialise Firebase';
        _permissions = 'Not available';
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connection = 'Unexpected error: $e';
        _user = 'Not available';
        _permissions = 'Not available';
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
        title: 'Firebase Diagnostics',
        subtitle: 'Check connection and permissions',
        children: [
          _infoBanner(
            'Run this test after configuring Firebase to verify connectivity, authentication and database rules for this device.',
            color: C.primary,
          ),
          SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connection',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _connection,
                  style: GoogleFonts.syne(fontSize: 12, color: C.textMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'User',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user,
                  style: GoogleFonts.syne(fontSize: 12, color: C.textMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Database permissions',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: C.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _permissions,
                  style: GoogleFonts.syne(fontSize: 12, color: C.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _running ? null : _runDiagnostics,
              style: ElevatedButton.styleFrom(
                backgroundColor: C.primary,
                foregroundColor: C.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _running
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: C.bg),
                    )
                  : Text(
                      'Run diagnostics',
                      style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════
// 8. USER ROLES
// ═════════════════════════════════════════════════════════════
class UserRolesPage extends StatefulWidget {
  const UserRolesPage({super.key});
  @override
  State<UserRolesPage> createState() => _UserRolesState();
}

class _UserRolesState extends State<UserRolesPage> {
  final _roles = [
    _RoleData('Super Admin', '👑', C.yellow,
        ['Full system access', 'Settings & billing', 'All reports', 'Delete records'],
        true, true),
    _RoleData('Manager', '🏪', C.primary,
        ['All jobs & customers', 'Inventory management', 'Financial reports', 'No settings access'],
        true, false),
    _RoleData('Technician', '🔧', C.green,
        ['Assigned jobs only', 'Parts & inventory view', 'No financial data', 'No customer PII'],
        false, false),
    _RoleData('Cashier', '💳', C.accent,
        ['POS sales only', 'Invoice printing', 'Job pickup confirmation', 'No repairs or inventory'],
        false, false),
  ];

  @override
  Widget build(BuildContext context) => _Page(
    title: 'User Roles & Access', subtitle: 'Staff permissions by role',
    children: [
      _infoBanner(
        'Assign roles to staff members in Technicians settings. '
        'Role permissions are enforced on all screens.',
      ),
      ..._roles.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SCard(
          glowColor: r.active ? r.color : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: r.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(r.icon, style: const TextStyle(fontSize: 22)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(r.name, style: GoogleFonts.syne(fontWeight: FontWeight.w800,
                    fontSize: 15, color: r.color)),
                if (r.isOwner) Pill('Owner Role', color: r.color, small: true),
              ])),
              if (!r.isOwner)
                Switch(value: r.active,
                    onChanged: (v) => setState(() => r.active = v)),
            ]),
            const SizedBox(height: 10),
            ...r.perms.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 14,
                    color: r.active ? r.color : C.textDim),
                const SizedBox(width: 8),
                Text(p, style: GoogleFonts.syne(fontSize: 12,
                    color: r.active ? C.text : C.textDim)),
              ]),
            )),
          ]),
        ),
      )),
      _SaveBtn(onSave: () {}),
    ],
  );
}

class _RoleData {
  final String name, icon;
  final Color color;
  final List<String> perms;
  bool active, isOwner;
  _RoleData(this.name, this.icon, this.color, this.perms, this.active, this.isOwner);
}

// ═════════════════════════════════════════════════════════════
// 9. WHATSAPP BUSINESS
// ═════════════════════════════════════════════════════════════
class WhatsappPage extends StatefulWidget {
  const WhatsappPage({super.key});
  @override
  State<WhatsappPage> createState() => _WhatsappPageState();
}

class _WhatsappPageState extends State<WhatsappPage> {
  final _apiKey    = TextEditingController();
  final _phoneId   = TextEditingController();
  bool _connected  = false;
  bool _autoPickup = true, _autoUpdate = false, _reminder = true;

  final _templates = [
    _Template('Pickup Ready',
        'Hi {name}! 👋 Your {device} ({job_num}) is ready for collection.\n'
        'Amount due: ₹{amount}. Open Mon–Sat 10am–7pm. 📍 {shop_address}'),
    _Template('Job Update',
        'Hi {name}! Update on your {device}: Status changed to {status}. '
        'Questions? Call us at {phone}.'),
    _Template('Pickup Reminder',
        'Hi {name}, reminder: your {device} has been ready for {days} days. '
        'Please collect at your earliest convenience.'),
  ];

  @override
  Widget build(BuildContext context) => _Page(
    title: 'WhatsApp Business', subtitle: 'Send automated customer messages',
    children: [
      _infoBanner(
        'Requires WhatsApp Business API access from Meta. '
        'Get your API key from business.facebook.com → WhatsApp → API Setup.',
        color: C.green,
      ),
      const SLabel('API CREDENTIALS'),
      AppField(label: 'API Key / Bearer Token', controller: _apiKey,
          hint: 'Paste your API key here'),
      AppField(label: 'Phone Number ID', controller: _phoneId,
          hint: 'From Meta Developer Console'),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity, height: 48,
        child: ElevatedButton.icon(
          onPressed: () => setState(() => _connected = !_connected),
          icon: Icon(_connected ? Icons.check_circle : Icons.link,
              size: 18, color: C.bg),
          label: Text(_connected ? 'Connected ✓' : 'Test Connection',
              style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _connected ? C.green : C.primary,
            foregroundColor: C.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
      const SLabel('AUTO-SEND TRIGGERS'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '🎉', title: 'Pickup Ready Notification',
            subtitle: 'Send when job → Ready for Pickup',
            trailing: Switch(value: _autoPickup,
                onChanged: (v) => setState(() => _autoPickup = v))),
        SettingsTile(icon: '🔄', title: 'Status Update Messages',
            subtitle: 'Notify on every status change',
            trailing: Switch(value: _autoUpdate,
                onChanged: (v) => setState(() => _autoUpdate = v))),
        SettingsTile(icon: '⏰', title: '3-Day Pickup Reminder',
            subtitle: 'Auto-remind if not collected in 3 days',
            trailing: Switch(value: _reminder,
                onChanged: (v) => setState(() => _reminder = v))),
      ]),
      const SLabel('MESSAGE TEMPLATES'),
      ..._templates.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(t.name, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                fontSize: 13, color: C.white)),
            TextButton(onPressed: () => _editTemplate(context, t),
                child: Text('Edit', style: GoogleFonts.syne(
                    color: C.primary, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.bgElevated,
                borderRadius: BorderRadius.circular(8)),
            child: Text(t.body, style: GoogleFonts.syne(
                fontSize: 11, color: C.textMuted, height: 1.5))),
        ])),
      )),
      _SaveBtn(onSave: () {}),
    ],
  );

  void _editTemplate(BuildContext context, _Template t) {
    final ctrl = TextEditingController(text: t.body);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit: ${t.name}', style: GoogleFonts.syne(
            fontWeight: FontWeight.w800, color: C.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _infoBanner('Variables: {name} {device} {amount} {job_num} {status} {days}'),
          TextFormField(controller: ctrl, maxLines: 5,
              style: GoogleFonts.syne(fontSize: 13, color: C.text),
              decoration: const InputDecoration()),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.syne(color: C.textMuted))),
          ElevatedButton(
            onPressed: () { setState(() => t.body = ctrl.text); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: C.primary,
                foregroundColor: C.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Save Template', style: GoogleFonts.syne(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Template { final String name; String body; _Template(this.name, this.body); }

// ═════════════════════════════════════════════════════════════
// 10. SMS GATEWAY
// ═════════════════════════════════════════════════════════════
class SmsPage extends StatefulWidget {
  const SmsPage({super.key});
  @override
  State<SmsPage> createState() => _SmsPageState();
}

class _SmsPageState extends State<SmsPage> {
  String _provider = 'MSG91';
  final _apiKey  = TextEditingController();
  final _sender  = TextEditingController(text: 'TECHFX');
  bool _onPickup = true, _onUpdate = false;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'SMS Gateway', subtitle: 'Text message notifications to customers',
    children: [
      const SLabel('PROVIDER'),
      ...['MSG91', 'Twilio', 'TextLocal', 'Fast2SMS'].map((p) {
        final sel = _provider == p;
        return GestureDetector(
          onTap: () => setState(() => _provider = p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? C.primary.withValues(alpha: 0.08) : C.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? C.primary : C.border, width: sel ? 2 : 1),
            ),
            child: Row(children: [
              Text(_providerIcon(p), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(child: Text(p, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                  fontSize: 13, color: sel ? C.primary : C.white))),
              if (sel) const Icon(Icons.check_circle, color: C.primary, size: 20),
            ]),
          ),
        );
      }),
      const SLabel('CREDENTIALS'),
      AppField(label: 'API Key', controller: _apiKey, hint: 'Enter your $_provider API key'),
      AppField(label: 'Sender ID', controller: _sender, hint: 'TECHFX (6 chars max)'),
      const SLabel('SEND SETTINGS'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '🎉', title: 'Pickup Ready SMS',
            subtitle: 'Auto-send when Ready for Pickup',
            trailing: Switch(value: _onPickup,
                onChanged: (v) => setState(() => _onPickup = v))),
        SettingsTile(icon: '🔄', title: 'Status Update SMS',
            subtitle: 'Notify on status changes',
            trailing: Switch(value: _onUpdate,
                onChanged: (v) => setState(() => _onUpdate = v))),
      ]),
      _SaveBtn(onSave: () {}),
    ],
  );

  String _providerIcon(String p) =>
      {'MSG91': '🇮🇳', 'Twilio': '🌐', 'TextLocal': '🇬🇧', 'Fast2SMS': '⚡'}[p] ?? '📱';
}

// ═════════════════════════════════════════════════════════════
// 11. PUSH NOTIFICATIONS
// ═════════════════════════════════════════════════════════════
class PushNotifPage extends StatefulWidget {
  const PushNotifPage({super.key});
  @override
  State<PushNotifPage> createState() => _PushNotifState();
}

class _PushNotifState extends State<PushNotifPage> {
  final _notifs = <String, bool>{
    'Job Overdue Alert': true,
    'Low Stock Warning': true,
    'New Job Created': false,
    'Job Status Changed': true,
    'Daily Summary (8am)': false,
    'Customer Pickup Reminder': true,
    'Payment Received': true,
    'Warranty Expiring Soon': false,
  };

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Push Notifications', subtitle: 'Alerts sent to this device',
    children: [
      _infoBanner('Push notifications appear in your phone\'s notification centre.'),
      SettingsGroup(title: 'ALERT TYPES',
          tiles: _notifs.entries.map((e) => SettingsTile(
            icon: _notifIcon(e.key),
            title: e.key,
            subtitle: e.value ? 'Enabled' : 'Disabled',
            trailing: Switch(value: e.value,
                onChanged: (v) => setState(() => _notifs[e.key] = v)),
          )).toList()),
      _SaveBtn(onSave: () {}),
    ],
  );

  String _notifIcon(String k) {
    const m = {
      'Job Overdue Alert': '⏰', 'Low Stock Warning': '📦',
      'New Job Created': '🔧', 'Job Status Changed': '🔄',
      'Daily Summary (8am)': '📊', 'Customer Pickup Reminder': '🎉',
      'Payment Received': '💰', 'Warranty Expiring Soon': '🛡️',
    };
    return m[k] ?? '🔔';
  }
}

// ═════════════════════════════════════════════════════════════
// 12. EMAIL
// ═════════════════════════════════════════════════════════════
class EmailPage extends StatelessWidget {
  const EmailPage({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Email Settings', subtitle: 'SMTP configuration for email sending',
    children: [
      _infoBanner('For Gmail: use App Passwords (not your main password). '
          'Enable 2FA first, then generate an App Password.'),
      const SLabel('SMTP CONFIGURATION'),
      const AppField(label: 'SMTP Host', hint: 'smtp.gmail.com'),
      const AppField(label: 'SMTP Port', hint: '587  (TLS)  or  465  (SSL)',
          keyboardType: TextInputType.number),
      const AppField(label: 'From Email Address', hint: 'noreply@yourshop.com',
          keyboardType: TextInputType.emailAddress),
      const AppField(label: 'App Password', hint: '16-character app password'),
      const AppField(label: 'From Display Name', hint: 'TechFix Pro Shop'),
      const SLabel('EMAIL TRIGGERS'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '🧾', title: 'Invoice on Completion',
            subtitle: 'Email invoice when job is completed',
            trailing: Switch(value: true, onChanged: (_) {})),
        SettingsTile(icon: '🎉', title: 'Pickup Ready Email',
            subtitle: 'Notify when device is ready',
            trailing: Switch(value: true, onChanged: (_) {})),
      ]),
      _SaveBtn(onSave: () {}),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 13. PAYMENT GATEWAY
// ═════════════════════════════════════════════════════════════
class PaymentGatewayPage extends StatefulWidget {
  const PaymentGatewayPage({super.key});
  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayState();
}

class _PaymentGatewayState extends State<PaymentGatewayPage> {
  String _selected = '';
  final _key = TextEditingController();
  final _secret = TextEditingController();
  bool _testMode = true;

  final _gateways = [
    ('razorpay', 'Razorpay', '🇮🇳', 'Most popular in India — UPI, cards, wallets'),
    ('stripe',   'Stripe',   '🌐', 'International cards & digital wallets'),
    ('paytm',    'Paytm',    '📱', 'Paytm QR, wallet & UPI payments'),
    ('instamojo','Instamojo','⚡', 'Simple Indian payment collection'),
  ];

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Payment Gateway', subtitle: 'Collect online payments from customers',
    children: [
      const SLabel('SELECT GATEWAY'),
      ..._gateways.map((g) {
        final sel = _selected == g.$1;
        return GestureDetector(
          onTap: () => setState(() => _selected = g.$1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: sel ? C.primary.withValues(alpha: 0.08) : C.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? C.primary : C.border, width: sel ? 2 : 1),
            ),
            child: Row(children: [
              Text(g.$3, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(g.$2, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                    fontSize: 14, color: sel ? C.primary : C.white)),
                Text(g.$4, style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
              ])),
              if (sel) const Icon(Icons.check_circle, color: C.primary),
            ]),
          ),
        );
      }),
      if (_selected.isNotEmpty) ...[
        const SLabel('API CREDENTIALS'),
        AppField(label: 'API Key / Key ID', controller: _key, hint: 'rzp_live_xxxx or pk_live_xxxx'),
        AppField(label: 'API Secret', controller: _secret, hint: 'Secret key from dashboard'),
          SettingsGroup(title: '', tiles: [
          SettingsTile(icon: '🧪', title: 'Test Mode',
              subtitle: _testMode ? 'Using sandbox — no real money' : 'LIVE mode — real payments',
              iconBg: _testMode ? C.yellow.withValues(alpha: 0.1) : C.red.withValues(alpha: 0.1),
              trailing: Switch(value: _testMode,
                  onChanged: (v) => setState(() => _testMode = v))),
        ]),
        if (!_testMode) _infoBanner(
            '⚠️ LIVE mode is active. Real payments will be processed.', color: C.red),
      ],
      _SaveBtn(onSave: () {}),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 14. ACCOUNTING EXPORT
// ═════════════════════════════════════════════════════════════
class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});
  @override
  Widget build(BuildContext context) => _Page(
    title: 'Accounting Export', subtitle: 'Sync or export to accounting software',
    children: [
      ...[
        ('tally', 'Tally ERP 9 / Prime', '📊',
            'Export as Tally XML/CSV. Import via Tally gateway.'),
        ('zoho',  'Zoho Books',           '📚',
            'Auto-sync via Zoho Books API. Invoices & payments.'),
        ('qbo',   'QuickBooks Online',    '💼',
            'Connect via OAuth. Real-time sync.'),
        ('csv',   'Generic CSV Export',   '📋',
            'Download all transactions as CSV for any software.'),
      ].map((a) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Text(a.$3, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(a.$2, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                  fontSize: 14, color: C.white)),
              Text(a.$4, style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
            ])),
            SizedBox(width: 80,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: C.primary,
                    foregroundColor: C.bg, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                child: Text(a.$1 == 'csv' ? 'Export' : 'Connect',
                    style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ]),
        ])),
      )),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 15. SUPPLIER INTEGRATION
// ═════════════════════════════════════════════════════════════
class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});
  @override
  State<SupplierPage> createState() => _SupplierState();
}

class _SupplierState extends State<SupplierPage> {
  final _url    = TextEditingController();
  final _apiKey = TextEditingController();
  bool _autoReorder = false, _emailPO = true;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Supplier Integration', subtitle: 'Auto-reorder low stock parts',
    children: [
      _infoBanner('When stock falls below reorder level, TechFix Pro can '
          'automatically create a Purchase Order and send it to your supplier.'),
      const SLabel('SUPPLIER API'),
      AppField(label: 'Supplier API URL', controller: _url,
          hint: 'https://api.supplier.com/orders'),
      AppField(label: 'API Key', controller: _apiKey,
          hint: 'Supplier-provided API key'),
      const SLabel('REORDER SETTINGS'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '🔄', title: 'Auto-Reorder on Low Stock',
            subtitle: _autoReorder ? 'Creates PO automatically' : 'Manual approval required',
            trailing: Switch(value: _autoReorder,
                onChanged: (v) => setState(() => _autoReorder = v))),
        SettingsTile(icon: '📧', title: 'Email Purchase Orders',
            subtitle: 'Send PO via email to supplier',
            trailing: Switch(value: _emailPO,
                onChanged: (v) => setState(() => _emailPO = v))),
      ]),
      _SaveBtn(onSave: () {}),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 16. AI DIAGNOSTICS
// ═════════════════════════════════════════════════════════════
class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _apiKey = TextEditingController();
  bool _diagnosis = true, _pricing = false, _parts = false;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'AI Diagnostics', subtitle: 'Claude AI for smart repair suggestions',
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF0099CC)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Text('🤖', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text('Claude AI', style: GoogleFonts.syne(fontSize: 22,
              fontWeight: FontWeight.w900, color: Colors.white)),
          Text('by Anthropic', style: GoogleFonts.syne(
              fontSize: 13, color: Colors.white60)),
          const SizedBox(height: 8),
          Text('Smart repair diagnosis, pricing suggestions, and parts recommendations',
              style: GoogleFonts.syne(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center),
        ]),
      ),
      const SizedBox(height: 16),
      const SLabel('API CONFIGURATION'),
      AppField(label: 'Anthropic API Key', controller: _apiKey,
          hint: 'sk-ant-api03-...'),
      _infoBanner('Get your API key from console.anthropic.com'),
      const SLabel('AI FEATURES'),
      SettingsGroup(title: '', tiles: [
        SettingsTile(icon: '🔍', title: 'Diagnosis Suggestions',
            subtitle: 'AI suggests likely causes from customer-reported symptoms',
            trailing: Switch(value: _diagnosis,
                onChanged: (v) => setState(() => _diagnosis = v))),
        SettingsTile(icon: '💰', title: 'Price Recommendations',
            subtitle: 'Market-rate pricing for common repairs',
            trailing: Switch(value: _pricing,
                onChanged: (v) => setState(() => _pricing = v))),
        SettingsTile(icon: '🔩', title: 'Parts Suggestions',
            subtitle: 'Auto-suggest parts needed based on diagnosis',
            trailing: Switch(value: _parts,
                onChanged: (v) => setState(() => _parts = v))),
      ]),
      _SaveBtn(onSave: () {}),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 17. APP LOCK & BIOMETRICS
// ═════════════════════════════════════════════════════════════
class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});
  @override
  State<AppLockPage> createState() => _AppLockState();
}

class _AppLockState extends State<AppLockPage> {
  bool _pinEnabled = false, _biometric = false, _autoLock = true;
  int _lockAfter = 2; // minutes
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _pinMismatch = false;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'App Lock & Biometrics', subtitle: 'Secure your shop data',
    children: [
      SettingsGroup(title: 'LOCK METHODS', tiles: [
        SettingsTile(icon: '🔢', title: 'PIN Lock',
            subtitle: _pinEnabled ? '4-digit PIN is set' : 'No PIN configured',
            trailing: Switch(value: _pinEnabled,
                onChanged: (v) => setState(() { _pinEnabled = v; if (!v) { _pin.clear(); _confirm.clear(); } }))),
        SettingsTile(icon: '🤳', title: 'Biometrics / Face ID',
            subtitle: _biometric ? 'Fingerprint or Face ID enabled' : 'Not configured',
            trailing: Switch(value: _biometric,
                onChanged: (v) => setState(() => _biometric = v))),
        SettingsTile(icon: '⏱️', title: 'Auto-Lock',
            subtitle: 'Lock after $_lockAfter min${_lockAfter == 1 ? "" : "s"} of inactivity',
            trailing: Switch(value: _autoLock,
                onChanged: (v) => setState(() => _autoLock = v))),
      ]),
      if (_autoLock) ...[
        const SLabel('AUTO-LOCK TIMEOUT'),
        Slider(
          value: _lockAfter.toDouble(), min: 1, max: 30,
          divisions: 5, activeColor: C.primary,
          label: '$_lockAfter min',
          onChanged: (v) => setState(() => _lockAfter = v.round()),
        ),
        Center(child: Text('Lock after $_lockAfter minute${_lockAfter == 1 ? "" : "s"}',
            style: GoogleFonts.syne(fontSize: 13, color: C.textMuted))),
        const SizedBox(height: 16),
      ],
      if (_pinEnabled) ...[
        const SLabel('SET PIN'),
        TextFormField(
          controller: _pin, obscureText: true, maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.syne(fontSize: 18, letterSpacing: 12, color: C.white),
          decoration: InputDecoration(
            labelText: 'Enter 4-digit PIN',
            labelStyle: GoogleFonts.syne(color: C.textMuted),
            counterText: '',
          ),
          onChanged: (_) => setState(() => _pinMismatch = false),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _confirm, obscureText: true, maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.syne(fontSize: 18, letterSpacing: 12, color: C.white),
          decoration: InputDecoration(
            labelText: 'Confirm PIN',
            labelStyle: GoogleFonts.syne(color: C.textMuted),
            counterText: '',
            errorText: _pinMismatch ? 'PINs do not match' : null,
          ),
          onChanged: (_) => setState(() => _pinMismatch = false),
        ),
        const SizedBox(height: 16),
      ],
      _SaveBtn(onSave: () {
        if (_pinEnabled) {
          if (_pin.text != _confirm.text) {
            setState(() => _pinMismatch = true);
            return;
          }
        }
      }),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 18. AUDIT LOGS
// ═════════════════════════════════════════════════════════════
class AuditLogsPage extends StatelessWidget {
  const AuditLogsPage({super.key});

  static const _logs = [
    ('2025-02-22 14:33', 'Admin',         'Job JOB-2025-0042 status → In Repair', '🔧'),
    ('2025-02-22 13:15', 'Suresh Kumar',  'Parts updated for JOB-2025-0041',       '🔩'),
    ('2025-02-22 11:00', 'Reception',     'New customer Vikram Singh added',        '👤'),
    ('2025-02-22 10:45', 'Admin',         'Product stock adjusted: S24 Screen +5', '📦'),
    ('2025-02-22 10:30', 'Admin',         'Invoice INV-2025-0041 generated',       '🧾'),
    ('2025-02-21 17:45', 'Ravi Sharma',   'Job JOB-2025-0039 cancelled',           '❌'),
    ('2025-02-21 16:00', 'Admin',         'Settings: Tax rate changed 18% → 18%',  '⚙️'),
    ('2025-02-21 14:22', 'Reception',     'Job JOB-2025-0040 checked in',          '📥'),
    ('2025-02-21 12:00', 'Suresh Kumar',  'Job JOB-2025-0038 status → Completed',  '🏁'),
  ];

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Audit Logs', subtitle: 'Complete activity trail',
    actions: [IconButton(icon: const Icon(Icons.download_outlined, color: C.primary),
        onPressed: () {})],
    children: [
      _infoBanner('All actions by all users are logged here. '
          'Logs cannot be deleted.', color: C.textMuted),
      ..._logs.map((l) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(l.$4, style: const TextStyle(fontSize: 17)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.$3, style: GoogleFonts.syne(fontSize: 13, color: C.text, height: 1.4)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_outline, size: 12, color: C.textMuted),
                const SizedBox(width: 4),
                Text(l.$2, style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
                const Spacer(),
                const Icon(Icons.access_time_outlined, size: 12, color: C.textMuted),
                const SizedBox(width: 4),
                Text(l.$1, style: GoogleFonts.syne(fontSize: 10, color: C.textMuted)),
              ]),
            ])),
          ]),
        ),
      )),
    ],
  );
}

// ═════════════════════════════════════════════════════════════
// 19. CLOUD BACKUP
// ═════════════════════════════════════════════════════════════
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupState();
}

class _BackupState extends State<BackupPage> {
  String _freq = 'Daily';
  String _location = 'Google Drive';
  bool _backing = false;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Cloud Backup', subtitle: 'Keep your data safe & restorable',
    children: [
      SCard(
        glowColor: C.green,
        child: Column(children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('All data backed up', style: GoogleFonts.syne(
              fontSize: 15, fontWeight: FontWeight.w700, color: C.white)),
          Text('Last backup: Today 06:00 AM', style: GoogleFonts.syne(
              fontSize: 12, color: C.green)),
          const SizedBox(height: 4),
          Text('Size: 2.4 MB  ·  384 jobs  ·  47 customers',
              style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
        ]),
      ),
      const SizedBox(height: 16),
      const SLabel('BACKUP SCHEDULE'),
      Row(children: ['Daily', 'Weekly', 'Manual'].map((f) {
        final sel = _freq == f;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: f == 'Manual' ? 0 : 8),
          child: GestureDetector(
            onTap: () => setState(() => _freq = f),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? C.primary.withValues(alpha: 0.15) : C.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? C.primary : C.border, width: sel ? 2 : 1),
              ),
              child: Text(f, textAlign: TextAlign.center,
                  style: GoogleFonts.syne(fontSize: 12, fontWeight: FontWeight.w700,
                      color: sel ? C.primary : C.textMuted)),
            ),
          ),
        ));
      }).toList()),
      const SizedBox(height: 16),
      const SLabel('BACKUP LOCATION'),
      ...['Google Drive', 'iCloud', 'Local Storage'].map((loc) =>
          GestureDetector(
            onTap: () => setState(() => _location = loc),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _location == loc ? C.primary.withValues(alpha: 0.08) : C.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _location == loc ? C.primary : C.border,
                    width: _location == loc ? 2 : 1),
              ),
              child: Row(children: [
                Text(_locIcon(loc), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(loc, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                    fontSize: 13, color: _location == loc ? C.primary : C.white))),
                if (_location == loc) const Icon(Icons.check_circle, color: C.primary),
              ]),
            ),
          )),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 50,
        child: ElevatedButton.icon(
          onPressed: _backing ? null : () async {
            setState(() => _backing = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _backing = false);
          },
          icon: _backing
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: C.bg))
              : const Icon(Icons.cloud_upload_outlined, size: 20),
          label: Text(_backing ? 'Backing up...' : '☁️  Backup Now',
              style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14)),
          style: ElevatedButton.styleFrom(backgroundColor: C.primary, foregroundColor: C.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 50,
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.restore_outlined, size: 20),
          label: Text('Restore from Backup',
              style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 14)),
          style: OutlinedButton.styleFrom(foregroundColor: C.textMuted,
              side: const BorderSide(color: C.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ],
  );

  String _locIcon(String l) =>
      {'Google Drive': '🟢', 'iCloud': '☁️', 'Local Storage': '💾'}[l] ?? '💾';
}

// ═════════════════════════════════════════════════════════════
// 20. EXPORT DATA
// ═════════════════════════════════════════════════════════════
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});
  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  String _fromDate = '2025-01-01';
  String _toDate   = DateTime.now().toIso8601String().substring(0, 10);
  final Map<String, bool> _exporting = {};

  final _exports = [
    ('jobs',      '🔧', 'All Repair Jobs',         'Complete job history with status, costs & timeline'),
    ('customers', '👥', 'Customers List',           'Names, phones, tier, spend history'),
    ('inventory', '📦', 'Inventory & Stock',        'Products, SKUs, prices, stock levels'),
    ('invoices',  '🧾', 'Invoices & Receipts',      'All generated invoices with line items'),
    ('payments',  '💰', 'Payment Transactions',      'All payments received and pending'),
    ('finance',   '📊', 'Financial Summary Report', 'Revenue, costs, tax, profit summary'),
  ];

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Export Data', subtitle: 'Download your shop data',
    children: [
      const SLabel('DATE RANGE'),
      Row(children: [
        Expanded(child: AppField(label: 'From', hint: 'YYYY-MM-DD',
            controller: TextEditingController(text: _fromDate),
            onChanged: (v) => _fromDate = v)),
        const SizedBox(width: 10),
        Expanded(child: AppField(label: 'To', hint: 'YYYY-MM-DD',
            controller: TextEditingController(text: _toDate),
            onChanged: (v) => _toDate = v)),
      ]),
      const SLabel('EXPORT OPTIONS'),
      ..._exports.map((e) {
        final loading = _exporting[e.$1] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.border)),
            child: Row(children: [
              Text(e.$2, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.$3, style: GoogleFonts.syne(fontWeight: FontWeight.w700,
                    fontSize: 13, color: C.white)),
                Text(e.$4, style: GoogleFonts.syne(fontSize: 11, color: C.textMuted)),
              ])),
              const SizedBox(width: 8),
              SizedBox(width: 80, height: 36,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    setState(() => _exporting[e.$1] = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) setState(() => _exporting[e.$1] = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: loading ? C.bgElevated : C.primary,
                    foregroundColor: loading ? C.textMuted : C.bg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  child: loading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: C.primary))
                      : Text('Export', style: GoogleFonts.syne(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
            ]),
          ),
        );
      }),
    ],
  );
}
