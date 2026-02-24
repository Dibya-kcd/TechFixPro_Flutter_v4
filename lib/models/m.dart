class Job {
  String jobId;
  String jobNumber;
  String shopId;
  String customerId;
  String customerName;
  String customerPhone;
  String brand;
  String model;
  String imei;
  String color;
  String problem;
  String notes;
  String status;
  String? previousStatus;
  String? holdReason;
  String priority;
  String technicianId;
  String technicianName;
  String createdAt;
  String estimatedEndDate;
  double laborCost;
  double partsCost;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  List<PartUsed> partsUsed;
  List<String> intakePhotos;
  List<String> completionPhotos;
  List<TimelineEntry> timeline;
  bool notificationSent;
  String notificationChannel;
  int reopenCount;
  String? warrantyExpiry;
  String? invoiceId;
  String updatedAt;

  Job({
    required this.jobId, required this.jobNumber, required this.shopId,
    required this.customerId, required this.customerName, required this.customerPhone,
    required this.brand, required this.model,
    this.imei = '', this.color = '',
    required this.problem, this.notes = '',
    this.status = 'Checked In',
    this.previousStatus, this.holdReason,
    this.priority = 'Normal',
    this.technicianId = '', this.technicianName = 'Unassigned',
    required this.createdAt, required this.estimatedEndDate,
    this.laborCost = 0, this.partsCost = 0, this.discountAmount = 0,
    this.taxAmount = 0, this.totalAmount = 0,
    this.partsUsed = const [], this.intakePhotos = const [],
    this.completionPhotos = const [], this.timeline = const [],
    this.notificationSent = false, this.notificationChannel = 'WhatsApp',
    this.reopenCount = 0, this.warrantyExpiry, this.invoiceId,
    required this.updatedAt,
  });

  double get subtotal => laborCost + partsCost;
  // Note: taxRate isn't in the schema for jobs, but we might need it for calculation
  // Let's assume taxAmount is pre-calculated or stored. 
  // If we need a rate, we can get it from shop settings.

  bool get isOnHold => status == 'On Hold';
  bool get isCancelled => status == 'Cancelled';
  bool get isCompleted => status == 'Completed';
  bool get isActive => !isOnHold && !isCancelled && !isCompleted;
  bool get canBeReopened => isCompleted || isCancelled;

  bool get isUnderWarranty {
    if (status != 'Completed' || warrantyExpiry == null) return false;
    try {
      final expiry = DateTime.parse(warrantyExpiry!);
      return DateTime.now().isBefore(expiry);
    } catch (_) { return false; }
  }

  bool get isOverdue {
    if (status == 'Completed' || status == 'Cancelled') return false;
    if (estimatedEndDate.isEmpty) return false;
    try { return DateTime.now().isAfter(DateTime.parse(estimatedEndDate)); } catch (_) { return false; }
  }

  Job copyWith({
    String? jobId, String? jobNumber, String? shopId, String? customerId,
    String? customerName, String? customerPhone, String? brand, String? model,
    String? imei, String? color, String? problem, String? notes, String? status,
    String? previousStatus, String? holdReason,
    String? priority, String? technicianId, String? technicianName,
    String? createdAt, String? estimatedEndDate, double? laborCost, double? partsCost,
    double? discountAmount, double? taxAmount, double? totalAmount,
    List<PartUsed>? partsUsed, List<String>? intakePhotos,
    List<String>? completionPhotos, List<TimelineEntry>? timeline,
    bool? notificationSent, String? notificationChannel, int? reopenCount,
    String? warrantyExpiry, String? invoiceId, String? updatedAt,
  }) => Job(
    jobId: jobId ?? this.jobId, jobNumber: jobNumber ?? this.jobNumber,
    shopId: shopId ?? this.shopId, customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    brand: brand ?? this.brand, model: model ?? this.model,
    imei: imei ?? this.imei, color: color ?? this.color,
    problem: problem ?? this.problem, notes: notes ?? this.notes,
    status: status ?? this.status,
    previousStatus: previousStatus ?? this.previousStatus,
    holdReason: holdReason ?? this.holdReason,
    priority: priority ?? this.priority,
    technicianId: technicianId ?? this.technicianId,
    technicianName: technicianName ?? this.technicianName,
    createdAt: createdAt ?? this.createdAt, estimatedEndDate: estimatedEndDate ?? this.estimatedEndDate,
    laborCost: laborCost ?? this.laborCost, partsCost: partsCost ?? this.partsCost,
    discountAmount: discountAmount ?? this.discountAmount, taxAmount: taxAmount ?? this.taxAmount,
    totalAmount: totalAmount ?? this.totalAmount,
    partsUsed: partsUsed ?? this.partsUsed,
    intakePhotos: intakePhotos ?? this.intakePhotos,
    completionPhotos: completionPhotos ?? this.completionPhotos,
    timeline: timeline ?? this.timeline,
    notificationSent: notificationSent ?? this.notificationSent,
    notificationChannel: notificationChannel ?? this.notificationChannel,
    reopenCount: reopenCount ?? this.reopenCount,
    warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
    invoiceId: invoiceId ?? this.invoiceId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class PartUsed {
  final String productId;
  final String name;
  final int quantity;
  final double price;
  PartUsed({required this.productId, required this.name, required this.quantity, required this.price});
  PartUsed copyWith({String? productId, String? name, int? quantity, double? price}) =>
      PartUsed(productId: productId ?? this.productId, name: name ?? this.name, quantity: quantity ?? this.quantity, price: price ?? this.price);
}

class TimelineEntry {
  final String status;
  final String time;
  final String by;
  final String note;
  final String type; // 'flow' | 'note' | 'hold' | 'cancel' | 'reopen'
  TimelineEntry({required this.status, required this.time, required this.by, this.note = '', this.type = 'flow'});
}

class Customer {
  String customerId;
  String shopId;
  String name;
  String phone;
  String email;
  String address;
  String tier;
  bool isVip;
  bool isBlacklisted;
  int points;
  int repairsCount;
  double totalSpend;
  String notes;
  String createdAt;
  String updatedAt;

  Customer({
    required this.customerId, required this.shopId, required this.name, required this.phone,
    this.email = '', this.address = '', this.tier = 'Bronze',
    this.isVip = false, this.isBlacklisted = false,
    this.points = 0, this.repairsCount = 0, this.totalSpend = 0,
    this.notes = '', required this.createdAt, required this.updatedAt,
  });

  Customer copyWith({
    String? customerId, String? shopId, String? name, String? phone, String? email,
    String? address, String? tier, bool? isVip, bool? isBlacklisted,
    int? points, int? repairsCount, double? totalSpend, String? notes,
    String? createdAt, String? updatedAt,
  }) => Customer(
    customerId: customerId ?? this.customerId, shopId: shopId ?? this.shopId,
    name: name ?? this.name, phone: phone ?? this.phone,
    email: email ?? this.email, address: address ?? this.address,
    tier: tier ?? this.tier, isVip: isVip ?? this.isVip,
    isBlacklisted: isBlacklisted ?? this.isBlacklisted,
    points: points ?? this.points, repairsCount: repairsCount ?? this.repairsCount,
    totalSpend: totalSpend ?? this.totalSpend, notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

class Product {
  String productId;
  String shopId;
  String sku;
  String productName;
  String category;
  String brand;
  String description;
  String supplierName;
  double costPrice;
  double sellingPrice;
  int stockQty;
  int reorderLevel;
  List<Map<String, dynamic>> stockHistory;
  bool isActive;
  String imageUrl;
  String createdAt;
  String updatedAt;

  Product({
    required this.productId, required this.shopId, required this.sku,
    required this.productName, required this.category,
    this.brand = '', this.description = '', this.supplierName = '',
    required this.costPrice, required this.sellingPrice,
    required this.stockQty, required this.reorderLevel,
    this.stockHistory = const [], this.isActive = true, this.imageUrl = '',
    required this.createdAt, required this.updatedAt,
  });

  bool get isLowStock => stockQty > 0 && stockQty <= reorderLevel;
  bool get isOutOfStock => stockQty == 0;

  Product copyWith({
    String? productId, String? shopId, String? sku, String? productName, String? category,
    String? brand, String? description, String? supplierName,
    double? costPrice, double? sellingPrice, int? stockQty, int? reorderLevel,
    List<Map<String, dynamic>>? stockHistory, bool? isActive, String? imageUrl,
    String? createdAt, String? updatedAt,
  }) => Product(
    productId: productId ?? this.productId, shopId: shopId ?? this.shopId,
    sku: sku ?? this.sku, productName: productName ?? this.productName, category: category ?? this.category,
    brand: brand ?? this.brand, description: description ?? this.description,
    supplierName: supplierName ?? this.supplierName,
    costPrice: costPrice ?? this.costPrice, sellingPrice: sellingPrice ?? this.sellingPrice,
    stockQty: stockQty ?? this.stockQty, reorderLevel: reorderLevel ?? this.reorderLevel,
    stockHistory: stockHistory ?? this.stockHistory, isActive: isActive ?? this.isActive,
    imageUrl: imageUrl ?? this.imageUrl,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

class Technician {
  String techId;
  String shopId;
  String name;
  String phone;
  String specialization;
  int totalJobs;
  int completedJobs;
  double rating;
  bool isActive;
  String joinedAt;
  String pin;

  Technician({ 
    required this.techId, required this.shopId, required this.name, this.phone = '',
    this.specialization = 'General', this.totalJobs = 0, this.completedJobs = 0,
    this.rating = 5.0, this.isActive = true,
    this.joinedAt = '', this.pin = '',
  });

  Technician copyWith({
    String? techId, String? shopId, String? name, String? phone, String? specialization,
    int? totalJobs, int? completedJobs, double? rating, bool? isActive,
    String? joinedAt, String? pin,
  }) => Technician(
    techId: techId ?? this.techId, shopId: shopId ?? this.shopId,
    name: name ?? this.name, phone: phone ?? this.phone,
    specialization: specialization ?? this.specialization,
    totalJobs: totalJobs ?? this.totalJobs,
    completedJobs: completedJobs ?? this.completedJobs,
    rating: rating ?? this.rating, 
    isActive: isActive ?? this.isActive,
    joinedAt: joinedAt ?? this.joinedAt,
    pin: pin ?? this.pin,
  );
}

class CartItem {
  final Product product;
  int qty;
  CartItem({required this.product, this.qty = 1});
}

class ShopSettings {
  String shopId;
  String shopName;
  String ownerName;
  String phone;
  String email;
  String address;
  String gstNumber;
  String logoUrl;
  String invoicePrefix;
  double defaultTaxRate;
  int defaultWarrantyDays;
  bool requireIntakePhoto;
  bool requireCompletionPhoto;
  Map<String, dynamic> settings;
  String createdAt;
  String plan;
  bool darkMode;

  final List<String> enabledPayments;
  final List<Map<String, String>> workflowStages;

  ShopSettings({
    this.shopId = '',
    this.shopName = 'TechFix Pro',
    this.ownerName = 'Admin',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.gstNumber = '',
    this.logoUrl = '',
    this.invoicePrefix = 'INV-',
    this.defaultTaxRate = 18.0,
    this.defaultWarrantyDays = 30,
    this.requireIntakePhoto = false,
    this.requireCompletionPhoto = false,
    this.settings = const {},
    this.createdAt = '',
    this.plan = 'free',
    this.darkMode = true,
    this.enabledPayments = const ['Cash', 'Card (Debit/Credit)', 'UPI (GPay/PhonePe)', 'Paytm Wallet'],
    this.workflowStages = const [
      {'icon': '📥', 'title': 'Checked In', 'desc': 'Device received at counter'},
      {'icon': '🔍', 'title': 'Diagnosed', 'desc': 'Issue identified by technician'},
      {'icon': '⏳', 'title': 'Awaiting Approval', 'desc': 'Waiting for customer quote approval'},
      {'icon': '⚙️', 'title': 'In Repair', 'desc': 'Work currently being performed'},
      {'icon': '📦', 'title': 'Awaiting Parts', 'desc': 'Waiting for spare parts to arrive'},
      {'icon': '🧪', 'title': 'Quality Check', 'desc': 'Testing device after repair'},
      {'icon': '✅', 'title': 'Ready for Pickup', 'desc': 'Customer notified, device ready'},
      {'icon': '🎉', 'title': 'Delivered', 'desc': 'Device handed over to customer'},
      {'icon': '🚫', 'title': 'Cancelled', 'desc': 'Repair cancelled or rejected'},
    ],
  });

  ShopSettings copyWith({
    String? shopId, String? shopName, String? ownerName, String? phone, String? email,
    String? address, String? gstNumber, String? logoUrl, String? invoicePrefix,
    double? defaultTaxRate, int? defaultWarrantyDays, bool? requireIntakePhoto,
    bool? requireCompletionPhoto, Map<String, dynamic>? settings,
    String? createdAt, String? plan, bool? darkMode,
    List<String>? enabledPayments, List<Map<String, String>>? workflowStages,
  }) => ShopSettings(
    shopId: shopId ?? this.shopId, shopName: shopName ?? this.shopName,
    ownerName: ownerName ?? this.ownerName, phone: phone ?? this.phone,
    email: email ?? this.email, address: address ?? this.address,
    gstNumber: gstNumber ?? this.gstNumber, logoUrl: logoUrl ?? this.logoUrl,
    invoicePrefix: invoicePrefix ?? this.invoicePrefix,
    defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
    defaultWarrantyDays: defaultWarrantyDays ?? this.defaultWarrantyDays,
    requireIntakePhoto: requireIntakePhoto ?? this.requireIntakePhoto,
    requireCompletionPhoto: requireCompletionPhoto ?? this.requireCompletionPhoto,
    settings: settings ?? this.settings, createdAt: createdAt ?? this.createdAt,
    plan: plan ?? this.plan, darkMode: darkMode ?? this.darkMode,
    enabledPayments: enabledPayments ?? this.enabledPayments,
    workflowStages: workflowStages ?? this.workflowStages,
  );
}

class SessionUser {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String shopId;
  final String phone;
  final String pin_hash;
  final bool biometricEnabled;
  final bool isActive;
  final String lastLoginAt;
  final String createdAt;

  SessionUser({
    required this.uid, required this.email, required this.displayName,
    required this.role, required this.shopId, this.phone = '',
    this.pin_hash = '', this.biometricEnabled = false, this.isActive = true,
    this.lastLoginAt = '', required this.createdAt,
  });
}

class Invoice {
  String invoiceId;
  String invoiceNumber;
  String shopId;
  String? jobId;
  String customerId;
  List<Map<String, dynamic>> lineItems;
  double subtotal;
  double discount;
  double taxRate;
  double taxAmount;
  double grandTotal;
  String paymentMethod;
  String paymentStatus;
  double amountPaid;
  double balanceDue;
  String notes;
  String pdfUrl;
  String issuedAt;
  String? paidAt;

  Invoice({
    required this.invoiceId, required this.invoiceNumber, required this.shopId,
    this.jobId, required this.customerId, required this.lineItems,
    required this.subtotal, required this.discount, required this.taxRate,
    required this.taxAmount, required this.grandTotal,
    required this.paymentMethod, required this.paymentStatus,
    required this.amountPaid, required this.balanceDue,
    this.notes = '', this.pdfUrl = '',
    required this.issuedAt, this.paidAt,
  });
}
