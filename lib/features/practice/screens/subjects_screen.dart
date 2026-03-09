import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/subject_model.dart';
import '../../../services/firebase_data_service.dart';

class SubjectsScreen extends StatefulWidget {
  final Map<String, String> seriesData;
  const SubjectsScreen({super.key, required this.seriesData});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final FirebaseDataService dataService = FirebaseDataService();
  late Future<List<Subject>> _subjectsFuture;
  late String seriesName;

  @override
  void initState() {
    super.initState();
    final seriesId = widget.seriesData['seriesId']!;
    seriesName = widget.seriesData['seriesName']!;
    _subjectsFuture = dataService.getSubjects(seriesId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Modern off-white background
      appBar: AppBar(
        title: Text(seriesName, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4527A0), Color(0xFF5E35B1)], // Premium Deep Purple Gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Subject>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5E35B1)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text('Oops! Something went wrong.', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, color: Colors.grey.shade300, size: 80),
                  const SizedBox(height: 16),
                  Text('No subjects found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final subjects = snapshot.data!;
          
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            itemCount: subjects.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85, // Adjusted for perfect modern card height
            ),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return _buildSubjectCard(context, subject, seriesName);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildSubjectCard(BuildContext context, Subject subject, String seriesName) {
    return GestureDetector(
      onTap: () {
        final subjectData = {
          'subjectId': subject.id,
          'subjectName': subject.name,
        };
        context.push('/topics', extra: subjectData);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000), // Very soft shadow
              blurRadius: 15,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative Background Circle
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5E35B1).withOpacity(0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Series Name Tag (Pill shape)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5E35B1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      seriesName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5E35B1),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Icon
                  const Icon(Icons.import_contacts_rounded, color: Color(0xFFFF9800), size: 28), // Orange accent icon
                  const SizedBox(height: 10),
                  
                  // Subject Name
                  Expanded(
                    child: Text(
                      subject.name,
                      style: const TextStyle(
                        color: Color(0xFF2D3142),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Subtitle
                  Text(
                    'Topics | Tests',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Bottom Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Start Now", 
                        style: TextStyle(
                          color: Color(0xFF5E35B1), 
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E57C2), Color(0xFF5E35B1)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
