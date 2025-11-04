import 'package:flutter/material.dart';
import 'package:exambeing/helpers/database_helper.dart'; // Local DB
import 'package:exambeing/services/notification_service.dart'; // Notification service
import 'package:intl/intl.dart'; // Date formatting ke liye

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late Future<List<TimetableEntry>> _entriesFuture;
  final dbHelper = DatabaseHelper.instance;
  final notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  void _loadEntries() {
    setState(() {
      _entriesFuture = dbHelper.getAllTimetableEntries();
    });
  }

  // Helper function: Din (1-7) ko string (Monday) mein badalna
  String _dayOfWeekToString(int day) {
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][day - 1]; // 1 = Monday, etc.
  }

  // Entry delete karna
  Future<void> _deleteEntry(TimetableEntry entry) async {
    // Pehle notification cancel karo
    await notificationService.cancelNotification(entry.notificationId);
    // Phir database se delete karo
    await dbHelper.deleteTimetableEntry(entry.id!);
    _loadEntries(); // List refresh karo
  }

  // Nayi entry add karne ka form (Bottom Sheet)
  void _showAddEntrySheet() {
    final formKey = GlobalKey<FormState>();
    String subjectName = '';
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    int selectedDay = DateTime.now().weekday; // Default aaj ka din

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Taaki keyboard khulne par UI upar chala jaaye
      builder: (ctx) {
        // StatefulBuilder ka istemal taaki BottomSheet ke andar time update ho sake
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add to Timetable', style: Theme.of(ctx).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      // Subject Name
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Subject Name', border: OutlineInputBorder()),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a subject name';
                          }
                          return null;
                        },
                        onSaved: (value) => subjectName = value!.trim(),
                      ),
                      const SizedBox(height: 16),
                      // Day of Week
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Day of Week', border: OutlineInputBorder()),
                        value: selectedDay,
                        items: List.generate(7, (index) {
                          return DropdownMenuItem(
                            value: index + 1, // 1 se 7
                            child: Text(_dayOfWeekToString(index + 1)),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      // Start aur End Time
                      Row(
                        children: [
                          // Start Time
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: ctx,
                                  initialTime: startTime ?? TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setSheetState(() => startTime = time);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                                child: Text(startTime?.format(ctx) ?? 'Select Time'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // End Time
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: ctx,
                                  initialTime: endTime ?? startTime ?? TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setSheetState(() => endTime = time);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder()),
                                child: Text(endTime?.format(ctx) ?? 'Select Time'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          child: const Text('Save Entry'),
                          onPressed: () async {
                            if (startTime == null || endTime == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select start and end time')));
                              return;
                            }
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                              
                              final notificationId = int.parse('$selectedDay${startTime!.hour.toString().padLeft(2, '0')}${startTime!.minute.toString().padLeft(2, '0')}');

                              final newEntry = TimetableEntry(
                                subjectName: subjectName,
                                startTime: startTime!,
                                endTime: endTime!,
                                dayOfWeek: selectedDay,
                                notificationId: notificationId,
                              );

                              await dbHelper.createTimetableEntry(newEntry);

                              await notificationService.scheduleWeeklyNotification(
                                id: notificationId,
                                title: 'Time for ${newEntry.subjectName}!',
                                body: 'Your scheduled session starts now (${newEntry.startTime.format(ctx)} - ${newEntry.endTime.format(ctx)})',
                                day: newEntry.dayOfWeek,
                                time: newEntry.startTime,
                              );

                              if (mounted) Navigator.pop(ctx);
                              _loadEntries();
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Weekly Timetable'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEntrySheet,
        tooltip: 'Add Entry',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<TimetableEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Your timetable is empty.\nTap the + button to add your first entry!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          final entries = snapshot.data!;
          
          final Map<int, List<TimetableEntry>> groupedEntries = {};
          for (var entry in entries) {
            if (groupedEntries[entry.dayOfWeek] == null) {
              groupedEntries[entry.dayOfWeek] = [];
            }
            groupedEntries[entry.dayOfWeek]!.add(entry);
          }
          
          final sortedDays = groupedEntries.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final day = sortedDays[index];
              final dayEntries = groupedEntries[day]!;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dayOfWeekToString(day),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Divider(),
                      ...dayEntries.map((entry) {
                        return ListTile(
                          // ⬇️===== YEH HAI FIX (Typo Hata Diya) =====⬇️
                          title: Text(entry.subjectName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          // ⬆️========================================⬆️
                          subtitle: Text(
                            '${entry.startTime.format(context)} - ${entry.endTime.format(context)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deleteEntry(entry),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
