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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, dynamic>> _studentData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadStudentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    try {
      // Gestion des types mixtes : Strings et Maps
      final presentStudents = _extractStudentIds(widget.historyData['presentStudents'] ?? []);
      final absentStudents = _extractStudentIds(widget.historyData['absentStudents'] ?? []);
      final allStudentIds = {...presentStudents, ...absentStudents};

      final Map<String, Map<String, dynamic>> studentData = {};

      for (final studentId in allStudentIds) {
        if (studentId.isNotEmpty) {
          final userDoc = await _firestore.collection('users').doc(studentId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>?;
            if (userData != null) {
              studentData[studentId] = {
                'name': userData['nom'] ?? 'Nom inconnu',
                'email': userData['email'] ?? '',
                'profilePicture': userData['profilePicture'] ?? '',
                'identifier': userData['identifier'] ?? '',
              };
            }
          }
        }
      }

      setState(() {
        _studentData = studentData;
      });
    } catch (e) {
      print('Erreur chargement données étudiants: $e');
    }
  }

  // Méthode pour extraire les IDs d'étudiants quel que soit le type
  List<String> _extractStudentIds(dynamic studentsField) {
    if (studentsField is List) {
      final List studentList = studentsField;
      final List<String> ids = [];

      for (final item in studentList) {
        if (item is String) {
          // Cas 1: Liste de Strings (UIDs)
          ids.add(item);
        } else if (item is Map<String, dynamic>) {
          // Cas 2: Liste de Maps avec un champ 'uid'
          final uid = item['uid'] ?? item['id'];
          if (uid is String) {
            ids.add(uid);
          }
        }
      }
      return ids;
    }
    return [];
  }

  Map<String, dynamic>? _getStudentData(String studentId) {
    return _studentData[studentId];
  }

  @override
  Widget build(BuildContext context) {
    final historyData = widget.historyData;

    // Utiliser la méthode d'extraction pour gérer les types mixtes
    final presentStudentIds = _extractStudentIds(historyData['presentStudents'] ?? []);
    final absentStudentIds = _extractStudentIds(historyData['absentStudents'] ?? []);

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

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              _buildHeader(historyData, date, presentCount, totalStudents, percentage),
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                Text('Présents (${presentStudentIds.length})'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 14),
                                const SizedBox(width: 6),
                                Text('Absents (${absentStudentIds.length})'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _tabController.index == 0
                          ? _buildStudentListAsColumn(presentStudentIds, true)
                          : _buildStudentListAsColumn(absentStudentIds, false),
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

  Widget _buildStudentListAsColumn(
      List<String> studentIds, bool isPresent) {
    if (studentIds.isEmpty) {
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: studentIds.length,
      itemBuilder: (context, index) {
        final studentId = studentIds[index];
        final studentData = _getStudentData(studentId);

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: _buildStudentAvatar(studentData?['profilePicture'], isPresent),
            title: Text(
              studentData?['name'] ?? 'Chargement...',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
            ),
            subtitle: Text(
              studentData?['email'] ?? studentData?['identifier'] ?? studentId,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPresent
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPresent
                      ? const Color(0xFF10B981).withOpacity(0.3)
                      : const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Text(
                isPresent ? 'Présent' : 'Absent',
                style: TextStyle(
                  color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentAvatar(String? photoUrl, bool isPresent) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: isPresent
            ? const Color(0xFF10B981).withOpacity(0.1)
            : const Color(0xFFEF4444).withOpacity(0.1),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback vers l'avatar par défaut en cas d'erreur
        },
      );
    } else {
      // Avatar par défaut avec icône
      return CircleAvatar(
        backgroundColor: isPresent
            ? const Color(0xFF10B981).withOpacity(0.2)
            : const Color(0xFFEF4444).withOpacity(0.2),
        child: Icon(
          isPresent ? Icons.person_rounded : Icons.person_outline_rounded,
          color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          size: 18,
        ),
      );
    }
  }
}