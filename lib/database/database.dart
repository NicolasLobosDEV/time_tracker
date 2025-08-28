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
  IntColumn get clientId => integer().references(Clients, #id)();
  TextColumn get name => text()();
  RealColumn get hourlyRate => real()();
  IntColumn get monthlyTimeLimit => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('Active'))();
}

class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get description => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get category => text()();
  BoolColumn get isBillable => boolean().withDefault(const Constant(true))();
  BoolColumn get isBilled => boolean().withDefault(const Constant(false))();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get projectId => integer().nullable().references(Projects, #id)();
  IntColumn get clientId => integer().nullable().references(Clients, #id)();
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
  IntColumn get clientId => integer().references(Clients, #id)();
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
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get category => text()();
  DateTimeColumn get deadline => dateTime()();
  TextColumn get priority => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

class CompanySettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get companyName => text()();
  TextColumn get companyAddress => text()();
  // THIS IS THE FIX
  TextColumn get logoPath => text().nullable()();
  BoolColumn get showLetterhead => boolean().withDefault(const Constant(true))();
}


@DriftDatabase(tables: [Clients, Projects, TimeEntries, Expenses, Invoices, Todos, CompanySettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'app_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}