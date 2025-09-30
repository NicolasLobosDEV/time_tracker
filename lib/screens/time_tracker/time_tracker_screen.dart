// lib/screens/time_tracker/time_tracker_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' hide Column;
import 'add_entry_dialog.dart';
import 'edit_entry_screen.dart';

class TimeTrackerScreen extends StatefulWidget {
  const TimeTrackerScreen({super.key});

  @override
  State<TimeTrackerScreen> createState() => _TimeTrackerScreenState();
}

class _TimeTrackerScreenState extends State<TimeTrackerScreen> {
  Widget _buildRecentEntriesList(AppDatabase db) {
    final recentEntriesQuery = db.select(db.timeEntries)
      ..where((t) => t.endTime.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
      ..limit(50);

    return StreamBuilder<List<TimeEntry>>(
      stream: recentEntriesQuery.watch(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        if (entries.isEmpty && snapshot.connectionState == ConnectionState.active) {
          return const Center(child: Text("No time entries yet."));
        }
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final duration = entry.endTime!.difference(entry.startTime);
            return Card(
              // Card color is now based on whether it has been invoiced
              color: entry.isBilled
                  ? Colors.green.withAlpha(38)
                  : Colors.red.withAlpha(38),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Dismissible(
                key: Key(entry.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  (db.delete(db.timeEntries)..where((t) => t.id.equals(entry.id))).go();
                },
                child: ListTile(
                  title: Text(entry.description),
                  subtitle: Text("${entry.category} on ${DateFormat.yMd().format(entry.startTime)}"),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => EditEntryScreen(entry: entry),
                    ));
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatDuration(duration)),
                      const SizedBox(width: 16),
                      // This switch now controls the 'isLogged' status
                      Tooltip(
                        message: 'Mark as Logged',
                        child: Switch(
                          value: entry.isLogged,
                          onChanged: (newValue) {
                            final updatedEntry = TimeEntriesCompanion(
                              isLogged: Value(newValue),
                            );
                            (db.update(db.timeEntries)..where((t) => t.id.equals(entry.id))).write(updatedEntry);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);

    return Scaffold(
      body: Column(
        children: [
          _buildActiveTimer(context, db),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Entries", style: Theme.of(context).textTheme.titleMedium),
                _buildWeeklyTotal(db),
              ],
            ),
          ),
          Expanded(
            child: _buildRecentEntriesList(db),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const AddEntryDialog();
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildActiveTimer(BuildContext context, AppDatabase db) {
    final activeTimerQuery = db.select(db.timeEntries)
      ..where((t) => t.endTime.isNull())
      ..limit(1);

    return StreamBuilder<List<TimeEntry>>(
      stream: activeTimerQuery.watch(),
      builder: (context, snapshot) {
        final activeEntry = snapshot.data?.firstOrNull;
        if (activeEntry == null) {
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: const Text("No active timer"),
              subtitle: const Text("Click the '+' to begin a new task"),
              trailing: Icon(Icons.play_circle_outline, color: Colors.grey.shade600),
            ),
          );
        }
        return ActiveTimerCard(activeEntry: activeEntry);
      },
    );
  }

  Widget _buildWeeklyTotal(AppDatabase db) {
    return StreamBuilder<List<TimeEntry>>(
      stream: db.select(db.timeEntries).watch(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final now = DateTime.now();
        final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        var weeklyTotal = Duration.zero;
        for (var entry in entries) {
          if (!entry.startTime.isBefore(startOfWeek) && entry.startTime.isBefore(endOfWeek) && entry.endTime != null) {
            weeklyTotal += entry.endTime!.difference(entry.startTime);
          }
        }
        return Text("Week: ${_formatDuration(weeklyTotal)}");
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

class ActiveTimerCard extends StatefulWidget {
  final TimeEntry activeEntry;
  const ActiveTimerCard({super.key, required this.activeEntry});

  @override
  State<ActiveTimerCard> createState() => _ActiveTimerCardState();
}

class _ActiveTimerCardState extends State<ActiveTimerCard> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.activeEntry.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.activeEntry.startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _stopTimer() {
    final db = Provider.of<AppDatabase>(context, listen: false);
    (db.update(db.timeEntries)..where((t) => t.id.equals(widget.activeEntry.id)))
      .write(TimeEntriesCompanion(
        endTime: Value(DateTime.now()),
      ));
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).primaryColor.withAlpha(51),
      margin: const EdgeInsets.all(8.0),
      child: ListTile(
        title: Text(widget.activeEntry.description, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(widget.activeEntry.category),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 30),
              onPressed: _stopTimer,
            ),
          ],
        ),
      ),
    );
  }
}

