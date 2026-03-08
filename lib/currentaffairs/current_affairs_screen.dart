import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../services/current_affairs_service.dart'; 
import 'quiz_screen.dart'; // 👈 Quiz screen ko import karna mat bhoolna

class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedRegion = "Rajasthan";
  String _selectedLanguage = "Hindi";
  
  bool _isLoading = false;
  String _newsContent = "";
  
  final CurrentAffairsService _newsService = CurrentAffairsService();

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _newsContent = "";
    });

    String result = await _newsService.getDailyCurrentAffairs(
      date: _selectedDate,
      region: _selectedRegion,
      language: _selectedLanguage,
    );

    setState(() {
      _newsContent = result;
      _isLoading = false;
    });
  }

  // --- AI TEST GENERATION LOGIC ---
  Future<void> _startAITest() async {
    // 1. Loading Dialog dikhao
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFF9800)),
              SizedBox(height: 15),
              Text("AI is creating 10 MCQs...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("Analyzing Sujas & PIB facts", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );

    try {
      // 2. Service se questions mangwao
      List<dynamic> testQuestions = await _newsService.getOrGenerateDailyTest(
        date: _selectedDate,
        region: _selectedRegion,
        language: _selectedLanguage,
        newsContent: _newsContent,
      );

      // 3. Loading band karo
      if (mounted) Navigator.pop(context);

      // 4. Test start karo
      if (testQuestions.isNotEmpty && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              questions: testQuestions,
              title: "${_selectedRegion} Quiz - ${DateFormat('dd MMM').format(_selectedDate)}",
            ),
          ),
        );
      } else {
        throw "No questions generated";
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Error aane par bhi loader hatao
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Oops! Test nahi ban paya. Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1), 
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF5E35B1), onPrimary: Colors.white, onSurface: Colors.black87),
          ),
          child: child!,
        ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchNews(); 
    }
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelect) {
    bool isSelected = value == currentValue;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          onSelect(value);
          _fetchNews();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)]) : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black54)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Current Affairs', style: TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF5E35B1)]),
          ),
        ),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1BEE7))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF5E35B1)),
                        Text(DateFormat('dd MMMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))),
                        const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: Color(0xFF5E35B1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildFilterChip("Raj", "Rajasthan", _selectedRegion, (val) => setState(() => _selectedRegion = val)),
                        const SizedBox(width: 8),
                        _buildFilterChip("India", "India", _selectedRegion, (val) => setState(() => _selectedRegion = val)),
                      ],
                    ),
                    Row(
                      children: [
                        _buildFilterChip("अ", "Hindi", _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                        const SizedBox(width: 8),
                        _buildFilterChip("A", "English", _selectedLanguage, (val) => setState(() => _selectedLanguage = val)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E35B1)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: MarkdownBody(
                        data: _newsContent,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF2D3142)),
                          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          strong: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4527A0)),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: !_isLoading && _newsContent.isNotEmpty && !_newsContent.contains("🚨")
          ? FloatingActionButton.extended(
              onPressed: _startAITest, // 👈 Naya function connect kar diya
              backgroundColor: const Color(0xFFFF9800),
              icon: const Icon(Icons.rocket_launch, color: Colors.white),
              label: const Text("Attempt AI Test", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
