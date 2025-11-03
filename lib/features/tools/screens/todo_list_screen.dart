import 'package.flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // Date formatting ke liye
import 'package:exambeing/helpers/database_helper.dart'; // ⬇️ Firebase ki jagah local DB helper

// ❌ (Firebase imports hata diye gaye)
// ❌ (Internal Task class hata di gayi, ab hum 'database_helper.dart' waali Task class use karenge)

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  final TextEditingController _taskController = TextEditingController();
  
  // ⬇️===== NAYE STATE VARIABLES (FutureBuilder Ke Liye) =====⬇️
  late Future<List<Task>> _tasksFuture;
  final dbHelper = DatabaseHelper.instance;
  // ⬆️=======================================================⬆️

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    // Screen load hote hi chune gaye din ke tasks load karo
    _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // ⬇️===== NAYA FUNCTION (Local DB Se Task Load Karna) =====⬇️
  Future<List<Task>> _loadTasksForSelectedDay(DateTime date) {
    // DatabaseHelper se us din ke tasks maango
    return dbHelper.getTasksByDate(date);
  }
  // ⬆️=======================================================⬆️

  // ⬇️===== FUNCTION UPDATED (Local DB Mein Add Karna) =====⬇️
  Future<void> _addTask() async {
    final String title = _taskController.text.trim();
    if (title.isEmpty) return;

    final newTask = Task(
      title: title,
      date: _selectedDay,
      isDone: false,
    );

    try {
      await dbHelper.createTask(newTask); // Local DB mein create karo
      _taskController.clear();
      if (mounted) Navigator.pop(context);
      // List ko refresh karo
      setState(() {
        _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
      });
    } catch (e) {
      debugPrint("Error adding task: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add task.')),
        );
      }
    }
  }
  // ⬆️=======================================================⬆️

  // ⬇️===== FUNCTION UPDATED (Local DB Mein Update Karna) =====⬇️
  Future<void> _toggleTaskStatus(Task task) async {
    try {
      // Local DB mein update karo
      await dbHelper.updateTaskStatus(task.id!, !task.isDone);
      // List ko refresh karo
      setState(() {
        _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
      });
    } catch (e) {
      debugPrint("Error updating task: $e");
    }
  }
  // ⬆️=======================================================⬆️

  // ⬇️===== FUNCTION UPDATED (Local DB Se Delete Karna) =====⬇️
  Future<void> _deleteTask(Task task) async {
    try {
      await dbHelper.deleteTask(task.id!); // Local DB se delete karo
      // List ko refresh karo
      setState(() {
        _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
      });
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
  }
  // ⬆️=======================================================⬆️

  // Naya task add karne ka dialog (Yeh waisa hi hai)
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
              onPressed: _addTask, // Yeh naya _addTask function call karega
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ❌ (User null check hata diya, kyonki local DB ke liye zaroori nahi)
    
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
            calendarFormat: CalendarFormat.week,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                // ⬇️ Naya din chuna, list refresh karo ⬇️
                _tasksFuture = _loadTasksForSelectedDay(selectedDay);
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
          ),
          const Divider(height: 1),

          // ⬇️===== STREAMBUILDER KO FUTUREBUILDER SE BADLA GAYA =====⬇️
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _tasksFuture, // Future variable ka istemal
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
                      'No tasks for ${DateFormat.yMMMd().format(_selectedDay)}.\nAdd one!',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Ab 'snapshot.data' seedha List<Task> hai
                final tasks = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (value) => _toggleTaskStatus(task),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: task.isDone ? Colors.grey : null,
                          ),
                        ),
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
          // ⬆️========================================================⬆️
        ],
      ),
    );
  }
}
