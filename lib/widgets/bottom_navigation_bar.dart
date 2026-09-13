```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imsnsit/provider/mode_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyBottomNavigationBar extends StatefulWidget {
  const MyBottomNavigationBar({super.key});

  @override
  State<MyBottomNavigationBar> createState() => _MyBottomNavigationBarState();
}

class _MyBottomNavigationBarState extends State<MyBottomNavigationBar> {
  int _selectedIndex = 1;

  late final SharedPreferences prefs = context.read<SharedPreferences>();

  final List<int> disabledIndexes = [];

  @override
  void initState() {
    super.initState();

    if (context.read<ModeProvider>().offline) {
      if (!prefs.containsKey('profileDataLastUpdated')) {
        disabledIndexes.add(0);
      }

      if (!prefs.containsKey('attendanceDataLastUpdated')) {
        disabledIndexes.add(1);
      }
    }
  }

  void onItemTapped(int index) {
    if (disabledIndexes.contains(index)) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      context.go('/profile_screen');
    } else if (index == 1) {
      context.go('/attendance/total');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: theme.copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            selectedItemColor:
                theme.colorScheme.onSecondary.withAlpha(150),
            selectedLabelStyle: GoogleFonts.lexend(),
            unselectedItemColor: theme.colorScheme.onBackground,
            unselectedLabelStyle: GoogleFonts.lexend(),
            selectedIconTheme: IconThemeData(
              color: theme.colorScheme.onSecondary.withAlpha(150),
            ),
            unselectedIconTheme: IconThemeData(
              color: theme.colorScheme.onBackground,
            ),
            backgroundColor: theme.colorScheme.primary,
            type: BottomNavigationBarType.fixed,
            elevation: 2,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month),
                label: 'Attendance',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: onItemTapped,
          ),
        ),
      ),
    );
  }
}
```
