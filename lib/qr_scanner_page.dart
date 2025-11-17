// lib/pages/student/qr_scanner_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final String classId;
  final String className;
  final String userUid;
  final String? sessionId;
  final String? teacherName;

  const QRScannerPage({
    Key? key,
    required this.classId,
    required this.className,
    required this.userUid,
    this.sessionId,
    this.teacherName,
  }) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool isLoading = false;
  bool isScanning = true;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String qrData) async {
    if (!isScanning) return;

    setState(() {
      isScanning = false;
      isLoading = true;
    });

    try {
      // Vérifier d'abord si c'est un QR code de session
      final sessionQuery = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('sessions')
          .where('qrCode', isEqualTo: qrData)
          .get();

      if (sessionQuery.docs.isNotEmpty) {
        // QR code de session trouvé
        final sessionDoc = sessionQuery.docs.first;
        final sessionData = sessionDoc.data();

        await _markAttendanceInSession(sessionDoc.reference, sessionData);
        return;
      }

      // Si pas trouvé dans les sessions, vérifier dans attendances
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(qrData)
          .get();

      if (!attendanceDoc.exists) {
        _showResultDialog(
          'QR Code invalide',
          'Cette session de présence n\'existe pas.',
          false,
        );
        return;
      }

      final attendanceData = attendanceDoc.data()!;

      if (attendanceData['classId'] != widget.classId) {
        _showResultDialog(
          'Classe incorrecte',
          'Ce QR Code ne correspond pas à cette classe.',
          false,
        );
        return;
      }

      if (attendanceData['isClosed'] == true) {
        _showResultDialog(
          'Session fermée',
          'Cette session de présence est déjà clôturée.',
          false,
        );
        return;
      }

      final presentStudents = List<String>.from(attendanceData['presentStudentsUid'] ?? []);

      if (!presentStudents.contains(widget.userUid)) {
        presentStudents.add(widget.userUid);

        await FirebaseFirestore.instance
            .collection('attendances')
            .doc(qrData)
            .update({
          'presentStudentsUid': presentStudents,
        });

        // Créer aussi un enregistrement dans l'historique
        await _createHistoryRecord(attendanceData);

        _showResultDialog(
          'Présence Valide!',
          'Votre présence a été validée pour ${widget.className}',
          true,
        );
      } else {
        _showResultDialog(
          'Déjà présent',
          'Vous avez déjà marqué votre présence pour cette session.',
          true,
        );
      }

    } catch (e) {
      _showResultDialog(
        'Erreur',
        'Une erreur est survenue: $e',
        false,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _markAttendanceInSession(DocumentReference sessionRef, Map<String, dynamic> sessionData) async {
    try {
      final presentStudents = List<String>.from(sessionData['presentStudents'] ?? []);

      if (!presentStudents.contains(widget.userUid)) {
        presentStudents.add(widget.userUid);

        await sessionRef.update({
          'presentStudents': presentStudents,
          'presentCount': FieldValue.increment(1),
        });

        // Créer un enregistrement dans l'historique
        await FirebaseFirestore.instance.collection('attendance_history').add({
          'classId': widget.classId,
          'className': widget.className,
          'userId': widget.userUid,
          'userName': 'Étudiant', // Vous pouvez récupérer le nom depuis Firestore
          'date': Timestamp.now(),
          'status': 'present',
          'scannedAt': Timestamp.now(),
          'teacherName': widget.teacherName ?? 'Enseignant inconnu',
          'sessionId': sessionRef.id,
          'startTime': sessionData['startTime'],
          'endTime': sessionData['endTime'],
        });

        _showResultDialog(
          'Présence Valide!',
          'Votre présence a été validée pour ${widget.className}',
          true,
        );
      } else {
        _showResultDialog(
          'Déjà présent',
          'Vous avez déjà marqué votre présence pour cette session.',
          true,
        );
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> _createHistoryRecord(Map<String, dynamic> attendanceData) async {
    await FirebaseFirestore.instance.collection('attendance_history').add({
      'classId': widget.classId,
      'className': widget.className,
      'userId': widget.userUid,
      'userName': 'Étudiant',
      'date': Timestamp.now(),
      'status': 'present',
      'scannedAt': Timestamp.now(),
      'teacherName': widget.teacherName ?? 'Enseignant inconnu',
      'attendanceId': attendanceData['id'],
      'startTime': attendanceData['startTime'],
      'endTime': attendanceData['endTime'],
    });
  }

  void _showResultDialog(String title, String message, bool isSuccess) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? successColor : errorColor,
              ),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (isSuccess) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    isScanning = true;
                  });
                  cameraController.start();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
  }

  void _switchCamera() {
    cameraController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scanner - ${widget.className}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: const Icon(Icons.flash_on),
            tooltip: 'Activer/Désactiver le flash',
          ),
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Changer de caméra',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner de QR code
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && isScanning) {
                  _processQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Overlay de visée
          _buildScannerOverlay(),

          // Indicateur de chargement
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Traitement en cours...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

  Widget _buildScannerOverlay() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        Container(
          height: 300,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primaryColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black.withOpacity(0.4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'Scannez le QR Code de présence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Positionnez le QR Code dans le cadre pour scanner automatiquement',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(20, 0)
      ..lineTo(0, 0)
      ..lineTo(0, 20)
      ..moveTo(0, size.height - 20)
      ..lineTo(0, size.height)
      ..lineTo(20, size.height)
      ..moveTo(size.width - 20, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - 20)
      ..moveTo(size.width, 20)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 20, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}