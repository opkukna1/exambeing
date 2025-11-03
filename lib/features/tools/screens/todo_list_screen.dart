import 'package.flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Date formatting ke liye

// Task ka model
class Task {
  final String id;
  final String title;
  bool isDone;
  final DateTime date; // Task kis din ka hai

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.date,
  });

  // Firebase se data lene ke liye
  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      isDone: data['isDone'] ?? false,
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  // Firebase mein data bhejne ke liye
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'isDone': isDone,
      'date': Timestamp.fromDate(date),
      'userId': FirebaseAuth.instance.currentUser?.uid, // Taki user sirf apne task dekhe
    };
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late DateTime _selectedDay; // User ne kaun sa din chuna hai
  late DateTime _focusedDay; // Calendar kaun sa mahina dikha raha hai
  final TextEditingController _taskController = TextEditingController();
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // User ke tasks ka reference
  CollectionReference get _tasksCollection {
    // Har user ka alag 'tasks' collection (users/{userId}/tasks)
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('tasks');
  }

  // Naya task add karne ka function
  Future<void> _addTask() async {
    final String title = _taskController.text.trim();
    if (title.isEmpty) return; // Khaali task add na karein

    // Naya task object banayein
    final newTask = Task(
      id: '', // ID Firebase dega
      title: title,
      date: _selectedDay, // Chune gaye din ke liye
    );

    // Firebase mein add karein
    try {
      await _tasksCollection.add(newTask.toFirestore());
      _taskController.clear(); // Text field saaf karein
      if (mounted) Navigator.pop(context); // Dialog band karein
    } catch (e) {
      debugPrint("Error adding task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add task.')),
        );
      }
    }
  }

  // Task ko done/undone karne ka function
  Future<void> _toggleTaskStatus(Task task) async {
    try {
      await _tasksCollection.doc(task.id).update({'isDone': !task.isDone});
    } catch (e) {
      debugPrint("Error updating task: $e");
    }
  }

  // Task delete karne ka function
  Future<void> _deleteTask(Task task) async {
    try {
      await _tasksCollection.doc(task.id).delete();
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
  }

  // Naya task add karne ka dialog
  void _showAddTaskDialog() {
    _taskController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('New Task for ${DateFormat.yMMMd().format(_selectedDay)}'),
          content: TextField(
            controller: _taskController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Task title'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: _addTask,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      // Agar user login nahi hai (haalaanki aisa nahi hona chahiye)
      return Scaffold(
        appBar: AppBar(title: const Text('To-Do List')),
        body: const Center(child: Text('Please log in to use To-Do List.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Date-wise To-Do List'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Calendar Widget
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2040, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week, // Sirf hafta dikhayein
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // Focus bhi update karein
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // Mahina badalne par focus update
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false, // 'Week'/'Month' button hatao
            ),
          ),
          const Divider(height: 1),

          // Chune gaye din ke tasks ki list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Firebase se chune gaye din ke tasks laao
              stream: _tasksCollection
                  .where('date', isEqualTo: Timestamp.fromDate(_selectedDay))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks for ${DateFormat.yMMMd().format(_selectedDay)}.\nAdd one!',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Tasks ko list mein badlo
                final tasks = snapshot.data!.docs
                    .map((doc) => Task.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      child: ListTile(
                        // Checkbox
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (value) => _toggleTaskStatus(task),
                        ),
                        // Task ka title
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: task.isDone ? Colors.grey : null,
                          ),
                        ),
                        // Delete button
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteTask(task),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
