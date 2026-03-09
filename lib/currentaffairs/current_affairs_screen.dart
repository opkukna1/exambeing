import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:printing/printing.dart'; 
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../services/current_affairs_service.dart';
import 'quiz_screen.dart'; 

class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Shared States
  String _selectedRegion = "Rajasthan";
  String _selectedLanguage = "Hindi";
  
  // Daily States
  DateTime _selectedDailyDate = DateTime.now();
  bool _isDailyLoading = false;
  String _dailyNewsContent = "";
  
  // Monthly States
  DateTime _selectedMonthlyDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isMonthlyLoading = false;
  String _monthlyContent = "";

  final CurrentAffairsService _newsService = CurrentAffairsService();

  // 🔥 ADMIN CHECK LOGIC 🔥
  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && user.email == "opsiddh42@gmail.com";
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchDailyNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔥 FIX: Tab change hone par Button update hoga 🔥
  void _handleTabSelection() {
    if (_tabController.indexIsChanging || !_tabController.indexIsChanging) {
      if (mounted) setState(() {}); // Isse Attempt Test wala button turant update ho jayega!
      if (_tabController.index == 1 && _monthlyContent.isEmpty) {
        _fetchMonthlyMagazine(forceUpdate: false);
      }
    }
  }

  // ==================== DAILY LOGIC ====================
  Future<void> _fetchDailyNews() async {
    setState(() { _isDailyLoading = true; _dailyNewsContent = ""; });
    String result = await _newsService.getDailyCurrentAffairs(
      date: _selectedDailyDate, region: _selectedRegion, language: _selectedLanguage,
    );
    if (mounted) setState(() { _dailyNewsContent = result; _isDailyLoading = false; });
  }

  Future<void> _startDailyTest() async {
    _showLoadingOverlay("AI is creating 10 MCQs...");
    try {
      List<dynamic> testQuestions = await _newsService.getOrGenerateDailyTest(
        date: _selectedDailyDate, region: _selectedRegion, language: _selectedLanguage, newsContent: _dailyNewsContent,
      );
      if (mounted) Navigator.pop(context);
      if (testQuestions.isNotEmpty && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
          questions: testQuestions, title: "Daily Quiz - ${DateFormat('dd MMM').format(_selectedDailyDate)}",
        )));
      } else throw "No questions generated";
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Test generation failed: $e");
    }
  }

  // ==================== MONTHLY LOGIC ====================
  Future<void> _fetchMonthlyMagazine({bool forceUpdate = false}) async {
    setState(() { _isMonthlyLoading = true; _monthlyContent = ""; });
    String result = await _newsService.getMonthlyCompilation(
      monthDate: _selectedMonthlyDate, region: _selectedRegion, language: _selectedLanguage,
      isAdmin: isAdmin, forceUpdate: forceUpdate,
    );
    if (mounted) setState(() { _monthlyContent = result; _isMonthlyLoading = false; });
  }

  Future<void> _startMonthlyTest() async {
    _showLoadingOverlay("Generating Mega Test (50 Qs)... This may take 30s.");
    try {
      List<dynamic> testQuestions = await _newsService.getOrGenerateMonthlyTest(
        monthDate: _selectedMonthlyDate, region: _selectedRegion, language: _selectedLanguage, monthlyContent: _monthlyContent,
      );
      if (mounted) Navigator.pop(context);
      if (testQuestions.isNotEmpty && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(
          questions: testQuestions, title: "Mega Mock - ${DateFormat('MMM yyyy').format(_selectedMonthlyDate)}",
        )));
      } else throw "Mega test generation failed";
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Mega Test failed: $e");
    }
  }

  // ==================== PDF EXPORT LOGIC ====================
  Future<void> _downloadDailyPdf() async {
    _showLoadingOverlay("Preparing Premium PDF Layout...");
    try {
      String htmlContent = await _newsService.getOrGenerateDailyHtml(
        date: _selectedDailyDate, region: _selectedRegion, language: _selectedLanguage, markdownContent: _dailyNewsContent,
      );
      if (mounted) Navigator.pop(context); 
      await Printing.layoutPdf(
        name: 'Exambeing_Daily_${DateFormat('dd_MMM').format(_selectedDailyDate)}',
        onLayout: (PdfPageFormat format) async {
          return await Printing.convertHtml(format: format, html: '<html><body style="font-family: sans-serif; padding:20px;">$htmlContent<br><br><center><small>Generated by Exambeing App</small></center></body></html>');
        },
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("PDF Error: $e");
    }
  }

  Future<void> _downloadMonthlyPdf({bool forceUpdateHtml = false}) async {
    _showLoadingOverlay(forceUpdateHtml ? "Updating PDF Layout..." : "Preparing Mega PDF...");
    try {
      String htmlContent = await _newsService.getOrGenerateMonthlyHtml(
        monthDate: _selectedMonthlyDate, region: _selectedRegion, language: _selectedLanguage, markdownContent: _monthlyContent, forceUpdate: forceUpdateHtml,
      );
      if (mounted) Navigator.pop(context); 
      if (!forceUpdateHtml) {
        await Printing.layoutPdf(
          name: 'Exambeing_Magazine_${DateFormat('MMM_yyyy').format(_selectedMonthlyDate)}',
          onLayout: (PdfPageFormat format) async {
            return await Printing.convertHtml(format: format, html: '<html><body style="font-family: sans-serif; padding:20px;">$htmlContent<br><br><center><small>Generated by Exambeing App</small></center></body></html>');
          },
        );
      } else {
        _showErrorSnackBar("HTML PDF Layout Updated Successfully! ✅");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("PDF Error: $e");
    }
  }

  // 🔥 NEW: FULL SCREEN READER MODE 🔥
  void _openFullScreen(String content, String title) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          backgroundColor: const Color(0xFF5E35B1),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
          child: MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 18, height: 1.7, color: Color(0xFF2D3142)), // Font thoda bada reading ke liye
              h1: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E1E1E)),
              h2: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5E35B1)),
              strong: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4527A0)),
              listBullet: const TextStyle(color: Color(0xFFFF9800), fontSize: 20),
              blockquoteDecoration: BoxDecoration(color: const Color(0xFFFFF3E0), border: const Border(left: BorderSide(color: Color(0xFFFF9800), width: 4)), borderRadius: BorderRadius.circular(4)),
              blockquote: const TextStyle(color: Color(0xFFE65100), fontStyle: FontStyle.italic),
            ),
          ),
        ),
      );
    }));
  }

  // ==================== UI HELPERS ====================
  void _showLoadingOverlay(String msg) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFFFF9800)), const SizedBox(height: 15),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _selectMonthYear(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedMonthlyDate, firstDate: DateTime(2024, 1), lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year, 
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF5E35B1), onPrimary: Colors.white)), child: child!),
    );
    if (picked != null) {
      setState(() { _selectedMonthlyDate = DateTime(picked.year, picked.month, 1); });
      _fetchMonthlyMagazine(forceUpdate: false);
    }
  }

  Future<void> _selectDailyDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDailyDate, firstDate: DateTime(2024, 1), lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF5E35B1), onPrimary: Colors.white)), child: child!),
    );
    if (picked != null && picked != _selectedDailyDate) {
      setState(() => _selectedDailyDate = picked);
      _fetchDailyNews();
    }
  }

  void _onFilterChanged() {
    if (_tabController.index == 0) _fetchDailyNews();
    else _fetchMonthlyMagazine(forceUpdate: false);
  }

  Widget _buildFilterChip(String label, String value, String currentValue, Function(String) onSelect) {
    bool isSelected = value == currentValue;
    return GestureDetector(
      onTap: () { if (!isSelected) { onSelect(value); _onFilterChanged(); } },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(gradient: isSelected ? const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF7E57C2)]) : null, color: isSelected ? null : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? Colors.white : Colors.black54)),
      ),
    );
  }

  Widget _buildDateSelector(String label, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1BEE7))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(icon, color: const Color(0xFF5E35B1)), Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))), const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: Color(0xFF5E35B1))]),
      ),
    );
  }

  Widget _buildMarkdownView(String content, bool isLoading, String loadingMsg) {
    if (isLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: Color(0xFF5E35B1)), const SizedBox(height: 20), Text(loadingMsg, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 16))]));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 90),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 10))]),
        child: MarkdownBody(
          data: content, selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 16, height: 1.7, color: Color(0xFF2D3142)),
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E1E1E)),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF5E35B1)),
            strong: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4527A0)),
            listBullet: const TextStyle(color: Color(0xFFFF9800), fontSize: 18),
            blockquoteDecoration: BoxDecoration(color: const Color(0xFFFFF3E0), border: const Border(left: BorderSide(color: Color(0xFFFF9800), width: 4)), borderRadius: BorderRadius.circular(4)),
            blockquote: const TextStyle(color: Color(0xFFE65100), fontStyle: FontStyle.italic),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Current Affairs', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4527A0), Color(0xFF5E35B1)]))),
        foregroundColor: Colors.white, centerTitle: true, elevation: 0,
        bottom: TabBar(
          controller: _tabController, indicatorColor: Colors.orangeAccent, indicatorWeight: 4, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: "Daily Updates"), Tab(text: "Monthly Magazine")],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 15), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 8))]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [ _buildFilterChip("Raj", "Rajasthan", _selectedRegion, (val) => setState(() => _selectedRegion = val)), const SizedBox(width: 8), _buildFilterChip("India", "India", _selectedRegion, (val) => setState(() => _selectedRegion = val))]),
                Row(children: [ _buildFilterChip("अ", "Hindi", _selectedLanguage, (val) => setState(() => _selectedLanguage = val)), const SizedBox(width: 8), _buildFilterChip("A", "English", _selectedLanguage, (val) => setState(() => _selectedLanguage = val))]),
              ],
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ==================== TAB 1: DAILY ====================
                Column(
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(20, 15, 20, 5), child: _buildDateSelector(DateFormat('dd MMMM yyyy').format(_selectedDailyDate), () => _selectDailyDate(context), Icons.calendar_month_rounded)),
                    
                    if (_dailyNewsContent.isNotEmpty && !_isDailyLoading && !_dailyNewsContent.contains("🚨"))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _openFullScreen(_dailyNewsContent, "Daily News - ${DateFormat('dd MMM').format(_selectedDailyDate)}"),
                              icon: const Icon(Icons.fullscreen, color: Color(0xFF5E35B1), size: 18),
                              label: const Text("Full Screen", style: TextStyle(color: Color(0xFF5E35B1))),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF5E35B1))),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _downloadDailyPdf, 
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18), label: const Text("PDF"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    Expanded(child: _buildMarkdownView(_dailyNewsContent, _isDailyLoading, "Reading Sujas & PIB...")),
                  ],
                ),
                
                // ==================== TAB 2: MONTHLY ====================
                Column(
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(20, 15, 20, 5), child: _buildDateSelector(DateFormat('MMMM yyyy').format(_selectedMonthlyDate), () => _selectMonthYear(context), Icons.auto_stories)),
                    
                    if (_monthlyContent != "NOT_PUBLISHED" && _monthlyContent.isNotEmpty && !_isMonthlyLoading && !_monthlyContent.contains("🚨"))
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Row(
                               children: [
                                 OutlinedButton.icon(
                                   onPressed: () => _openFullScreen(_monthlyContent, "Magazine - ${DateFormat('MMM yyyy').format(_selectedMonthlyDate)}"),
                                   icon: const Icon(Icons.fullscreen, color: Color(0xFF5E35B1), size: 18),
                                   label: const Text("Full Screen", style: TextStyle(color: Color(0xFF5E35B1))),
                                   style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF5E35B1))),
                                 ),
                                 const SizedBox(width: 10),
                                 ElevatedButton.icon(
                                   onPressed: _downloadMonthlyPdf, 
                                   icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 18), label: const Text("PDF"),
                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                 ),
                               ],
                             ),
                             if (isAdmin)
                               PopupMenuButton<String>(
                                 onSelected: (value) {
                                   if (value == 'update_text') _fetchMonthlyMagazine(forceUpdate: true);
                                   if (value == 'update_pdf') _downloadMonthlyPdf(forceUpdateHtml: true);
                                 },
                                 itemBuilder: (context) => [
                                   const PopupMenuItem(value: 'update_text', child: Text("Update Magazine Text")),
                                   const PopupMenuItem(value: 'update_pdf', child: Text("Update PDF Layout")),
                                 ],
                                 child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.settings, size: 18)])),
                               ),
                           ],
                         ),
                       ),
                    Expanded(
                      child: _isMonthlyLoading 
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E35B1))) 
                        : _monthlyContent == "NOT_PUBLISHED"
                          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 50, color: Colors.grey.shade400), const SizedBox(height: 10), const Text("Magazine not published yet.", style: TextStyle(color: Colors.grey, fontSize: 16)), if (isAdmin) const SizedBox(height: 20), if (isAdmin) ElevatedButton.icon(onPressed: () => _fetchMonthlyMagazine(forceUpdate: true), icon: const Icon(Icons.publish), label: const Text("Admin: Publish Now"))]))
                          : _buildMarkdownView(_monthlyContent, false, ""),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      
      floatingActionButton: _tabController.index == 0
          ? (!_isDailyLoading && _dailyNewsContent.isNotEmpty && !_dailyNewsContent.contains("🚨") ? FloatingActionButton.extended(onPressed: _startDailyTest, backgroundColor: const Color(0xFFFF9800), elevation: 4, icon: const Icon(Icons.rocket_launch, color: Colors.white), label: const Text("Attempt Daily Quiz", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))) : null)
          : (!_isMonthlyLoading && _monthlyContent.isNotEmpty && _monthlyContent != "NOT_PUBLISHED" && !_monthlyContent.contains("🚨") ? FloatingActionButton.extended(onPressed: _startMonthlyTest, backgroundColor: const Color(0xFFD32F2F), elevation: 4, icon: const Icon(Icons.workspace_premium, color: Colors.white), label: const Text("Attempt Mega Mock (50 Q)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))) : null),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
