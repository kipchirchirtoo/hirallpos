import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// Tables mirroring Postgres schema for offline-first querying
class LocalOrganizations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get businessType => text()();
  TextColumn get ownerName => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get plan => text().withDefault(const Constant('trial'))();
  TextColumn get billingStatus => text().withDefault(const Constant('active'))();
  TextColumn get licenseKey => text().nullable()();
  DateTimeColumn get trialEndsAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalBranches extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get name => text()();
  TextColumn get location => text().nullable()();
  TextColumn get tillNumber => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalBranchModules extends Table {
  TextColumn get branchId => text()();
  TextColumn get moduleKey => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get config => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {branchId, moduleKey};
}

class LocalCategories extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#2563EB'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  RealColumn get costPrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get taxRate => real().withDefault(const Constant(16.0))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSales extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text()();
  TextColumn get receiptNumber => text()();
  TextColumn get cashierId => text().nullable()();
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get mpesaReceiptNumber => text().nullable()();
  TextColumn get paymentStatus => text().withDefault(const Constant('completed'))();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))(); // synced | pending
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalTables extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text()();
  TextColumn get tableNumber => text()();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  TextColumn get status => text().withDefault(const Constant('available'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalUsers extends Table {
  TextColumn get id => text()();
  TextColumn get organizationId => text()();
  TextColumn get branchId => text().nullable()();
  TextColumn get email => text()();
  TextColumn get fullName => text()();
  TextColumn get pinCode => text().nullable()();
  TextColumn get role => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  LocalOrganizations,
  LocalBranches,
  LocalBranchModules,
  LocalCategories,
  LocalProducts,
  LocalSales,
  LocalExpenses,
  LocalTables,
  LocalUsers,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'hirall_pos_offline.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
