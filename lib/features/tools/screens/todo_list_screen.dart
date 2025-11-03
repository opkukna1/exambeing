import 'package:flutter/material.dart'; // ✅ FIX: 'Import' ko 'import' kar diya
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // Date formatting ke liye
import 'package:exambeing/helpers/database_helper.dart'; // Firebase ki jagah local DB helper

// (Internal Task class hata di gayi, ab hum 'database_helper.dart' waali Task class use karenge)

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  final TextEditingController _taskController = TextEditingController();
  
  late Future<List<Task>> _tasksFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<List<Task>> _loadTasksForSelectedDay(DateTime date) {
    return dbHelper.getTasksByDate(date);
  }

  Future<void> _addTask() async {
    final String title = _taskController.text.trim();
    if (title.isEmpty) return;

    final newTask = Task(
      title: title,
      date: _selectedDay,
      isDone: false,
    );

    try {
      await dbHelper.createTask(newTask);
      _taskController.clear();
      if (mounted) Navigator.pop(context);
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

  Future<void> _toggleTaskStatus(Task task) async {
    try {
      await dbHelper.updateTaskStatus(task.id!, !task.isDone);
      setState(() {
        _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
      });
    } catch (e) {
      debugPrint("Error updating task: $e");
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await dbHelper.deleteTask(task.id!);
      setState(() {
        _tasksFuture = _loadTasksForSelectedDay(_selectedDay);
      });
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
  }

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

          // Chune gaye din ke tasks ki list
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { // Ab 'ConnectionState' mil jaayega
                  return const Center(child: CircularProgressIndicator()); // Ab 'Center' mil jaayega
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}')); // Ab 'Text' mil jaayega
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No tasks for ${DateFormat.yMMMd().format(_selectedDay)}.\nAdd one!',
                      textAlign: TextAlign.center, // Ab 'TextAlign' mil jaayega
                    ),
                  );
                }

                final tasks = snapshot.data!;

                return ListView.builder( // Ab 'ListView' mil jaayega
                  padding: const EdgeInsets.all(8.0),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card( // Ab 'Card' mil jaayega
                      child: ListTile( // Ab 'ListTile' mil jaayega
                        leading: Checkbox( // Ab 'Checkbox' mil jaayega
                          value: task.isDone,
                          onChanged: (value) => _toggleTaskStatus(task),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle( // Ab 'TextStyle' mil jaayega
                            decoration: task.isDone
                                ? TextDecoration.lineThrough // Ab 'TextDecoration' mil jaayega
                                : TextDecoration.none,
                            color: task.isDone ? Colors.grey : null, // Ab 'Colors' mil jaayega
                          ),
                        ),
                        trailing: IconButton( // Ab 'IconButton' mil jaayega
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
