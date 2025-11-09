import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryDetailsPage extends StatefulWidget {
  final Map<String, dynamic> historyData;
  final String historyId;

  const HistoryDetailsPage({
    Key? key,
    required this.historyData,
    required this.historyId,
  }) : super(key: key);

  @override
  State<HistoryDetailsPage> createState() => _HistoryDetailsPageState();
}

class _HistoryDetailsPageState extends State<HistoryDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Optionnel: écouter les changements si nécessaire
    _tabController.addListener(() {
      if (mounted) setState(() {}); // rebuild to show correct tab content
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyData = widget.historyData;
    final presentStudents =
    List<Map<String, dynamic>>.from(historyData['presentStudents'] ?? []);
    final absentStudents =
    List<Map<String, dynamic>>.from(historyData['absentStudents'] ?? []);

    final date = (historyData['date'] as Timestamp).toDate();
    final presentCount = historyData['presentCount'] ?? 0;
    final totalStudents = historyData['totalStudents'] ?? 0;
    final percentage = totalStudents > 0
        ? (presentCount / totalStudents * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Détails de la séance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        centerTitle: false,
      ),

      // Scroll global unique
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // header compact
              _buildHeader(historyData, date, presentCount, totalStudents, percentage),

              const SizedBox(height: 10),

              // onglets + contenu (tout dans le même scroll)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF6B7280),
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14),
                                const SizedBox(width: 6),
                                Text('Présents (${presentStudents.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 14),
                                const SizedBox(width: 6),
                                Text('Absents (${absentStudents.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Contenu de l'onglet affiché inline — utilise AnimatedSwitcher pour une transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _tabController.index == 0
                          ? _buildStudentListAsColumn(presentStudents, true)
                          : _buildStudentListAsColumn(absentStudents, false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // header
  Widget _buildHeader(Map<String, dynamic> data, DateTime date,
      int presentCount, int totalStudents, int percentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['className'] ?? 'Séance',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Séance du ${DateFormat('dd/MM/yyyy').format(date)}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.school_rounded, 'Classe',
                    data['schoolClass'] ?? 'Non spécifiée'),
                _buildInfoRow(Icons.access_time_rounded, 'Horaire',
                    '${data['startTime']} - ${data['endTime']}'),
                _buildInfoRow(Icons.person_rounded, 'Enseignant',
                    data['teacherName'] ?? 'Inconnu'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Statistiques de présence',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCircle('Présents', (historyData()['presentCount'] ?? 0), Colors.white,
                    Icons.check_circle_rounded),
                _buildStatCircle('Absents', (historyData()['totalStudents'] ?? 0) - (historyData()['presentCount'] ?? 0),
                    Colors.white, Icons.cancel_rounded),
                _buildStatCircle('Total', (historyData()['totalStudents'] ?? 0), Colors.white, Icons.people_rounded),
                _buildStatCircle('Taux', totalPercentage(), Colors.white, Icons.percent_rounded, suffix: '%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // helpers to safely read historyData inside header (since build already extracted some)
  Map<String, dynamic> historyData() => widget.historyData;
  int totalPercentage() {
    final presentCount = widget.historyData['presentCount'] ?? 0;
    final totalStudents = widget.historyData['totalStudents'] ?? 0;
    return totalStudents > 0 ? (presentCount / totalStudents * 100).round() : 0;
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(String title, int value, Color color, IconData icon,
      {String suffix = ''}) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text('$value$suffix',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(title,
            style: TextStyle(
                fontSize: 10, color: color.withOpacity(0.8), height: 1.2)),
      ],
    );
  }

  // version that uses a shrinkWrapped ListView (so performance remains good for long lists)
  Widget _buildStudentListAsColumn(
      List<Map<String, dynamic>> students, bool isPresent) {
    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text("Aucun étudiant trouvé",
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // important: pas de scroll interne
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              child: Icon(
                isPresent ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
              ),
            ),
            title: Text(
              student['name'] ?? 'Nom inconnu',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            subtitle: Text(
              student['identifier'] ?? '',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            trailing: Text(
              isPresent ? 'Présent' : 'Absent',
              style: TextStyle(
                color: isPresent
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
