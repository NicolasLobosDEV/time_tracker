// lib/screens/reports/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

enum TimePeriod { currentWeek, pastWeek, pastMonth, pastYear, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.currentWeek;
  late Future<Map<String, dynamic>> _reportDataFuture;

  DateTime? _customStartDate;
  DateTime? _customEndDate;
  // REMOVED the fixed _yAxisMax state variable

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _generateReportData(_selectedPeriod);
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return "0h 0m";
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Future<Map<String, dynamic>> _generateReportData(TimePeriod period) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final settings = await (db.select(
      db.companySettings,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    // (Date calculation, query, and data processing remain the same)
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case TimePeriod.currentWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        endDate = startDate.add(const Duration(days: 7));
        break;
      case TimePeriod.pastWeek:
        final startOfLastWeek = now.subtract(Duration(days: now.weekday + 6));
        startDate = DateTime(
          startOfLastWeek.year,
          startOfLastWeek.month,
          startOfLastWeek.day,
        );
        endDate = startDate.add(const Duration(days: 7));
        break;
      case TimePeriod.pastMonth:
        final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        endDate = firstDayOfCurrentMonth.subtract(const Duration(days: 1));
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      case TimePeriod.pastYear:
        startDate = DateTime(now.year - 1, 1, 1);
        endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        break;
      case TimePeriod.custom:
        startDate = _customStartDate ?? DateTime(now.year, now.month, now.day);
        endDate =
            _customEndDate ??
            DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }

    final query =
        db.select(db.timeEntries).join([
            drift.innerJoin(
              db.projects,
              db.projects.id.equalsExp(db.timeEntries.projectId),
            ),
          ])
          ..where(db.timeEntries.startTime.isBetweenValues(startDate, endDate))
          ..where(db.timeEntries.endTime.isNotNull());
    final results = await query.get();

    Duration totalDuration = Duration.zero;
    double totalRevenue = 0;
    Map<int, double> chartData;
    bool isWeekly =
        period == TimePeriod.currentWeek || period == TimePeriod.pastWeek;

    if (isWeekly) {
      chartData = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
    } else {
      chartData = {for (var i = 1; i <= 12; i++) i: 0.0};
    }

    for (final row in results) {
      final entry = row.readTable(db.timeEntries);
      final project = row.readTable(db.projects);
      final duration = entry.endTime!.difference(entry.startTime);
      final hours = duration.inMinutes / 60.0;

      totalDuration += duration;
      totalRevenue += hours * project.hourlyRate;

      int key = isWeekly ? entry.startTime.weekday : entry.startTime.month;

      if (chartData.containsKey(key)) {
        chartData.update(key, (value) => value + hours);
      }
    }

    return {
      'totalDuration': totalDuration,
      'totalRevenue': totalRevenue,
      'chartData': chartData,
      'startDate': startDate,
      'endDate': endDate,
      'weeklyGoal': settings?.weeklyHoursGoal,
      'monthlyGoal': settings?.monthlyHoursGoal,
      // CHANGE 1: Pass the Y-axis value from settings to the builder
      'yAxisMax': settings?.reportsYAxisMax ?? 12.0,
    };
  }

  // (selectCustomDateRange and getPeriodDisplayName functions remain the same)
  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _customStartDate ?? DateTime.now(),
        end: _customEndDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
        _selectedPeriod = TimePeriod.custom;
        _reportDataFuture = _generateReportData(TimePeriod.custom);
      });
    }
  }

  String _getPeriodDisplayName(TimePeriod period) {
    switch (period) {
      case TimePeriod.currentWeek:
        return 'This Week';
      case TimePeriod.pastWeek:
        return 'Last Week';
      case TimePeriod.pastMonth:
        return 'Last Month';
      case TimePeriod.pastYear:
        return 'Last Year';
      case TimePeriod.custom:
        return 'Custom...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // (Dropdown remains the same)
            SizedBox(
              width: 200,
              child: DropdownButton<TimePeriod>(
                value: _selectedPeriod,
                isExpanded: true,
                items: TimePeriod.values.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(_getPeriodDisplayName(period)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue == null) return;
                  if (newValue == TimePeriod.custom) {
                    _selectCustomDateRange();
                  } else {
                    setState(() {
                      _selectedPeriod = newValue;
                      _reportDataFuture = _generateReportData(newValue);
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            FutureBuilder<Map<String, dynamic>>(
              future: _reportDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Expanded(
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }
                if (!snapshot.hasData ||
                    snapshot.data!['totalDuration'] == Duration.zero) {
                  return const Expanded(
                    child: Center(
                      child: Text('No hours found for this period.'),
                    ),
                  );
                }

                final data = snapshot.data!;
                final Duration totalDuration = data['totalDuration'];
                final double totalRevenue = data['totalRevenue'];
                final Map<int, double> chartData = data['chartData'];
                final DateTime startDate = data['startDate'];
                final DateTime endDate = data['endDate'];
                final int? weeklyGoal = data['weeklyGoal'];
                final int? monthlyGoal = data['monthlyGoal'];
                // CHANGE 2: Get the Y-axis value from the data
                final double yAxisMax = data['yAxisMax'];

                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Hours Tracked (${DateFormat.yMd().format(startDate)} - ${DateFormat.yMd().format(endDate)})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 200,
                        // CHANGE 3: Pass the value to the chart builder
                        child: BarChart(_buildBarChart(chartData, yAxisMax)),
                      ),
                      const SizedBox(height: 32),

                      // (Cards remain the same)
                      if ((_selectedPeriod == TimePeriod.currentWeek ||
                              _selectedPeriod == TimePeriod.pastWeek) &&
                          weeklyGoal != null &&
                          weeklyGoal > 0)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.flag,
                              color: Colors.amberAccent,
                            ),
                            title: const Text('Weekly Goal Progress'),
                            trailing: Text(
                              '${_formatDuration(totalDuration)} / ${weeklyGoal}h 0m',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      if (_selectedPeriod == TimePeriod.pastMonth &&
                          monthlyGoal != null &&
                          monthlyGoal > 0)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.flag,
                              color: Colors.amberAccent,
                            ),
                            title: const Text('Monthly Goal Progress'),
                            trailing: Text(
                              '${_formatDuration(totalDuration)} / ${monthlyGoal}h 0m',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.timer,
                            color: Colors.tealAccent,
                          ),
                          title: const Text('Total Time Tracked'),
                          trailing: Text(
                            _formatDuration(totalDuration),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.attach_money,
                            color: Colors.greenAccent,
                          ),
                          title: const Text('Total Revenue'),
                          trailing: Text(
                            NumberFormat.simpleCurrency(
                              locale: 'en_US',
                            ).format(totalRevenue),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // CHANGE 4: Update the function signature and use the dynamic value
  BarChartData _buildBarChart(Map<int, double> data, double yAxisMax) {
    bool isWeekly =
        _selectedPeriod == TimePeriod.currentWeek ||
        _selectedPeriod == TimePeriod.pastWeek;

    return BarChartData(
      maxY: yAxisMax,
      barGroups: data.entries.map((entry) {
        return BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: Theme.of(context).primaryColor,
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              // Correct way to return the title widget
              return Text(
                '${value.toInt()}h',
                style: const TextStyle(fontSize: 10),
              );
            },
            interval: yAxisMax > 0 ? yAxisMax / 4 : 1,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              String text;
              if (isWeekly) {
                switch (value.toInt()) {
                  case 1:
                    text = 'Mon';
                    break;
                  case 2:
                    text = 'Tue';
                    break;
                  case 3:
                    text = 'Wed';
                    break;
                  case 4:
                    text = 'Thu';
                    break;
                  case 5:
                    text = 'Fri';
                    break;
                  case 6:
                    text = 'Sat';
                    break;
                  case 7:
                    text = 'Sun';
                    break;
                  default:
                    text = '';
                    break;
                }
              } else {
                text = DateFormat.MMM().format(DateTime(0, value.toInt()));
              }
              // Correct way to return the title widget
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(text, style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: Colors.white10, strokeWidth: 1),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.blueGrey,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final hours = rod.toY;
            return BarTooltipItem(
              '${hours.toStringAsFixed(1)} hours',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
    );
  }
}
