import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
// Yahan apne hisaab se path adjust kar lena
import '../services/current_affairs_service.dart'; 

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1), 
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5E35B1), // Deep Purple
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchNews(); 
    }
  }

  // --- PREMIUM CHIP WIDGET ---
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
          gradient: isSelected 
              ? const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)])
              : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
          boxShadow: isSelected 
              ? [BoxShadow(color: const Color(0xFF5E35B1).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Ekdum soft background
      appBar: AppBar(
        title: const Text('Current Affairs', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4527A0), Color(0xFF5E35B1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- TOP MODERN FILTER SECTION ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                // Date Picker (Modern Button)
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5), // Light purple background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1BEE7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: Color(0xFF5E35B1)),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4527A0)),
                        ),
                        const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: Color(0xFF5E35B1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Chips for Region & Language
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

          // --- CONTENT DISPLAY SECTION (Modern Card) ---
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF5E35B1)),
                        SizedBox(height: 20),
                        Text("Reading Sujas & PIB...", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 80), // Bottom padding for FAB
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: const [
                          BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 10)),
                        ],
                      ),
                      child: MarkdownBody(
                        data: _newsContent,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF2D3142)),
                          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E1E1E), height: 1.3),
                          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5E35B1)),
                          h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                          strong: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4527A0)),
                          listBullet: const TextStyle(color: Color(0xFFFF9800), fontSize: 18), // Orange bullets
                          blockquoteDecoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            border: const Border(left: BorderSide(color: Color(0xFFFF9800), width: 4)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          blockquote: const TextStyle(color: Color(0xFFE65100), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      
      // --- PREMIUM FLOATING ACTION BUTTON ---
      floatingActionButton: !_isLoading && _newsContent.isNotEmpty && !_newsContent.contains("Error") && !_newsContent.contains("🚨")
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("AI Test Generator Starting...", style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0xFF4527A0),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              elevation: 4,
              backgroundColor: const Color(0xFFFF9800), // Action Orange
              icon: const Icon(Icons.rocket_launch, color: Colors.white),
              label: const Text("Attempt AI Test", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
