import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' as drift;

enum TimePeriod { thisWeek, lastWeek, lastMonth, thisYear }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.thisWeek;
  List<BarChartGroupData> _chartData = [];
  double _totalHours = 0;
  double _totalEarnings = 0;
  double _maxY = 10; // Default max Y for the chart

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateReportData();
  }

  DateTimeRange _getDateRange(TimePeriod period) {
    final now = DateTime.now();
    switch (period) {
      case TimePeriod.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case TimePeriod.lastWeek:
        final endOfLastWeek = now.subtract(Duration(days: now.weekday));
        final startOfLastWeek = endOfLastWeek.subtract(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(startOfLastWeek.year, startOfLastWeek.month, startOfLastWeek.day),
          end: DateTime(endOfLastWeek.year, endOfLastWeek.month, endOfLastWeek.day, 23, 59, 59),
        );
      case TimePeriod.lastMonth:
        final firstDayOfCurrentMonth = DateTime(now.year, now.month, 1);
        final lastDayOfLastMonth = firstDayOfCurrentMonth.subtract(const Duration(days: 1));
        final firstDayOfLastMonth = DateTime(lastDayOfLastMonth.year, lastDayOfLastMonth.month, 1);
        return DateTimeRange(start: firstDayOfLastMonth, end: lastDayOfLastMonth);
      case TimePeriod.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    }
  }

  Future<void> _updateReportData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final range = _getDateRange(_selectedPeriod);

    final query = db.select(db.timeEntries).join([
      drift.innerJoin(db.projects, db.projects.id.equalsExp(db.timeEntries.projectId)),
    ])
      ..where(db.timeEntries.startTime.isBetweenValues(range.start, range.end))
      ..where(db.timeEntries.endTime.isNotNull());

    final results = await query.get();

    double totalHours = 0;
    double totalEarnings = 0;
    Map<int, double> hoursPerGroup = {};

    for (final row in results) {
      final entry = row.readTable(db.timeEntries);
      final project = row.readTable(db.projects);
      final duration = entry.endTime!.difference(entry.startTime);
      final hours = duration.inMinutes / 60.0;

      totalHours += hours;
      totalEarnings += hours * project.hourlyRate;

      int groupKey;
      if (_selectedPeriod == TimePeriod.thisYear) {
        groupKey = entry.startTime.month; // Group by month
      } else {
        groupKey = entry.startTime.weekday; // Group by day of the week
      }
      hoursPerGroup.update(groupKey, (value) => value + hours, ifAbsent: () => hours);
    }

    double maxY = 10;
    if (hoursPerGroup.isNotEmpty) {
      maxY = hoursPerGroup.values.reduce((a, b) => a > b ? a : b) * 1.2;
      if (maxY < 10) maxY = 10;
    }

    if(mounted) {
      setState(() {
        _totalHours = totalHours;
        _totalEarnings = totalEarnings;
        _maxY = maxY;
        _chartData = _generateChartGroups(hoursPerGroup);
      });
    }
  }

  List<BarChartGroupData> _generateChartGroups(Map<int, double> hoursPerGroup) {
    if (_selectedPeriod == TimePeriod.thisYear) {
      return List.generate(12, (i) {
        final month = i + 1;
        return BarChartGroupData(
          x: month,
          barRods: [BarChartRodData(toY: hoursPerGroup[month] ?? 0, width: 15, borderRadius: BorderRadius.circular(4))],
        );
      });
    } else {
      return List.generate(7, (i) {
        final day = i + 1;
        return BarChartGroupData(
          x: day,
          barRods: [BarChartRodData(toY: hoursPerGroup[day] ?? 0, width: 15, borderRadius: BorderRadius.circular(4))],
        );
      });
    }
  }

  Widget getBottomTitles(double value, TitleMeta meta) {
    final style = TextStyle(color: Colors.grey.shade400, fontSize: 12);
    String text;

    if (_selectedPeriod == TimePeriod.thisYear) {
      text = DateFormat.MMM().format(DateTime(0, value.toInt()));
    } else {
      switch (value.toInt()) {
        case 1: text = 'Mon'; break;
        case 2: text = 'Tue'; break;
        case 3: text = 'Wed'; break;
        case 4: text = 'Thu'; break;
        case 5: text = 'Fri'; break;
        case 6: text = 'Sat'; break;
        case 7: text = 'Sun'; break;
        default: text = ''; break;
      }
    }
    // FIX: The `SideTitleWidget` constructor has been updated. This new format
    // should resolve the 'meta' parameter error.
    return Text(text, style: style);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(locale: 'en_US', name: 'USD');

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SegmentedButton<TimePeriod>(
            segments: const <ButtonSegment<TimePeriod>>[
              ButtonSegment(value: TimePeriod.thisWeek, label: Text('This Week')),
              ButtonSegment(value: TimePeriod.lastWeek, label: Text('Last Week')),
              ButtonSegment(value: TimePeriod.lastMonth, label: Text('Last Month')),
              ButtonSegment(value: TimePeriod.thisYear, label: Text('This Year')),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (Set<TimePeriod> newSelection) {
              setState(() {
                _selectedPeriod = newSelection.first;
                _updateReportData();
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Total Hours', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_totalHours.toStringAsFixed(2), style: Theme.of(context).textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text('Total Earnings', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(currencyFormat.format(_totalEarnings), style: Theme.of(context).textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                maxY: _maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String title;
                      if (_selectedPeriod == TimePeriod.thisYear) {
                        title = DateFormat.MMMM().format(DateTime(0, group.x.toInt()));
                      } else {
                        title = DateFormat.EEEE().format(DateTime(2024, 1, group.x.toInt() + 21)); // A random monday
                      }
                      return BarTooltipItem(
                        '$title\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: <TextSpan>[
                          TextSpan(
                            text: '${rod.toY.toStringAsFixed(2)} hours',
                            style: const TextStyle(color: Colors.yellow),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: getBottomTitles, reservedSize: 38)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _chartData,
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 2),
              ),
            ),
          )
        ],
      ),
    );
  }
}

