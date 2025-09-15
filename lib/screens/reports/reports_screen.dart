import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:time_tracker/database/database.dart';


// (Your table classes like Clients, Projects, etc. remain here)
class Clients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
}

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1)();
  IntColumn get clientId => integer().references(Clients, #id)();
  RealColumn get hourlyRate => real()();
  IntColumn get monthlyTimeLimitHours => integer().nullable()();
}

class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get category => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  BoolColumn get isBillable => boolean().withDefault(const Constant(true))();
  BoolColumn get isBilled => boolean().withDefault(const Constant(false))();
  IntColumn get invoiceId => integer().nullable()();
}

// In lib/database/database.dart
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
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Draft'))();
  TextColumn get lineItemsJson => text().nullable()();
}

class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get priority => text()(); // P1, P2, P3
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get deadline => dateTime()();
  IntColumn get projectId => integer().references(Projects, #id)();
  TextColumn get category => text()();
  RealColumn get estimatedHours => real().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

class CompanySettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get companyName => text().nullable()();
  TextColumn get companyAddress => text().nullable()();
  TextColumn get cnpj => text().nullable()();
  TextColumn get companyLogoPath => text().nullable()();
  TextColumn get invoiceLetterhead => text().nullable()();
  IntColumn get weeklyHoursGoal => integer().nullable()();
  IntColumn get monthlyHoursGoal => integer().nullable()();
  RealColumn get reportsYAxisMax => real().nullable()();
  TextColumn get invoiceLetterheadImagePath => text().nullable()();

  // --- THIS IS THE ONLY LINE THAT WAS ADDED ---
  BoolColumn get showLetterhead =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Clients,
    Projects,
    TimeEntries,
    Expenses,
    Invoices,
    CompanySettings,
    Todos,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Use getApplicationSupportDirectory to avoid OneDrive
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'app_tracker.sqlite'));
    print(dbFolder);

    return NativeDatabase.createInBackground(file);
  });
}
