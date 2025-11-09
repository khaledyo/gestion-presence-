import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

// Couleurs modernes
const Color primaryColor = Color(0xFF6366F1);
const Color backgroundColor = Color(0xFFF8FAFC);
const Color surfaceColor = Colors.white;
const Color successColor = Color(0xFF10B981);
const Color errorColor = Color(0xFFEF4444);
const Color warningColor = Color(0xFFF59E0B);
const Color textPrimary = Color(0xFF1F2937);
const Color textSecondary = Color(0xFF6B7280);

// Enum pour gérer les états de session
enum SessionStatus {
  loading,
  beforeClass,
  duringClass,
  afterClass,
}

class Student {
  final String uid;
  final String fullName;
  final String studentIdentifier;

  Student({
    required this.uid,
    required this.fullName,
    required this.studentIdentifier,
  });
}

class AttendanceList extends StatefulWidget {
  final Map<String, dynamic> classData;
  final String classId;

  const AttendanceList({
    Key? key,
    required this.classData,
    required this.classId,
  }) : super(key: key);

  @override
  State<AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends State<AttendanceList> {
  List<Student> enrolledStudents = [];
  Map<String, bool> attendanceStatus = {};
  String? sessionId;
  bool isLoading = true;
  bool isSessionClosed = false;
  String searchQuery = '';
  Timer? _sessionTimer;
  int _remainingTime = 0;
  SessionStatus _sessionStatus = SessionStatus.loading;

  // Durée de validité du QR code fixée à 15 minutes
  final int _qrCodeDuration = 15 * 60; // 15 minutes en secondes

  @override
  void initState() {
    super.initState();
    _initializeAttendanceSession();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAttendanceSession() async {
    try {
      setState(() {
        _sessionStatus = SessionStatus.loading;
        isLoading = true;
      });

      // Charger les étudiants en premier
      await _loadStudents();

      // Vérifier l'horaire du cours et l'état de la session
      await _checkClassScheduleAndSession();

    } catch (e) {
      print("Erreur d'initialisation: $e");
      _showSnackBar("Erreur d'initialisation: $e", errorColor);
      setState(() {
        isLoading = false;
        _sessionStatus = SessionStatus.afterClass;
      });
    }
  }

  Future<void> _checkClassScheduleAndSession() async {
    final now = DateTime.now();

    // Récupérer les données de la classe
    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .get();

    if (!classDoc.exists) {
      throw Exception('Classe non trouvée');
    }

    final classData = classDoc.data() ?? {};

    // Vérifier s'il existe une session de présence active
    final existingSessionId = classData['attendanceSessionId'] as String?;

    if (existingSessionId != null) {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(existingSessionId)
          .get();

      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data()!;
        final isClosed = sessionData['isClosed'] ?? false;
        final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

        if (!isClosed && expiresAt != null && now.isBefore(expiresAt)) {
          // Session active trouvée - la réutiliser
          sessionId = existingSessionId;
          _remainingTime = expiresAt.difference(now).inSeconds;
          _sessionStatus = SessionStatus.duringClass;
          _startSessionTimer();

          // Charger les présences existantes
          _loadExistingAttendance(sessionData);

          setState(() {
            isLoading = false;
          });
          return;
        } else if (!isClosed && expiresAt != null && now.isAfter(expiresAt)) {
          // Session expirée - sauvegarder et fermer
          await _saveToHistoryAndCloseSession(existingSessionId);
        }
      }
    }

    // Vérifier l'horaire du cours pour créer une nouvelle session si nécessaire
    await _checkClassTiming(classData);
  }

  void _loadExistingAttendance(Map<String, dynamic> sessionData) {
    final presentUids = List<String>.from(sessionData['presentStudentsUid'] ?? []);

    for (var student in enrolledStudents) {
      if (presentUids.contains(student.uid)) {
        attendanceStatus[student.uid] = true;
      }
    }

    setState(() {});
  }

  Future<void> _checkClassTiming(Map<String, dynamic> classData) async {
    final now = DateTime.now();

    DateTime? dateDebut;
    DateTime? dateFin;

    // Récupérer les dates de début et fin
    if (classData['dateDebut'] != null && classData['dateFin'] != null) {
      dateDebut = (classData['dateDebut'] as Timestamp).toDate();
      dateFin = (classData['dateFin'] as Timestamp).toDate();
    } else if (classData['jour'] != null && classData['horaireDebut'] != null && classData['horaireFin'] != null) {
      try {
        final jour = DateFormat('dd/MM/yyyy').parse(classData['jour']);
        final debutParts = (classData['horaireDebut'] as String).split(':');
        final finParts = (classData['horaireFin'] as String).split(':');

        if (debutParts.length == 2 && finParts.length == 2) {
          dateDebut = DateTime(
              jour.year, jour.month, jour.day,
              int.parse(debutParts[0]), int.parse(debutParts[1])
          );
          dateFin = DateTime(
              jour.year, jour.month, jour.day,
              int.parse(finParts[0]), int.parse(finParts[1])
          );
        }
      } catch (e) {
        print('Erreur parsing horaire: $e');
      }
    }

    SessionStatus newStatus = SessionStatus.afterClass;
    int newRemainingTime = 0;

    if (dateDebut != null && dateFin != null) {
      if (now.isBefore(dateDebut)) {
        // Avant le cours
        newStatus = SessionStatus.beforeClass;
        newRemainingTime = dateDebut.difference(now).inSeconds;
        _startPreSessionTimer();
      } else if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
        // Pendant le cours - VÉRIFIER SI UNE SESSION A DÉJÀ EU LIEU PENDANT CETTE PLAGE HORAIRE
        final todaySessionHappened = classData['todaySessionHappened'] as bool? ?? false;
        final lastSessionDate = (classData['lastSessionDate'] as Timestamp?)?.toDate();

        // Vérifier si la dernière session était pendant la même plage horaire aujourd'hui
        final isSameTimeSlot = lastSessionDate != null &&
            _isSameDay(lastSessionDate, now) &&
            _isDuringClassTime(lastSessionDate, dateDebut, dateFin);

        if (todaySessionHappened && isSameTimeSlot) {
          // Une session a déjà eu lieu pendant cette plage horaire aujourd'hui - AFFICHER L'HISTORIQUE
          newStatus = SessionStatus.afterClass;
          _showSnackBar('Session de présence déjà terminée pour ce cours - Voir l\'historique', Colors.blue);
        } else {
          // Aucune session pendant cette plage horaire aujourd'hui - créer une nouvelle session
          newStatus = SessionStatus.duringClass;
          await _createNewSession();
          return;
        }
      } else {
        // Après le cours
        newStatus = SessionStatus.afterClass;
      }
    } else {
      // Pas d'heures définies
      newStatus = SessionStatus.afterClass;
    }

    setState(() {
      _sessionStatus = newStatus;
      _remainingTime = newRemainingTime;
      isLoading = false;
    });
  }

  // Méthode utilitaire pour vérifier si deux dates sont le même jour
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Méthode utilitaire pour vérifier si une date est pendant les heures de cours
  bool _isDuringClassTime(DateTime dateToCheck, DateTime classStart, DateTime classEnd) {
    return dateToCheck.isAfter(classStart) && dateToCheck.isBefore(classEnd);
  }

  Future<void> _createNewSession() async {
    try {
      final newSessionId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();
      final sessionEnd = now.add(Duration(seconds: _qrCodeDuration));

      // Créer la session dans Firestore
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(newSessionId)
          .set({
        'classId': widget.classId,
        'className': widget.classData['nom'],
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(sessionEnd),
        'presentStudentsUid': [],
        'isClosed': false,
        'sessionCode': _generateSessionCode(),
      });

      // Mettre à jour la classe avec la nouvelle session
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': newSessionId,
        // Ne pas marquer comme terminée tant que la session n'est pas finie
      });

      // Mettre à jour l'état local
      setState(() {
        sessionId = newSessionId;
        _remainingTime = _qrCodeDuration;
        isSessionClosed = false;
        _sessionStatus = SessionStatus.duringClass;
        isLoading = false;
      });

      _startSessionTimer();

      _showSnackBar('QR Code activé pour 15 minutes', successColor);

    } catch (e) {
      print("Erreur création session: $e");
      _showSnackBar("Erreur création session: $e", errorColor);

      setState(() {
        isLoading = false;
        _sessionStatus = SessionStatus.afterClass;
        sessionId = null;
      });
    }
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _autoSaveAndCloseSession();
        timer.cancel();
      }
    });
  }

  void _startPreSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        // Le cours commence maintenant - créer une session
        _createNewSession();
        timer.cancel();
      }
    });
  }

  Future<void> _autoSaveAndCloseSession() async {
    if (sessionId != null && !isSessionClosed) {
      await _saveToHistoryAndCloseSession(sessionId!);
      _showSnackBar('Présences sauvegardées automatiquement', successColor);
    }
  }

  Future<void> _saveToHistoryAndCloseSession(String sessionIdToClose) async {
    try {
      // 1. Sauvegarder dans l'historique
      await _saveToHistory();

      // 2. Fermer la session
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionIdToClose)
          .update({
        'isClosed': true,
        'closedAt': Timestamp.now(),
        'autoClosed': true,
      });

      // 3. Supprimer la référence de session ET marquer comme terminée pour cette plage horaire
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': FieldValue.delete(),
        'todaySessionHappened': true,
        'lastSessionDate': Timestamp.now(),
      });

      setState(() {
        isSessionClosed = true;
        sessionId = null;
        _sessionStatus = SessionStatus.afterClass;
      });

      _sessionTimer?.cancel();

    } catch (e) {
      print("Erreur sauvegarde automatique: $e");
      _showSnackBar("Erreur sauvegarde automatique", errorColor);
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final presentStudents = enrolledStudents
          .where((student) => attendanceStatus[student.uid] ?? false)
          .toList();

      final absentStudents = enrolledStudents
          .where((student) => !(attendanceStatus[student.uid] ?? false))
          .toList();

      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      final classData = classDoc.data() ?? {};

      final historyData = {
        'classId': widget.classId,
        'className': widget.classData['nom'] ?? 'Séance sans nom',
        'date': Timestamp.now(),
        'startTime': widget.classData['horaireDebut'] ?? 'Non spécifié',
        'endTime': widget.classData['horaireFin'] ?? 'Non spécifié',
        'schoolClass': widget.classData['schoolClass'] ?? 'Classe non spécifiée',
        'teacherUid': classData['enseignantUid'] ?? widget.classData['enseignantUid'] ?? 'unknown',
        'teacherName': classData['enseignantName'] ?? widget.classData['enseignantName'] ?? 'Enseignant',
        'createdAt': Timestamp.now(),
        'sessionDuration': 15,
        'totalStudents': enrolledStudents.length,
        'presentCount': presentStudents.length,
        'absentCount': absentStudents.length,
        'presentStudents': presentStudents.map((student) => {
          'uid': student.uid,
          'name': student.fullName,
          'identifier': student.studentIdentifier
        }).toList(),
        'absentStudents': absentStudents.map((student) => {
          'uid': student.uid,
          'name': student.fullName,
          'identifier': student.studentIdentifier
        }).toList(),
      };

      await FirebaseFirestore.instance
          .collection('attendance_history')
          .add(historyData);

      print('✅ Historique sauvegardé automatiquement');

    } catch (e) {
      print('❌ Erreur sauvegarde historique: $e');
    }
  }

  Future<void> _loadStudents() async {
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      final List<String> studentUids =
      List<String>.from(classDoc.data()?['studentsUid'] ?? []);

      final fetchedStudents = <Student>[];

      if (studentUids.isNotEmpty) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: studentUids)
            .get();

        fetchedStudents.addAll(studentsSnapshot.docs.map((doc) {
          final data = doc.data();
          return Student(
            uid: doc.id,
            fullName: data['nom'] ?? 'Nom Inconnu',
            studentIdentifier: data['email'] ?? '',
          );
        }).toList());
      }

      setState(() {
        enrolledStudents = fetchedStudents;
        attendanceStatus = {
          for (var s in fetchedStudents) s.uid: false,
        };
      });
    } catch (e) {
      print("Erreur chargement étudiants: $e");
      setState(() {
        enrolledStudents = [];
        attendanceStatus = {};
      });
    }
  }

  Stream<DocumentSnapshot> getAttendanceStream() {
    if (sessionId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('attendances')
        .doc(sessionId)
        .snapshots();
  }

  void _toggleStudent(String uid, bool status) {
    if (isSessionClosed) return;

    setState(() {
      attendanceStatus[uid] = status;
    });

    // Sauvegarder automatiquement dans la session en temps réel
    if (sessionId != null) {
      _updateAttendanceInFirestore();
    }
  }

  Future<void> _updateAttendanceInFirestore() async {
    try {
      final presentStudents = attendanceStatus.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionId)
          .update({
        'presentStudentsUid': presentStudents,
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print("Erreur mise à jour présence: $e");
    }
  }

  List<Student> get filteredStudents {
    final query = searchQuery.toLowerCase();
    return enrolledStudents.where((student) {
      return student.fullName.toLowerCase().contains(query) ||
          student.studentIdentifier.toLowerCase().contains(query);
    }).toList();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  String _getStatusMessage() {
    switch (_sessionStatus) {
      case SessionStatus.beforeClass:
        return 'Le cours commence dans ${_formatTime(_remainingTime)}';
      case SessionStatus.duringClass:
        return 'QR Code actif - Expire dans: ${_formatTime(_remainingTime)}';
      case SessionStatus.afterClass:
        return 'Session terminée - Présences sauvegardées';
      case SessionStatus.loading:
        return 'Chargement...';
      default:
        return 'État inconnu';
    }
  }

  IconData _getStatusIcon() {
    switch (_sessionStatus) {
      case SessionStatus.beforeClass:
        return Icons.schedule_rounded;
      case SessionStatus.duringClass:
        return Icons.play_lesson_rounded;
      case SessionStatus.afterClass:
        return Icons.done_all_rounded;
      case SessionStatus.loading:
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getStatusColor() {
    switch (_sessionStatus) {
      case SessionStatus.beforeClass:
        return warningColor;
      case SessionStatus.duringClass:
        return successColor;
      case SessionStatus.afterClass:
        return Colors.blue;
      case SessionStatus.loading:
        return textSecondary;
      default:
        return textSecondary;
    }
  }

  bool get _canShowQRCode {
    return sessionId != null &&
        sessionId!.isNotEmpty &&
        !isSessionClosed &&
        _remainingTime > 0 &&
        _sessionStatus == SessionStatus.duringClass;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.classData['nom'] ?? 'Session de présence',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          if (_sessionStatus == SessionStatus.duringClass && !isSessionClosed)
            IconButton(
              icon: Icon(Icons.info_outline_rounded),
              onPressed: () {
                _showSnackBar('Les présences se sauvegardent automatiquement', primaryColor);
              },
              tooltip: 'Sauvegarde automatique',
            ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : StreamBuilder<DocumentSnapshot>(
        stream: getAttendanceStream(),
        builder: (context, snapshot) {
          if (sessionId != null && snapshot.hasData) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final expiresAt = data['expiresAt'] as Timestamp?;

            if (expiresAt != null) {
              final calculatedRemainingTime = _calculateRemainingTime(expiresAt);
              if (calculatedRemainingTime != _remainingTime) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _remainingTime = calculatedRemainingTime;
                  });
                });
              }

              if (calculatedRemainingTime <= 0 && !isSessionClosed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _autoSaveAndCloseSession();
                });
              }
            }
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final presentUids = List<String>.from(data['presentStudentsUid'] ?? []);
          final isClosed = data['isClosed'] ?? false;

          // Mettre à jour l'état local avec les données Firestore
          for (var s in enrolledStudents) {
            if (presentUids.contains(s.uid)) {
              attendanceStatus[s.uid] = true;
            }
          }

          final presentCount = attendanceStatus.values.where((v) => v).length;
          final absentCount = enrolledStudents.length - presentCount;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(presentCount, absentCount),
                const SizedBox(height: 8),
                _buildStatusSection(),
                if (_canShowQRCode) ...[
                  const SizedBox(height: 8),
                  _buildQrCodeSection(),
                ],
                const SizedBox(height: 8),
                _buildSearchBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildStudentList(isClosed),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _calculateRemainingTime(Timestamp expiresAt) {
    final now = DateTime.now();
    final expiration = expiresAt.toDate();
    return expiration.difference(now).inSeconds;
  }

  Widget _buildStatusSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(), size: 20, color: _getStatusColor()),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getStatusMessage(),
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (_sessionStatus == SessionStatus.duringClass)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_mode_rounded, size: 12, color: successColor),
                  const SizedBox(width: 4),
                  Text(
                    'Auto',
                    style: TextStyle(
                      color: successColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_rounded, color: primaryColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'QR Code de présence',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: QrImageView(
              data: sessionId ?? '',
              size: 200,
              version: QrVersions.auto,
              foregroundColor: primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Durée: 15 minutes • Sauvegarde automatique',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chargement...',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int presentCount, int absentCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Classe : ${widget.classData['nom']}",
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Présents', presentCount, successColor, Icons.check_circle_rounded),
              _buildStatItem('Absents', absentCount, errorColor, Icons.cancel_rounded),
              _buildStatItem('Total', enrolledStudents.length, primaryColor, Icons.people_rounded),
            ],
          ),
          if (_sessionStatus == SessionStatus.afterClass)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Présences sauvegardées dans l\'historique',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
          hintText: 'Rechercher un étudiant...',
          hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onChanged: (val) => setState(() => searchQuery = val),
      ),
    );
  }

  Widget _buildStudentList(bool isClosed) {
    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 6),
            Text(
              'Aucun étudiant trouvé',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredStudents.length,
      itemBuilder: (context, index) {
        final student = filteredStudents[index];
        final isPresent = attendanceStatus[student.uid] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
            elevation: 1,
            child: ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPresent ? successColor.withOpacity(0.1) : errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPresent ? Icons.check_rounded : Icons.close_rounded,
                  color: isPresent ? successColor : errorColor,
                  size: 14,
                ),
              ),
              title: Text(
                student.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontSize: 12,
                ),
              ),
              subtitle: Text(
                student.studentIdentifier,
                style: TextStyle(color: textSecondary, fontSize: 10),
              ),
              trailing: !isClosed ? _buildAttendanceBadge(student.uid, isPresent) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minLeadingWidth: 0,
              dense: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceBadge(String uid, bool isPresent) {
    return GestureDetector(
      onTap: () => _toggleStudent(uid, !isPresent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isPresent ? successColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPresent ? successColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          isPresent ? 'Présent' : 'Absent',
          style: TextStyle(
            color: isPresent ? Colors.white : textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}