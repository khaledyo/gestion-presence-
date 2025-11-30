import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

// Couleurs modernes avec dégradés
const Color primaryColor = Color(0xFF6366F1);
const Color primaryDark = Color(0xFF4F46E5);
const Color primaryLight = Color(0xFF818CF8);
const Color backgroundColor = Color(0xFFF8FAFC);
const Color surfaceColor = Color(0xFFFFFFFF);
const Color successColor = Color(0xFF10B981);
const Color successDark = Color(0xFF059669);
const Color errorColor = Color(0xFFEF4444);
const Color warningColor = Color(0xFFF59E0B);
const Color textPrimary = Color(0xFF1F2937);
const Color textSecondary = Color(0xFF6B7280);
const Color cardShadowColor = Color(0x0A000000);

// Dégradés modernes
const LinearGradient primaryGradient = LinearGradient(
  colors: [primaryColor, primaryDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient successGradient = LinearGradient(
  colors: [successColor, successDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient cardGradient = LinearGradient(
  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Enum pour gérer les états de session
enum SessionStatus {
  loading,
  beforeClass,
  duringClass,
  afterClass,
  qrCodeActive,
  teacherAbsent,
  classCanceled,
}

class Student {
  final String uid;
  final String fullName;
  final String studentIdentifier;
  final String? photoUrl;

  Student({
    required this.uid,
    required this.fullName,
    required this.studentIdentifier,
    this.photoUrl,
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
  Timer? _syncTimer;
  int _remainingTime = 0;
  SessionStatus _sessionStatus = SessionStatus.loading;
  bool _canStartQRSession = false;
  bool _hasSessionHappenedInThisTimeSlot = false;

  final int _qrCodeDuration = 15 * 60;

  @override
  void initState() {
    super.initState();
    _initializeAttendanceSession();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeAttendanceSession() async {
    try {
      setState(() {
        _sessionStatus = SessionStatus.loading;
        isLoading = true;
      });

      await _loadStudents();
      _resetAttendanceState();
      _hasSessionHappenedInThisTimeSlot = await _hasSessionAlreadyHappenedInThisTimeSlot();
      await _checkClassScheduleAndSession();
      _startSyncTimer();

    } catch (e) {
      print("Erreur d'initialisation: $e");
      _showSnackBar("Erreur d'initialisation: $e", errorColor);
      setState(() {
        isLoading = false;
        _sessionStatus = SessionStatus.afterClass;
      });
    }
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (sessionId != null && !isSessionClosed) {
        _syncSessionTime();
      }
    });
  }

  Future<void> _syncSessionTime() async {
    if (sessionId == null) return;

    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionId!)
          .get();

      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data()!;
        final expiresAt = sessionData['expiresAt'] as Timestamp;

        setState(() {
          _remainingTime = _calculateRemainingTime(expiresAt);
        });
      }
    } catch (e) {
      print('Erreur synchronisation temps: $e');
    }
  }

  Future<void> _checkClassScheduleAndSession() async {
    final now = DateTime.now();

    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .get();

    if (!classDoc.exists) {
      throw Exception('Classe non trouvée');
    }

    final classData = classDoc.data() ?? {};
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
          sessionId = existingSessionId;
          _remainingTime = _calculateRemainingTime(sessionData['expiresAt'] as Timestamp);
          _sessionStatus = SessionStatus.qrCodeActive;
          _startSessionTimer();
          _loadExistingAttendance(sessionData);

          setState(() {
            isLoading = false;
            _canStartQRSession = false;
          });
          return;
        } else if (!isClosed && expiresAt != null && now.isAfter(expiresAt)) {
          await _saveToHistoryAndCloseSession(existingSessionId);
        }
      }
    }

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

  Future<bool> _hasSessionAlreadyHappenedInThisTimeSlot() async {
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) return false;

      final classData = classDoc.data()!;
      final sessionCompletedForTimeSlot = classData['sessionCompletedForTimeSlot'] ?? false;

      final lastSessionHoraire = classData['lastSessionHoraire'] as String?;
      final currentHoraire = widget.classData['horaireDebut'] as String?;

      final lastSessionDate = classData['lastSessionDate'] as Timestamp?;
      final today = DateTime.now();

      if (lastSessionDate != null && lastSessionHoraire != null && currentHoraire != null) {
        final lastSession = lastSessionDate.toDate();

        final isSameDay = lastSession.year == today.year &&
            lastSession.month == today.month &&
            lastSession.day == today.day;

        final isSameTimeSlot = lastSessionHoraire == currentHoraire;

        if (isSameDay && isSameTimeSlot) {
          return true;
        } else {
          _resetAttendanceState();
          return false;
        }
      }

      return false;
    } catch (e) {
      print("Erreur vérification session précédente: $e");
      return false;
    }
  }

  void _resetAttendanceState() {
    setState(() {
      attendanceStatus = {
        for (var student in enrolledStudents) student.uid: false,
      };
      _hasSessionHappenedInThisTimeSlot = false;
      sessionId = null;
      isSessionClosed = false;
    });
    print("🔄 État de présence réinitialisé pour nouveau créneau horaire");
  }

  Future<void> _checkClassTiming(Map<String, dynamic> classData) async {
    final now = DateTime.now();
    DateTime? dateDebut;
    DateTime? dateFin;

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
    bool canStartQR = false;

    final currentHoraire = widget.classData['horaireDebut'] as String?;
    final lastSessionHoraire = classData['lastSessionHoraire'] as String?;

    if (currentHoraire != null && lastSessionHoraire != null && currentHoraire != lastSessionHoraire) {
      _resetAttendanceState();
    }

    if (_hasSessionHappenedInThisTimeSlot) {
      newStatus = SessionStatus.afterClass;
      canStartQR = false;
    }
    else if (dateDebut != null && dateFin != null) {
      final isBeforeClass = now.isBefore(dateDebut);
      final isDuringClass = now.isAfter(dateDebut) && now.isBefore(dateFin);
      final isAfterClass = now.isAfter(dateFin);

      if (isBeforeClass) {
        newStatus = SessionStatus.beforeClass;
        newRemainingTime = dateDebut.difference(now).inSeconds;
        _startPreSessionTimer();
      } else if (isDuringClass) {
        newStatus = SessionStatus.duringClass;
        canStartQR = sessionId == null;
      } else if (isAfterClass) {
        final isCanceled = classData['isCanceled'] ?? false;

        if (isCanceled) {
          newStatus = SessionStatus.classCanceled;
        } else if (!_hasSessionHappenedInThisTimeSlot && sessionId == null) {
          newStatus = SessionStatus.teacherAbsent;
          _notifyStudentsAboutTeacherAbsence(classData);
        } else {
          newStatus = SessionStatus.afterClass;
        }
      }
    } else {
      newStatus = SessionStatus.afterClass;
    }

    setState(() {
      _sessionStatus = newStatus;
      _remainingTime = newRemainingTime;
      _canStartQRSession = canStartQR;
      isLoading = false;
    });
  }

  Future<void> _notifyStudentsAboutTeacherAbsence(Map<String, dynamic> classData) async {
    try {
      final classId = widget.classId;
      final today = DateTime.now().toIso8601String().split('T')[0];
      final notificationKey = 'absence_notification_${classId}_$today';

      final prefs = await SharedPreferences.getInstance();
      final alreadyNotified = prefs.getBool(notificationKey) ?? false;

      if (alreadyNotified) return;

      final className = classData['nom'] ?? 'Séance sans nom';
      final teacherName = classData['enseignantName'] ?? 'Le professeur';
      final startTime = classData['horaireDebut'] ?? '';
      final endTime = classData['horaireFin'] ?? '';
      final studentsUid = List<String>.from(classData['studentsUid'] ?? []);

      if (studentsUid.isEmpty) return;

      final notificationData = {
        'type': 'teacher_absence',
        'classId': classId,
        'className': className,
        'teacherName': teacherName,
        'teacherUid': widget.classData['enseignantUid'],
        'date': Timestamp.now(),
        'timeSlot': '$startTime - $endTime',
        'message': '$teacherName était absent pour le cours "$className"',
        'forStudents': studentsUid,
        'isRead': {},
        'createdAt': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('notifications').add(notificationData);
      await prefs.setBool(notificationKey, true);

    } catch (e) {
      print('❌ Erreur envoi notification absence: $e');
    }
  }

  Future<void> _startQRSession() async {
    if (_hasSessionHappenedInThisTimeSlot) {
      _showSnackBar('Une session a déjà été effectuée pour ce créneau horaire aujourd\'hui', warningColor);
      return;
    }

    if (!_canStartQRSession || sessionId != null) {
      _showSnackBar('Une session est déjà active', warningColor);
      return;
    }

    try {
      final newSessionId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();
      final sessionEnd = now.add(Duration(minutes: 15));

      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      final sessionCompletedForTimeSlot = classDoc.data()?['sessionCompletedForTimeSlot'] ?? false;
      final lastSessionHoraire = classDoc.data()?['lastSessionHoraire'] as String?;
      final currentHoraire = widget.classData['horaireDebut'] as String?;

      if (sessionCompletedForTimeSlot && lastSessionHoraire == currentHoraire) {
        _showSnackBar('Une session a déjà été effectuée pour ce créneau horaire aujourd\'hui', warningColor);
        return;
      }

      final existingSessionId = classDoc.data()?['attendanceSessionId'] as String?;
      if (existingSessionId != null) {
        final existingSession = await FirebaseFirestore.instance
            .collection('attendances')
            .doc(existingSessionId)
            .get();

        if (existingSession.exists && !(existingSession.data()?['isClosed'] ?? false)) {
          _showSnackBar('Une session est déjà active pour ce cours', warningColor);
          return;
        }
      }

      setState(() {
        attendanceStatus = {
          for (var student in enrolledStudents) student.uid: false,
        };
      });

      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(newSessionId)
          .set({
        'classId': widget.classId,
        'className': widget.classData['nom'],
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(sessionEnd),
        'presentStudentsUid': [],
        'isClosed': false,
        'sessionCode': _generateSessionCode(),
        'sessionDuration': 15,
        'serverStartTime': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': newSessionId,
      });

      setState(() {
        sessionId = newSessionId;
        _remainingTime = sessionEnd.difference(now).inSeconds;
        isSessionClosed = false;
        _sessionStatus = SessionStatus.qrCodeActive;
        _canStartQRSession = false;
      });

      _startSessionTimer();
      _showSnackBar('QR Code activé pour 15 minutes - Présences réinitialisées', successColor);

    } catch (e) {
      print("Erreur démarrage session QR: $e");
      _showSnackBar("Erreur démarrage session QR: $e", errorColor);
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
        setState(() {
          _sessionStatus = SessionStatus.duringClass;
          _canStartQRSession = true;
        });
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
      await _saveToHistory();

      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionIdToClose)
          .update({
        'isClosed': true,
        'closedAt': Timestamp.now(),
        'autoClosed': true,
      });

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': FieldValue.delete(),
        'todaySessionHappened': true,
        'lastSessionDate': Timestamp.now(),
        'lastSessionHoraire': widget.classData['horaireDebut'],
        'sessionCompletedForTimeSlot': true,
      });

      setState(() {
        isSessionClosed = true;
        sessionId = null;
        _sessionStatus = SessionStatus.afterClass;
        _canStartQRSession = false;
        _hasSessionHappenedInThisTimeSlot = true;
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
            photoUrl: data['profilePicture'],
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
        content: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 3),
        elevation: 6,
        showCloseIcon: true,
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  int _calculateRemainingTime(Timestamp expiresAt) {
    final now = DateTime.now();
    final expiration = expiresAt.toDate();
    final remaining = expiration.difference(now).inSeconds;
    return remaining.clamp(0, 15 * 60);
  }

  String _getStatusMessage() {
    switch (_sessionStatus) {
      case SessionStatus.beforeClass:
        return 'Le cours commence dans ${_formatTime(_remainingTime)}';
      case SessionStatus.duringClass:
        return 'Cours en cours - Démarrez le QR Code';
      case SessionStatus.qrCodeActive:
        final minutes = _remainingTime ~/ 60;
        final seconds = _remainingTime % 60;
        return 'QR Code actif';
      case SessionStatus.afterClass:
        return 'Session terminée - Présences sauvegardées';
      case SessionStatus.teacherAbsent:
        return 'Cours terminé - Professeur absent';
      case SessionStatus.classCanceled:
        return 'Cours annulé';
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
      case SessionStatus.qrCodeActive:
        return Icons.qr_code_2_rounded;
      case SessionStatus.afterClass:
        return Icons.verified_rounded;
      case SessionStatus.teacherAbsent:
        return Icons.person_off_rounded;
      case SessionStatus.classCanceled:
        return Icons.cancel_rounded;
      case SessionStatus.loading:
        return Icons.hourglass_bottom_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getStatusColor() {
    switch (_sessionStatus) {
      case SessionStatus.beforeClass:
        return warningColor;
      case SessionStatus.duringClass:
        return primaryColor;
      case SessionStatus.qrCodeActive:
        return successColor;
      case SessionStatus.afterClass:
        return Colors.blue;
      case SessionStatus.teacherAbsent:
        return Colors.orange;
      case SessionStatus.classCanceled:
        return Colors.grey;
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
        _sessionStatus == SessionStatus.qrCodeActive;
  }

  // Design moderne 3D pour les cartes
  BoxDecoration _modernCardDecoration({Color? color, bool withGradient = false}) {
    return BoxDecoration(
      gradient: withGradient ? cardGradient : null,
      color: withGradient ? null : color ?? surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: cardShadowColor.withOpacity(0.1),
          blurRadius: 20,
          offset: Offset(0, 4),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: cardShadowColor.withOpacity(0.05),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1,
      ),
    );
  }

  Widget _buildModernCard({
    required Widget child,
    Color? color,
    bool withGradient = false,
    EdgeInsets? padding,
  }) {
    return Container(
      decoration: _modernCardDecoration(color: color, withGradient: withGradient),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }

  // Méthode pour construire l'avatar de l'étudiant
  Widget _buildStudentAvatar(Student student) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: student.photoUrl != null && student.photoUrl!.isNotEmpty
            ? Image.network(
          student.photoUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultAvatar(student.fullName);
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(student.fullName);
          },
        )
            : _buildDefaultAvatar(student.fullName),
      ),
    );
  }

  // Avatar par défaut avec initiales
  Widget _buildDefaultAvatar(String fullName) {
    final initials = _getInitials(fullName);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Méthode pour extraire les initiales
  String _getInitials(String fullName) {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (fullName.isNotEmpty) {
      return fullName.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  // NOUVELLE MÉTHODE : Icône de présence/absence
  Widget _buildAttendanceIcon(bool isPresent) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isPresent ? successColor.withOpacity(0.1) : errorColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: isPresent ? successColor : errorColor,
          width: 1.5,
        ),
      ),
      child: Icon(
        isPresent ? Icons.check_rounded : Icons.close_rounded,
        size: 14,
        color: isPresent ? successColor : errorColor,
      ),
    );
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
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: surfaceColor,
        elevation: 0,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          if (_sessionStatus == SessionStatus.qrCodeActive && !isSessionClosed)
            IconButton(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline_rounded, size: 18, color: Colors.white),
              ),
              onPressed: () {
                _showSnackBar('QR Code valable 15 minutes - Sauvegarde automatique', primaryColor);
              },
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
            final isClosed = data['isClosed'] ?? false;

            if (isClosed && !isSessionClosed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  isSessionClosed = true;
                  sessionId = null;
                  _sessionStatus = SessionStatus.afterClass;
                  _canStartQRSession = false;
                  _hasSessionHappenedInThisTimeSlot = true;
                });
              });
            }

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

          for (var s in enrolledStudents) {
            if (presentUids.contains(s.uid)) {
              attendanceStatus[s.uid] = true;
            }
          }

          final presentCount = attendanceStatus.values.where((v) => v).length;
          final absentCount = enrolledStudents.length - presentCount;

          return SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(presentCount, absentCount),
                  const SizedBox(height: 16),
                  _buildStatusSection(),

                  if (_hasSessionHappenedInThisTimeSlot) ...[
                    const SizedBox(height: 16),
                    _buildSessionAlreadyDoneSection(),
                  ]
                  else if (_sessionStatus == SessionStatus.teacherAbsent) ...[
                    const SizedBox(height: 16),
                    _buildTeacherAbsentSection(),
                  ]
                  else if (_sessionStatus == SessionStatus.classCanceled) ...[
                      const SizedBox(height: 16),
                      _buildClassCanceledSection(),
                    ]
                    else if (_sessionStatus == SessionStatus.duringClass && _canStartQRSession) ...[
                        const SizedBox(height: 16),
                        _buildStartQRSection(),
                      ],

                  if (_canShowQRCode) ...[
                    const SizedBox(height: 16),
                    _buildQrCodeSection(),
                  ],

                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildStudentList(isClosed),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection() {
    return _buildModernCard(
      withGradient: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_getStatusColor(), _getStatusColor().withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(_getStatusIcon(), size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statut de la session',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusMessage(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_sessionStatus == SessionStatus.qrCodeActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: successGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: successColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '15min',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionAlreadyDoneSection() {
    return _buildModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_rounded, color: warningColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Session déjà effectuée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Une session de présence a déjà été réalisée',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Horaire: ${widget.classData['horaireDebut'] ?? 'Non spécifié'} - ${widget.classData['horaireFin'] ?? 'Non spécifié'}',
              style: TextStyle(
                color: primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartQRSection() {
    return _buildModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Démarrer le QR Code de présence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Le QR Code sera actif pendant 15 minutes',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _startQRSession,
              icon: Icon(Icons.qr_code_2_rounded, size: 20),
              label: Text(
                'Démarrer QR Code (15min)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection() {
    final minutes = _remainingTime ~/ 60;
    final seconds = _remainingTime % 60;

    return _buildModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'QR Code de présence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.grey[100]!, width: 2),
            ),
            child: QrImageView(
              data: sessionId ?? '',
              size: 200,
              version: QrVersions.auto,
              foregroundColor: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Expire dans: ${minutes}min ${seconds}s',
              style: TextStyle(
                color: successColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sauvegarde automatique à la fin',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement...',
            style: TextStyle(
              color: textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int presentCount, int absentCount) {
    return _buildModernCard(
      withGradient: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Classe : ${widget.classData['nom']}",
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
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
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      _hasSessionHappenedInThisTimeSlot
                          ? 'Session déjà effectuée '
                          : 'Présences sauvegardées dans l\'historique',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1),
      ),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.search_rounded, color: primaryColor, size: 20),
          ),
          hintText: 'Rechercher un étudiant...',
          hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (val) => setState(() => searchQuery = val),
      ),
    );
  }

  Widget _buildStudentList(bool isClosed) {
    if (filteredStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Aucun étudiant trouvé',
              style: TextStyle(color: textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredStudents.map((student) {
        final isPresent = attendanceStatus[student.uid] ?? false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: ListTile(
              leading: _buildStudentAvatar(student),
              title: Text(
                student.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                student.studentIdentifier,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 NOUVEAU : Icône de présence/absence
                  if (_sessionStatus == SessionStatus.afterClass || isSessionClosed)
                    _buildAttendanceIcon(isPresent),

                  const SizedBox(width: 8),

                  // Bouton présent/absent (seulement si session active)
                  if (!isClosed)
                    _buildAttendanceBadge(student.uid, isPresent),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceBadge(String uid, bool isPresent) {
    return GestureDetector(
      onTap: () => _toggleStudent(uid, !isPresent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isPresent ? successGradient : LinearGradient(
            colors: [Colors.grey.shade300, Colors.grey.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isPresent ? successColor : Colors.grey).withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          isPresent ? 'Présent' : 'Absent',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Sections pour professeur absent et cours annulé (design moderne)
  Widget _buildTeacherAbsentSection() {
    return _buildModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.orange.shade700],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_off_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professeur absent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      'Aucun QR Code de présence n\'a été généré',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Les étudiants ont été notifiés',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Une notification a été envoyée aux étudiants pour les informer de cette absence.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCanceledSection() {
    return _buildModernCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_rounded, color: Colors.grey, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cours annulé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Cette séance a été annulée par le professeur',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}