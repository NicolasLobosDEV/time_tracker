// lib/screens/main_screen.dart
import 'package:flutter/material.dart';

// Import all of your screen files so this file knows what they are.
import 'package:time_tracker/screens/clients/clients_screen.dart';
import 'package:time_tracker/screens/expenses/expenses_screen.dart';
import 'package:time_tracker/screens/home_screen.dart';
import 'package:time_tracker/screens/invoices/invoices_screen.dart';
import 'package:time_tracker/screens/projects/projects_screen.dart';
import 'package:time_tracker/screens/settings/settings_screen.dart';
import 'package:time_tracker/screens/time_tracker/time_tracker_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // This list now correctly references the imported screen classes.
  // The 'const' keyword was removed from the list initialization below.
  final List<Widget> _screens = <Widget>[
    HomeScreen(),
    TimeTrackerScreen(),
    ProjectsScreen(),
    ClientsScreen(),
    ExpensesScreen(),
    InvoicesScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  final List<String> _titles = const <String>[
    'Tasks To-Do',
    'Time Tracker',
    'Projects',
    'Clients',
    'Expenses',
    'Invoices',
    'Reports',
    'Settings',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Expenses',
          ),
            BottomNavigationBarItem(
            icon: Icon(Icons.request_quote),
            label: 'Invoices',
          ),
            BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
            BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }
}