// lib/pages/student/history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentHistoryPage extends StatefulWidget {
  final String userUid;
  final String userName;

  const StudentHistoryPage({
    Key? key,
    required this.userUid,
    required this.userName,
  }) : super(key: key);

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<String, Map<String, dynamic>> _subjectStats = {};

  // Couleurs modernes avec dégradés 3D
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color secondaryDark = Color(0xFF7C3AED);
  static const Color accentColor = Color(0xFF06B6D4);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardGradientStart = Color(0xFFFFFFFF);
  static const Color cardGradientEnd = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color successColor = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Récupérer l'historique des présences où l'étudiant est présent
      final historySnapshot = await _firestore
          .collection('attendance_history')
          .where('presentStudents', arrayContains: widget.userUid)
          .orderBy('createdAt', descending: true)
          .get();

      // Récupérer aussi les sessions où l'étudiant est absent
      final allHistorySnapshot = await _firestore
          .collection('attendance_history')
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> allHistory = [];

      for (final doc in allHistorySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final presentStudents = List<String>.from(data['presentStudents'] ?? []);
        final absentStudents = List<String>.from(data['absentStudents'] ?? []);

        final isPresent = presentStudents.contains(widget.userUid);
        final isAbsent = absentStudents.contains(widget.userUid);

        if (isPresent || isAbsent) {
          allHistory.add({
            ...data,
            'id': doc.id,
            'studentStatus': isPresent ? 'present' : 'absent',
          });
        }
      }

      // Calculer les statistiques par matière
      _calculateSubjectStats(allHistory);

      setState(() {
        _attendanceHistory = allHistory;
        _isLoading = false;
      });

    } catch (e) {
      print('Erreur chargement historique: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateSubjectStats(List<Map<String, dynamic>> history) {
    final Map<String, Map<String, dynamic>> stats = {};

    for (final session in history) {
      final subjectName = session['className'] ?? 'Séance sans nom';
      final isPresent = session['studentStatus'] == 'present';

      if (!stats.containsKey(subjectName)) {
        stats[subjectName] = {
          'totalSessions': 0,
          'presentSessions': 0,
          'absentSessions': 0,
          'attendanceRate': 0.0,
          'sessions': [],
        };
      }

      final subjectStat = stats[subjectName]!;
      subjectStat['totalSessions'] = (subjectStat['totalSessions'] as int) + 1;

      if (isPresent) {
        subjectStat['presentSessions'] = (subjectStat['presentSessions'] as int) + 1;
      } else {
        subjectStat['absentSessions'] = (subjectStat['absentSessions'] as int) + 1;
      }

      // Calculer le taux de présence
      final total = subjectStat['totalSessions'] as int;
      final present = subjectStat['presentSessions'] as int;
      subjectStat['attendanceRate'] = total > 0 ? (present / total * 100) : 0.0;

      // Ajouter la session à l'historique de la matière
      (subjectStat['sessions'] as List).add(session);
    }

    setState(() {
      _subjectStats = stats;
    });
  }

  Color _getAttendanceRateColor(double rate) {
    if (rate >= 80) return successColor;
    if (rate >= 60) return warningColor;
    return errorColor;
  }

  Color _getAttendanceRateDarkColor(double rate) {
    if (rate >= 80) return successDark;
    if (rate >= 60) return warningDark;
    return errorDark;
  }

  String _getAttendanceStatus(double rate) {
    if (rate >= 80) return 'Excellent';
    if (rate >= 60) return 'Satisfaisant';
    if (rate >= 40) return 'À améliorer';
    return 'Critique';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de votre historique...',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Récupération de vos données de présence',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardGradientStart, cardGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.1), secondaryColor.withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.history_toggle_off_rounded, size: 56, color: primaryColor),
                ),
                const SizedBox(height: 28),
                Text(
                  'Aucun historique de présence',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Vos présences apparaîtront ici après avoir scanné des QR Codes en cours',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Scanner un QR Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectStats() {
    if (_subjectStats.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Statistiques par matière',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        ..._subjectStats.entries.map((entry) {
          final subjectName = entry.key;
          final stats = entry.value;
          final totalSessions = stats['totalSessions'] as int;
          final presentSessions = stats['presentSessions'] as int;
          final absentSessions = stats['absentSessions'] as int;
          final attendanceRate = stats['attendanceRate'] as double;

          return _buildSubjectCard(
            subjectName,
            totalSessions,
            presentSessions,
            absentSessions,
            attendanceRate,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSubjectCard(
      String subjectName,
      int totalSessions,
      int presentSessions,
      int absentSessions,
      double attendanceRate,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardGradientStart, cardGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$totalSessions séance${totalSessions > 1 ? 's' : ''} au total',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getAttendanceRateColor(attendanceRate),
                        _getAttendanceRateDarkColor(attendanceRate),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getAttendanceRateColor(attendanceRate).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    '${attendanceRate.round()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Barre de progression avec label
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Taux de présence',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _getAttendanceStatus(attendanceRate),
                      style: TextStyle(
                        fontSize: 13,
                        color: _getAttendanceRateColor(attendanceRate),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: attendanceRate / 100,
                      backgroundColor: Colors.transparent,
                      color: _getAttendanceRateColor(attendanceRate),
                      minHeight: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.check_circle_rounded, '$presentSessions', 'Présences', successColor, successDark),
                _buildStatItem(Icons.cancel_rounded, '$absentSessions', 'Absences', errorColor, errorDark),
                _buildStatItem(Icons.emoji_events_rounded, _getAttendanceStatus(attendanceRate), 'Statut',
                    _getAttendanceRateColor(attendanceRate), _getAttendanceRateDarkColor(attendanceRate)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color, Color darkColor) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, darkColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Historique détaillé',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
        ..._attendanceHistory.map((session) => _buildSessionCard(session)).toList(),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isPresent = session['studentStatus'] == 'present';
    final date = (session['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    final className = session['className'] ?? 'Séance sans nom';
    final schoolClass = session['schoolClass'] ?? 'Classe non spécifiée';
    final startTime = session['startTime'] ?? '';
    final endTime = session['endTime'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardGradientStart, cardGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: isPresent
                        ? LinearGradient(
                      colors: [successColor, successDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : LinearGradient(
                      colors: [errorColor, errorDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isPresent ? successColor : errorColor).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPresent ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        schoolClass,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(date)} • $startTime - $endTime',
                        style: TextStyle(
                          color: textSecondary.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPresent
                          ? [successColor, successDark]
                          : [errorColor, errorDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isPresent ? successColor : errorColor).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    isPresent ? 'Présent' : 'Absent',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Mon historique',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            fontSize: 20,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _loadAttendanceHistory,
              icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _attendanceHistory.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadAttendanceHistory,
        color: primaryColor,
        backgroundColor: surfaceColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec statistiques globales
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(Icons.bar_chart_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vue d\'ensemble',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_attendanceHistory.length} séance${_attendanceHistory.length > 1 ? 's' : ''} enregistrée${_attendanceHistory.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Statistiques globales
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildGlobalStat(
                          'Séances totales',
                          _attendanceHistory.length.toString(),
                          Icons.calendar_today_rounded,
                          Colors.white,
                        ),
                        _buildGlobalStat(
                          'Présences',
                          _attendanceHistory.where((s) => s['studentStatus'] == 'present').length.toString(),
                          Icons.check_circle_rounded,
                          Colors.white,
                        ),
                        _buildGlobalStat(
                          'Absences',
                          _attendanceHistory.where((s) => s['studentStatus'] == 'absent').length.toString(),
                          Icons.cancel_rounded,
                          Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Statistiques par matière
              _buildSubjectStats(),
              const SizedBox(height: 20),
              // Historique détaillé
              _buildSessionHistory(),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalStat(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}