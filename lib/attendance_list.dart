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
  qrCodeActive,
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
  bool _canStartQRSession = false;
  bool _hasSessionHappenedInThisTimeSlot = false; // NOUVEAU: Stocker l'état local par créneau

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

      // Vérifier si une session a déjà eu lieu dans ce créneau horaire
      _hasSessionHappenedInThisTimeSlot = await _hasSessionAlreadyHappenedInThisTimeSlot();

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
          _sessionStatus = SessionStatus.qrCodeActive;
          _startSessionTimer();

          // Charger les présences existantes
          _loadExistingAttendance(sessionData);

          // DÉSACTIVER LE BOUTON POUR DÉMARRER UN NOUVEAU QR
          setState(() {
            isLoading = false;
            _canStartQRSession = false;
          });
          return;
        } else if (!isClosed && expiresAt != null && now.isAfter(expiresAt)) {
          // Session expirée - sauvegarder et fermer
          await _saveToHistoryAndCloseSession(existingSessionId);
        }
      }
    }

    // Vérifier l'horaire du cours pour déterminer l'état
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

      // Vérifier si une session a déjà été complétée pour ce créneau horaire
      final sessionCompletedForTimeSlot = classData['sessionCompletedForTimeSlot'] ?? false;
      if (sessionCompletedForTimeSlot) {
        // Vérifier si c'est le même créneau horaire
        final lastSessionHoraire = classData['lastSessionHoraire'] as String?;
        final currentHoraire = widget.classData['horaireDebut'] as String?;

        if (lastSessionHoraire == currentHoraire) {
          return true; // Même créneau horaire, session déjà faite
        }
      }

      // Vérifier la date de la dernière session et l'horaire
      final lastSessionDate = classData['lastSessionDate'] as Timestamp?;
      final lastSessionHoraire = classData['lastSessionHoraire'] as String?;
      final currentHoraire = widget.classData['horaireDebut'] as String?;

      if (lastSessionDate != null && lastSessionHoraire != null && currentHoraire != null) {
        final lastSession = lastSessionDate.toDate();
        final today = DateTime.now();

        // Comparer les dates (jour/mois/année seulement)
        final isSameDay = lastSession.year == today.year &&
            lastSession.month == today.month &&
            lastSession.day == today.day;

        // Vérifier si c'est le même créneau horaire
        final isSameTimeSlot = lastSessionHoraire == currentHoraire;

        return isSameDay && isSameTimeSlot;
      }

      return false;
    } catch (e) {
      print("Erreur vérification session précédente: $e");
      return false;
    }
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
    bool canStartQR = false;

    // UTILISER LA VARIABLE LOCALE AU LIEU D'APPELER LA MÉTHODE DIRECTEMENT
    if (_hasSessionHappenedInThisTimeSlot) {
      // Une session a déjà eu lieu dans ce créneau horaire - EMPÊCHER TOUTE NOUVELLE SESSION
      newStatus = SessionStatus.afterClass;
      canStartQR = false;
      print('🚫 Session déjà effectuée pour ce créneau horaire - Nouvelle session bloquée');
    }
    else if (dateDebut != null && dateFin != null) {
      final isBeforeClass = now.isBefore(dateDebut);
      final isDuringClass = now.isAfter(dateDebut) && now.isBefore(dateFin);
      final isAfterClass = now.isAfter(dateFin);

      if (isBeforeClass) {
        // AVANT le cours - ATTENDRE l'heure exacte
        newStatus = SessionStatus.beforeClass;
        newRemainingTime = dateDebut.difference(now).inSeconds;
        _startPreSessionTimer();
      } else if (isDuringClass) {
        // PENDANT le cours - L'ENSEIGNANT PEUT DÉMARRER LE QR CODE
        // MAIS SEULEMENT SI AUCUNE SESSION N'EST ACTIVE
        newStatus = SessionStatus.duringClass;
        canStartQR = sessionId == null; // SEULEMENT SI PAS DE SESSION ACTIVE
      } else if (isAfterClass) {
        // APRÈS le cours
        newStatus = SessionStatus.afterClass;
      }
    } else {
      // Pas d'heures définies
      newStatus = SessionStatus.afterClass;
    }

    setState(() {
      _sessionStatus = newStatus;
      _remainingTime = newRemainingTime;
      _canStartQRSession = canStartQR;
      isLoading = false;
    });
  }

  Future<bool> _checkIfSessionAlreadyActive() async {
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      final existingSessionId = classDoc.data()?['attendanceSessionId'] as String?;

      if (existingSessionId != null) {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('attendances')
            .doc(existingSessionId)
            .get();

        if (sessionDoc.exists) {
          final sessionData = sessionDoc.data()!;
          final isClosed = sessionData['isClosed'] ?? false;
          final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

          return !isClosed && expiresAt != null && DateTime.now().isBefore(expiresAt);
        }
      }

      return false;
    } catch (e) {
      print("Erreur vérification session: $e");
      return false;
    }
  }

  Future<void> _startQRSession() async {
    // VÉRIFIER SI UNE SESSION A DÉJÀ EU LIEU DANS CE CRÉNEAU HORAIRE
    if (_hasSessionHappenedInThisTimeSlot) {
      _showSnackBar('Une session a déjà été effectuée pour ce créneau horaire aujourd\'hui', warningColor);
      return;
    }

    // EMPÊCHER LE DÉMARRAGE MULTIPLE
    if (!_canStartQRSession || sessionId != null) {
      _showSnackBar('Une session est déjà active', warningColor);
      return;
    }

    try {
      final newSessionId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";
      final now = DateTime.now();

      // VÉRIFIER UNE DERNIÈRE FOIS AVANT DE CRÉER
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      // Vérifier si une session a déjà eu lieu dans ce créneau horaire (double vérification)
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

      // Session de 15 minutes exactement
      final sessionEnd = now.add(Duration(minutes: 15));

      print('🕒 Démarrage session QR: ${DateFormat('HH:mm').format(now)}');
      print('⏰ Expiration session: ${DateFormat('HH:mm').format(sessionEnd)}');
      print('⏱️ Durée totale: 15 minutes');

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
        'sessionDuration': 15,
      });

      // Mettre à jour la classe avec la nouvelle session
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': newSessionId,
        // NE PAS marquer comme complétée ici - seulement à la fin de la session
      });

      // Mettre à jour l'état local
      setState(() {
        sessionId = newSessionId;
        _remainingTime = sessionEnd.difference(now).inSeconds;
        isSessionClosed = false;
        _sessionStatus = SessionStatus.qrCodeActive;
        _canStartQRSession = false;
      });

      _startSessionTimer();
      _showSnackBar('QR Code activé pour 15 minutes', successColor);

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

        // Afficher un message toutes les 30 secondes
        if (_remainingTime % 30 == 0) {
          final minutes = _remainingTime ~/ 60;
          print('⏳ Attente début cours: ${minutes}min ${_remainingTime % 60}s');
        }
      } else {
        // Le cours commence MAINTENANT - permettre le démarrage du QR Code
        print('🎯 Heure du cours atteinte - QR Code disponible');
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

      // 3. Supprimer la référence de session et MARQUER COMME COMPLÉTÉE POUR CE CRÉNEAU
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'attendanceSessionId': FieldValue.delete(),
        'todaySessionHappened': true,
        'lastSessionDate': Timestamp.now(),
        'lastSessionHoraire': widget.classData['horaireDebut'], // Stocker l'horaire de la session
        // AJOUTEZ CE CHAMP POUR EMPÊCHER LES NOUVELLES SESSIONS DANS CE CRÉNEAU
        'sessionCompletedForTimeSlot': true,
      });

      // METTRE À JOUR L'ÉTAT LOCAL
      setState(() {
        isSessionClosed = true;
        sessionId = null;
        _sessionStatus = SessionStatus.afterClass;
        _canStartQRSession = false;
        _hasSessionHappenedInThisTimeSlot = true; // METTRE À JOUR L'ÉTAT LOCAL
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
        'sessionDuration': 15, // Durée fixe de 15 minutes
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
        return 'Cours en cours - Démarrez le QR Code';
      case SessionStatus.qrCodeActive:
        final minutes = _remainingTime ~/ 60;
        final seconds = _remainingTime % 60;
        return 'QR Code actif - Expire dans: ${minutes}min ${seconds}s';
      case SessionStatus.afterClass:
      // UTILISER LA VARIABLE LOCALE AU LIEU D'APPELER LA MÉTHODE

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
      case SessionStatus.qrCodeActive:
        return Icons.qr_code_rounded;
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
        return primaryColor;
      case SessionStatus.qrCodeActive:
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
        _sessionStatus == SessionStatus.qrCodeActive;
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
          if (_sessionStatus == SessionStatus.qrCodeActive && !isSessionClosed)
            IconButton(
              icon: Icon(Icons.info_outline_rounded),
              onPressed: () {
                _showSnackBar('QR Code valable 15 minutes - Sauvegarde automatique', primaryColor);
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
            final isClosed = data['isClosed'] ?? false;

            // SI LA SESSION EST FERMÉE, METTRE À JOUR L'ÉTAT
            if (isClosed && !isSessionClosed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  isSessionClosed = true;
                  sessionId = null;
                  _sessionStatus = SessionStatus.afterClass;
                  _canStartQRSession = false;
                  _hasSessionHappenedInThisTimeSlot = true; // METTRE À JOUR L'ÉTAT LOCAL
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
                // AFFICHER DIRECTEMENT LE MESSAGE SI SESSION DÉJÀ EFFECTUÉE
                if (_hasSessionHappenedInThisTimeSlot) ...[
                  const SizedBox(height: 8),
                  _buildSessionAlreadyDoneSection(),
                ] else if (_sessionStatus == SessionStatus.duringClass && _canStartQRSession) ...[
                  const SizedBox(height: 8),
                  _buildStartQRSection(),
                ],
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
          if (_sessionStatus == SessionStatus.qrCodeActive)
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
                    '15min',
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

  // NOUVELLE SECTION : AFFICHAGE DIRECT DU MESSAGE QUAND SESSION DÉJÀ EFFECTUÉE
  Widget _buildSessionAlreadyDoneSection() {
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
                  color: warningColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_rounded, color: warningColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Session déjà effectuée',
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
          Text(
            'Une session de présence a déjà été réalisée pour ce créneau horaire aujourd\'hui',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Horaire: ${widget.classData['horaireDebut'] ?? 'Non spécifié'} - ${widget.classData['horaireFin'] ?? 'Non spécifié'}',
            style: TextStyle(
              color: primaryColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartQRSection() {
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
                child: Icon(Icons.play_arrow_rounded, color: primaryColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Démarrer le QR Code de présence',
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
          Text(
            'Le QR Code sera actif pendant 15 minutes',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startQRSession,
              icon: Icon(Icons.qr_code_rounded, size: 16),
              label: Text('Démarrer QR Code (15min)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
            'Durée: 15 minutes • Expire dans: ${minutes}min ${seconds}s',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Sauvegarde automatique à la fin',
            style: TextStyle(
              color: successColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
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
                    _hasSessionHappenedInThisTimeSlot
                        ? 'Session déjà effectuée pour ce créneau horaire'
                        : 'Présences sauvegardées dans l\'historique',
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