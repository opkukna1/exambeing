import 'dart:typed_data';
import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart'; // ✅ FIX: Removed unused import
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:exambeing/models/schedule_model.dart';    // ✅ FIX: Using package import
import 'package:exambeing/models/subject_model.dart';       // ✅ FIX: Using package import
import 'package:exambeing/services/firebase_data_service.dart'; // ✅ FIX: Using package import

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final FirebaseDataService _dataService = FirebaseDataService();
  late Future<List<Schedule>> _schedulesFuture;
  late Future<List<Subject>> _subjectsFuture;
  String _currentFilterTitle = 'Latest Schedules';

  @override
  void initState() {
    super.initState();
    _schedulesFuture = _dataService.getSchedules();
    _subjectsFuture = _dataService.getAllSubjects();
  }

  Future<void> _refreshData() async {
    setState(() {
      _schedulesFuture = _dataService.getSchedules(subjectId: _selectedSubjectId);
      _subjectsFuture = _dataService.getAllSubjects();
    });
  }
  
  String? _selectedSubjectId;

  void _applyFilter({Subject? subject}) {
    setState(() {
      if (subject == null) {
        _currentFilterTitle = 'Latest Schedules';
        _selectedSubjectId = null;
        _schedulesFuture = _dataService.getSchedules();
      } else {
        _currentFilterTitle = subject.name;
        _selectedSubjectId = subject.id;
        _schedulesFuture = _dataService.getSchedules(subjectId: subject.id);
      }
    });
  }
  
  void _showFilterSheet(List<Subject> subjects) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Filter by Subject', style: Theme.of(context).textTheme.titleLarge),
              ),
              const Divider(),
              ListTile(
                title: const Text('All Schedules', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _applyFilter();
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    final subject = subjects[index];
                    return ListTile(
                      title: Text(subject.name),
                      onTap: () {
                        Navigator.pop(context);
                        _applyFilter(subject: subject);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentFilterTitle),
        actions: [
          FutureBuilder<List<Subject>>(
            future: _subjectsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const IconButton(icon: Icon(Icons.filter_list_off), onPressed: null);
              }
              final subjects = snapshot.data!;
              return IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter by Subject',
                onPressed: () => _showFilterSheet(subjects),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<Schedule>>(
          future: _schedulesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No schedule posted.')));
            }
            final schedules = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: schedules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final schedule = schedules[index];
                final screenshotController = ScreenshotController();
                return _buildScheduleCard(context, schedule, screenshotController);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, Schedule schedule, ScreenshotController controller) {
    return Screenshot(
      controller: controller,
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareCardAsImage(context, controller),
                    tooltip: 'Share as Image',
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                schedule.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareCardAsImage(BuildContext context, ScreenshotController controller) async {
    final Uint8List? image = await controller.capture(pixelRatio: 2.0);
    if (image == null || !mounted) return;
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/schedule.png').writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath.path)], text: "Check out this schedule!");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing image: $e')));
      }
    }
  }
}
