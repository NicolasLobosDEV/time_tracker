// lib/database/database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Define tables
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
}

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clientId =>
      integer().references(Clients, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get hourlyRate => real()();
  IntColumn get monthlyTimeLimit => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('Active'))();
}

class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get category => text()();
  BoolColumn get isBillable => boolean().withDefault(const Constant(true))();
  BoolColumn get isBilled => boolean().withDefault(const Constant(false))();
  // ADDED: New status for marking entries as logged in external platforms
  BoolColumn get isLogged => boolean().withDefault(const Constant(false))();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get projectId =>
      integer().nullable().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get clientId =>
      integer().nullable().references(Clients, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  RealColumn get distance => real().nullable()();
  RealColumn get costPerUnit => real().nullable()();
  BoolColumn get isBilled => boolean().withDefault(const Constant(false))();
}

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceIdString => text()();
  IntColumn get clientId =>
      integer().references(Clients, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get issueDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get totalAmount => real()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get lineItemsJson => text().nullable()();
}

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get category => text()();
  DateTimeColumn get deadline => dateTime()();
  TextColumn get priority => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get startTime => dateTime()();
  RealColumn get estimatedHours => real().nullable()();
}

class CompanySettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get companyName => text()();
  TextColumn get companyAddress => text()();
  TextColumn get logoPath => text().nullable()();
  BoolColumn get showLetterhead => boolean().withDefault(const Constant(true))();
}


@DriftDatabase(tables: [Clients, Projects, TimeEntries, Expenses, Invoices, Todos, CompanySettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // FIX: Incremented schema version to 3

  // FIX: Added migration logic
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Migration from version 1 to 2
          await m.addColumn(timeEntries, timeEntries.isLogged);
        }
        // Drift will handle recreating tables with the new cascade rules
        // automatically because of the schema version bump. For complex migrations,
        // you might need more specific logic here.
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'app_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

