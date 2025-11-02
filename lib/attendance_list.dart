import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

// Enum pour gérer les états de session (déplacé au niveau supérieur)
enum SessionStatus {
  loading,
  beforeClass,
  duringClass,
  afterClass,
  manualSession
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

  // Durée de validité du QR code (15 minutes par défaut)
  int _qrCodeDuration = 15 * 60; // 15 minutes en secondes

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
      });

      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      if (!classDoc.exists) {
        throw Exception('Classe non trouvée');
      }

      final classData = classDoc.data() ?? {};
      final existingSessionId = classData['currentAttendanceSessionId'] as String?;

      // Vérifier les heures de cours
      final now = DateTime.now();
      final dateDebut = (classData['dateDebut'] as Timestamp?)?.toDate();
      final dateFin = (classData['dateFin'] as Timestamp?)?.toDate();

      SessionStatus newStatus = SessionStatus.afterClass;
      int newRemainingTime = 0;

      if (dateDebut != null && dateFin != null) {
        if (now.isBefore(dateDebut)) {
          // Avant le cours
          newStatus = SessionStatus.beforeClass;
          newRemainingTime = dateDebut.difference(now).inSeconds;
        } else if (now.isAfter(dateDebut) && now.isBefore(dateFin)) {
          // Pendant le cours
          newStatus = SessionStatus.duringClass;
          newRemainingTime = dateFin.difference(now).inSeconds;

          // Créer automatiquement une session si pendant le cours
          if (existingSessionId == null) {
            await _createNewSession();
          }
        } else {
          // Après le cours
          newStatus = SessionStatus.afterClass;
        }
      } else {
        // Pas d'heures définies - permettre une session manuelle
        newStatus = SessionStatus.afterClass;
      }

      // Vérifier si une session existe et est active
      if (existingSessionId != null) {
        final sessionDoc = await FirebaseFirestore.instance
            .collection('attendances')
            .doc(existingSessionId)
            .get();

        if (sessionDoc.exists) {
          final sessionData = sessionDoc.data()!;
          final isClosed = sessionData['isClosed'] ?? false;

          if (!isClosed) {
            sessionId = existingSessionId;
            // Calculer le temps restant pour cette session
            final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();
            if (expiresAt != null) {
              newRemainingTime = expiresAt.difference(now).inSeconds;
              if (newRemainingTime > 0) {
                _startSessionTimer();
                // Si nous avons une session active, forcer le statut duringClass ou manual
                if (newStatus == SessionStatus.afterClass || newStatus == SessionStatus.beforeClass) {
                  newStatus = SessionStatus.manualSession;
                }
              } else {
                await _closeSession(existingSessionId);
                sessionId = null;
              }
            }
          }
        }
      }

      setState(() {
        _sessionStatus = newStatus;
        _remainingTime = newRemainingTime;
      });

      await _loadStudents();

    } catch (e) {
      print("Erreur d'initialisation: $e");
      _showSnackBar("Erreur d'initialisation: $e", errorColor);
      setState(() {
        isLoading = false;
        _sessionStatus = SessionStatus.afterClass;
      });
    }
  }

  Future<void> _createNewSession() async {
    try {
      sessionId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";

      final now = DateTime.now();
      final sessionEnd = now.add(Duration(seconds: _qrCodeDuration));

      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionId)
          .set({
        'classId': widget.classId,
        'className': widget.classData['nom'],
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(sessionEnd),
        'presentStudentsUid': [],
        'isClosed': false,
        'sessionCode': _generateSessionCode(),
        'isManualSession': true, // Toujours true pour les sessions créées manuellement
      });

      // Mettre à jour la classe avec la nouvelle session
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .update({
        'currentAttendanceSessionId': sessionId,
      });

      setState(() {
        _remainingTime = _qrCodeDuration;
        _sessionStatus = SessionStatus.manualSession;
        isSessionClosed = false;
      });

      _startSessionTimer();
      _showSnackBar('QR Code généré avec succès', successColor);

    } catch (e) {
      _showSnackBar("Erreur création session: $e", errorColor);
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
        _autoCloseSession();
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
        // Le cours commence maintenant
        setState(() {
          _sessionStatus = SessionStatus.duringClass;
        });
        _createNewSession();
        timer.cancel();
      }
    });
  }

  Future<void> _autoCloseSession() async {
    if (sessionId != null && !isSessionClosed) {
      await _closeSession(sessionId!);
      _showSnackBar('Session automatiquement fermée (temps écoulé)', warningColor);
    }
  }

  Future<void> _closeSession(String sessionIdToClose) async {
    await FirebaseFirestore.instance
        .collection('attendances')
        .doc(sessionIdToClose)
        .update({
      'isClosed': true,
      'closedAt': Timestamp.now(),
      'autoClosed': true,
    });

    setState(() {
      isSessionClosed = true;
    });
    _sessionTimer?.cancel();
  }

  Future<void> _startManualSession() async {
    // Fermer l'ancienne session si elle existe
    if (sessionId != null && !isSessionClosed) {
      await _closeSession(sessionId!);
    }

    // Créer une nouvelle session manuelle
    await _createNewSession();

    setState(() {
      _sessionStatus = SessionStatus.manualSession;
    });

    _showSnackBar('Session manuelle démarrée', successColor);
  }

  Future<void> _refreshQRCode() async {
    if (isSessionClosed) return;

    // Fermer l'ancienne session
    if (sessionId != null) {
      await _closeSession(sessionId!);
    }

    // Créer une nouvelle session
    await _createNewSession();

    _showSnackBar('Nouveau QR Code généré', primaryColor);
  }

  Future<void> _loadStudents() async {
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .get();

      final List<String> studentUids =
      List<String>.from(classDoc.data()?['studentsUid'] ?? []);

      if (studentUids.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: studentUids)
          .get();

      final fetchedStudents = studentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return Student(
          uid: doc.id,
          fullName: data['nom'] ?? 'Nom Inconnu',
          studentIdentifier: data['email'] ?? '',
        );
      }).toList();

      setState(() {
        enrolledStudents = fetchedStudents;
        attendanceStatus = {
          for (var s in fetchedStudents) s.uid: false,
        };
        isLoading = false;
      });
    } catch (e) {
      _showSnackBar("Erreur chargement étudiants: $e", errorColor);
      setState(() => isLoading = false);
    }
  }

  Stream<DocumentSnapshot> getAttendanceStream() {
    if (sessionId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('attendances')
        .doc(sessionId)
        .snapshots();
  }

  Future<void> _saveAndCloseSession() async {
    if (isSessionClosed || sessionId == null) return;

    final presentStudents = attendanceStatus.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    try {
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(sessionId)
          .set({
        'presentStudentsUid': presentStudents,
        'isClosed': true,
        'closedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      setState(() {
        isSessionClosed = true;
      });

      _sessionTimer?.cancel();

      _showSnackBar(
        'Présence enregistrée (${presentStudents.length}/${enrolledStudents.length})',
        successColor,
      );
    } catch (e) {
      _showSnackBar("Erreur lors de la sauvegarde: $e", errorColor);
    }
  }

  void _toggleStudent(String uid, bool status) {
    if (isSessionClosed) return;
    setState(() {
      attendanceStatus[uid] = status;
    });
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
        return 'Cours en cours - Temps restant: ${_formatTime(_remainingTime)}';
      case SessionStatus.afterClass:
        return 'Le cours est terminé';
      case SessionStatus.manualSession:
        return 'Session manuelle - Expire dans: ${_formatTime(_remainingTime)}';
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
      case SessionStatus.manualSession:
        return Icons.qr_code_rounded;
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
        return errorColor;
      case SessionStatus.manualSession:
        return primaryColor;
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
        (_sessionStatus == SessionStatus.duringClass ||
            _sessionStatus == SessionStatus.manualSession ||
            _sessionStatus == SessionStatus.beforeClass);
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
          if (!isLoading && _sessionStatus != SessionStatus.loading)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'start_manual') {
                  _startManualSession();
                } else if (value == 'refresh_qr') {
                  _refreshQRCode();
                }
              },
              itemBuilder: (context) => [
                if (_sessionStatus != SessionStatus.duringClass &&
                    _sessionStatus != SessionStatus.manualSession)
                  PopupMenuItem(
                    value: 'start_manual',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Démarrer session manuelle'),
                      ],
                    ),
                  ),
                if ((_sessionStatus == SessionStatus.duringClass ||
                    _sessionStatus == SessionStatus.manualSession) &&
                    !isSessionClosed)
                  PopupMenuItem(
                    value: 'refresh_qr',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 20),
                        SizedBox(width: 8),
                        Text('Rafraîchir QR Code'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : StreamBuilder<DocumentSnapshot>(
        stream: getAttendanceStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData && sessionId != null) {
            return _buildLoadingState();
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

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(presentCount, absentCount),
                const SizedBox(height: 12),
                _buildStatusSection(),
                if (_canShowQRCode) _buildQrCodeSection(),
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildStudentList(isClosed),
                ),
                const SizedBox(height: 12),
                _buildActionButton(isClosed),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Icon(_getStatusIcon(), size: 24, color: _getStatusColor()),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusMessage(),
              style: TextStyle(
                color: _getStatusColor(),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // Bouton pour démarrer une session manuelle si pas de QR code
          if (!_canShowQRCode && !isSessionClosed)
            ElevatedButton.icon(
              onPressed: _startManualSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: Icon(Icons.qr_code_rounded, size: 16),
              label: Text('Générer QR Code'),
            ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code_rounded, color: primaryColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QR Code de présence - ${_formatTime(_remainingTime)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: QrImageView(
              data: sessionId ?? '',
              size: 180,
              version: QrVersions.auto,
              foregroundColor: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sessionId != null ? "Session ID: ${sessionId!.substring(0, 10)}..." : "",
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scanné par les étudiants',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chargement...',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int presentCount, int absentCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Présents', presentCount, successColor, Icons.check_circle_rounded),
              _buildStatItem('Absents', absentCount, errorColor, Icons.cancel_rounded),
              _buildStatItem('Total', enrolledStudents.length, primaryColor, Icons.people_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
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
          prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
          hintText: 'Rechercher un étudiant...',
          hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            Icon(Icons.search_off_rounded, size: 50, color: textSecondary.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text(
              'Aucun étudiant trouvé',
              style: TextStyle(color: textSecondary, fontSize: 14),
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
          margin: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(10),
            elevation: 1,
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPresent ? successColor.withOpacity(0.1) : errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPresent ? Icons.check_rounded : Icons.close_rounded,
                  color: isPresent ? successColor : errorColor,
                  size: 16,
                ),
              ),
              title: Text(
                student.fullName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                student.studentIdentifier,
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              trailing: !isClosed ? _buildToggleButton(student.uid, isPresent) : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minLeadingWidth: 0,
              dense: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleButton(String uid, bool isPresent) {
    return GestureDetector(
      onTap: () => _toggleStudent(uid, !isPresent),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPresent ? successColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPresent ? successColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          isPresent ? 'Présent' : 'Marquer',
          style: TextStyle(
            color: isPresent ? Colors.white : textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isClosed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isClosed ? null : _saveAndCloseSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isClosed ? Icons.lock_rounded : Icons.save_rounded,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              isClosed ? 'Session Clôturée' : 'Enregistrer et Clôturer',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}