import 'dart:async'; // Timer ke liye zaroori
import 'package:flutter/material.dart';

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  static const int _workDuration = 25 * 60; // 25 minutes in seconds
  static const int _shortBreakDuration = 5 * 60; // 5 minutes in seconds
  static const int _longBreakDuration = 15 * 60; // 15 minutes in seconds

  Timer? _timer;
  int _remainingSeconds = _workDuration;
  String _currentMode = 'Work'; // 'Work', 'Short Break', 'Long Break'
  bool _isRunning = false;
  int _pomodoroCount = 0;

  @override
  void dispose() {
    _timer?.cancel(); // Screen band hone par timer ko band karo
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return; // Pehle se chal raha hai to kuchh na karo

    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // Time poora ho gaya
        _timer?.cancel();
        setState(() => _isRunning = false);
        _playNotificationSound(); // (Future feature: yahaan sound baja sakte hain)
        _switchMode(); // Agle mode par jaao
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      // Current mode ke hisaab se time reset karo
      if (_currentMode == 'Work') {
        _remainingSeconds = _workDuration;
      } else if (_currentMode == 'Short Break') {
        _remainingSeconds = _shortBreakDuration;
      } else {
        _remainingSeconds = _longBreakDuration;
      }
    });
  }

  void _switchMode() {
    setState(() {
      if (_currentMode == 'Work') {
        _pomodoroCount++;
        // Har 4 pomodoro ke baad lamba break
        if (_pomodoroCount % 4 == 0) {
          _currentMode = 'Long Break';
          _remainingSeconds = _longBreakDuration;
        } else {
          _currentMode = 'Short Break';
          _remainingSeconds = _shortBreakDuration;
        }
      } else {
        // Break khatam, kaam par vaapas
        _currentMode = 'Work';
        _remainingSeconds = _workDuration;
      }
    });
    // Naya mode shuru hone par automatic start kar sakte hain
    _startTimer();
  }

  void _playNotificationSound() {
    // TODO: Yahaan par 'assets_audio_player' ya 'soundpool' package se
    // ek 'ding' sound baja sakte hain taaki user ko pata chale time khatam.
    debugPrint('Timer finished!');
  }

  // Seconds ko "MM:SS" format mein badalna
  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor;
    final String statusText;

    if (_currentMode == 'Work') {
      backgroundColor = theme.colorScheme.primaryContainer;
      statusText = 'Time to focus!';
    } else {
      backgroundColor = Colors.green.shade100;
      statusText = 'Time for a break!';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        color: backgroundColor, // Mode ke hisaab se background color badlega
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status (Work/Break)
              Text(
                _currentMode,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                statusText,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 40),

              // Timer Clock
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _formatTime(_remainingSeconds),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset Button
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    iconSize: 32,
                    onPressed: _resetTimer,
                    tooltip: 'Reset',
                  ),
                  const SizedBox(width: 20),

                  // Start/Pause Button (Main Button)
                  FloatingActionButton.large(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    child: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Skip Button
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    iconSize: 32,
                    onPressed: () {
                       _timer?.cancel();
                       _switchMode(); // Agle mode par skip karo
                    },
                    tooltip: 'Skip',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Pomodoro Count
              Text(
                'Pomodoros completed: $_pomodoroCount',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
