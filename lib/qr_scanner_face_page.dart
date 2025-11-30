// lib/pages/qr_scanner_face_page.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/face_recognition_service.dart';

class QRScannerFacePage extends StatefulWidget {
  final String classId;
  final String className;
  final String userUid;
  final String teacherName;

  const QRScannerFacePage({
    Key? key,
    required this.classId,
    required this.className,
    required this.userUid,
    required this.teacherName,
  }) : super(key: key);

  @override
  State<QRScannerFacePage> createState() => _QRScannerFacePageState();
}

class _QRScannerFacePageState extends State<QRScannerFacePage> {
  late MobileScannerController _qrController;
  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _locationVerified = false;
  bool _isInitializing = true;
  bool _qrScanned = false;
  bool _faceVerified = false;
  String? _scannedQRData;
  double _similarityScore = 0.0;
  String _verificationStatus = 'En attente...';
  bool _cameraReady = false;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color successColor = Color(0xFF10B981);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _qrController = MobileScannerController();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final locationResult = await LocationService.verifyLocation();
      final bool isWithinEstablishment = locationResult['isWithinEstablishment'] as bool;

      setState(() {
        _locationVerified = isWithinEstablishment;
      });

      if (!isWithinEstablishment) {
        _showError('Vous devez être dans l\'établissement pour valider la présence');
      }
    } catch (e) {
      _showError('Erreur de localisation: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      print('📷 Début initialisation caméra...');

      setState(() {
        _isInitializing = true;
        _cameraReady = false;
      });

      // Attendre un peu pour laisser le temps à la caméra QR de se fermer
      await Future.delayed(Duration(milliseconds: 500));

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Aucune caméra disponible');
      }

      print('📷 Caméras disponibles: ${cameras.length}');

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      print('📷 Utilisation caméra: ${frontCamera.name} (${frontCamera.lensDirection})');

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      // Ajouter un listener pour les erreurs de caméra
      _cameraController!.addListener(() {
        if (_cameraController!.value.hasError) {
          print('❌ Erreur caméra: ${_cameraController!.value.errorDescription}');
        }
      });

      await _cameraController!.initialize();

      // Démarrer la preview immédiatement après l'initialisation
      await _cameraController!.resumePreview();

      print('✅ Caméra initialisée avec succès');

      setState(() {
        _isInitializing = false;
        _cameraReady = true;
      });

    } catch (e) {
      print('❌ Erreur initialisation caméra: $e');
      setState(() {
        _isInitializing = false;
        _cameraReady = false;
      });
      _showError('Erreur caméra: $e');
      _resetFaceDetection();
    }
  }

  Future<void> _captureAndVerifyFace() async {
    // Vérifications plus robustes
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      print('⏸️ Capture impossible - État incorrect');
      return;
    }

    setState(() {
      _isProcessing = true;
      _verificationStatus = 'Capture en cours...';
    });

    try {
      print('📸 Début capture et vérification faciale');

      // Vérifier que la caméra est prête
      if (!_cameraController!.value.isInitialized) {
        throw Exception('Caméra non initialisée');
      }

      // Capturer une image depuis la caméra
      print('📸 Prise de photo...');
      final XFile capturedFile = await _cameraController!.takePicture();
      final Uint8List capturedImageBytes = await capturedFile.readAsBytes();

      print('✅ Photo capturée: ${capturedFile.path}');

      setState(() {
        _verificationStatus = 'Analyse faciale Face++...';
      });

      // Vérifier la correspondance faciale avec Face++ API
      final result = await FaceRecognitionService.verifyFaceMatch(
          capturedImageBytes,
          widget.userUid
      );

      if (!result['success']) {
        throw Exception(result['error']);
      }

      final bool isMatch = result['isMatch'] as bool;
      final double confidence = result['confidence'] as double;

      print('🎯 Résultat reconnaissance: $isMatch, Score: $confidence');

      setState(() {
        _faceVerified = isMatch;
        _similarityScore = confidence;
        _verificationStatus = isMatch
            ? '✅ Correspondance confirmée!'
            : '❌ Visage non reconnu';
      });

      if (isMatch) {
        print('✅ Reconnaissance réussie, sauvegarde présence...');
        await _saveAttendance();
      } else {
        print('❌ Reconnaissance échouée');
        _showFaceRecognitionError(confidence);
      }

    } catch (e) {
      print('❌ Erreur vérification faciale: $e');
      _showError('Erreur vérification faciale: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showFaceRecognitionError(double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.face_retouching_off_rounded, color: errorColor),
            SizedBox(width: 8),
            Text('Visage Non Reconnu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('La reconnaissance faciale n\'a pas pu confirmer votre identité.'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Score de confiance Face++:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '${_similarityScore.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _similarityScore > 50 ? warningColor : errorColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _similarityScore / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _similarityScore > 70 ? successColor :
                        _similarityScore > 50 ? warningColor : errorColor
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Seuil minimum: 70%',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Conseils pour une meilleure reconnaissance:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 📷 Assurez-vous d\'avoir un bon éclairage'),
            Text('• 👁️ Regardez directement la caméra'),
            Text('• 🕶️ Retirez les lunettes de soleil'),
            Text('• 🧢 Évitez les casquettes et chapeaux'),
            Text('• 😊 Gardez une expression neutre'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Réessayer', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _processQRCode(String qrData) async {
    if (!_locationVerified) {
      _showError('Localisation non vérifiée');
      _resetQRScan();
      return;
    }

    // Empêcher les traitements multiples
    if (_isProcessing || _qrScanned) {
      print('⏸️ Traitement déjà en cours, ignore le scan');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      print('🔍 QR Code reçu: $qrData');

      final isValidQR = await _validateQRCode(qrData);

      if (isValidQR) {
        // ARRÊTER le scanner QR immédiatement
        await _qrController.stop();

        setState(() {
          _qrScanned = true;
          _scannedQRData = qrData;
          _isProcessing = false;
        });

        // Sauvegarder dans les préférences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_scanned_qr', qrData);
        await prefs.setString('last_scanned_class', widget.classId);
        await prefs.setString('last_scanned_user', widget.userUid);

        print('💾 QR code sauvegardé localement');

        // Initialiser la caméra pour la reconnaissance faciale
        await _initializeCamera();
      } else {
        _showError('QR Code invalide ou expiré');
        _resetQRScan();
      }
    } catch (e) {
      print('❌ Erreur traitement QR: $e');
      _showError('Erreur traitement QR: $e');
      _resetQRScan();
    }
  }

  Future<bool> _validateQRCode(String qrData) async {
    try {
      print('🔍 Validation QR Code: $qrData');

      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(qrData)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        print('📄 Données attendance: ${data.containsKey('classId') ? data['classId'] : 'classId non trouvé'}');

        if (data['isClosed'] == true) {
          print('❌ Session fermée');
          return false;
        }

        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          print('❌ QR Code expiré');
          return false;
        }

        if (data['classId'] != widget.classId) {
          print('❌ Mauvais classId: ${data['classId']} vs ${widget.classId}');
          return false;
        }

        print('✅ QR Code valide');
        return true;
      }

      print('❌ Document attendance non trouvé');
      return false;
    } catch (e) {
      print('❌ Erreur validation QR: $e');
      return false;
    }
  }

  Future<void> _saveAttendance() async {
    print('🟢 DÉBUT _saveAttendance()');

    try {
      print('💾 Début sauvegarde présence pour: ${widget.userUid}');

      // METHODE SECOURS : Récupérer le QR code depuis plusieurs sources
      String? qrData = _scannedQRData;
      print('🔍 QR Data from variable: $qrData');

      // Si _scannedQRData est null, essayer depuis les préférences
      if (qrData == null || qrData.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        qrData = prefs.getString('last_scanned_qr');
        print('🔄 Récupération QR depuis préférences: $qrData');
      }

      // Si toujours null, erreur critique
      if (qrData == null || qrData.isEmpty) {
        print('❌ ERREUR CRITIQUE: Impossible de récupérer le QR code');
        throw Exception('Données QR Code perdues');
      }

      print('📋 QR Data utilisé: $qrData');
      print('🏫 Class ID: ${widget.classId}');
      print('👤 User UID: ${widget.userUid}');

      // 1. VÉRIFIER SI DÉJÀ PRÉSENT
      print('🔍 Vérification si déjà présent...');
      final alreadyPresent = await _checkIfAlreadyPresent(qrData);
      print('🔍 Résultat vérification: $alreadyPresent');

      if (alreadyPresent) {
        print('⚠️ Étudiant déjà présent dans la session');
        await _showAlreadyPresentDialog();
        return;
      }

      // 2. RÉCUPÉRER ET VALIDER LE DOCUMENT
      print('📄 Récupération document Firestore...');
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(qrData)
          .get();

      if (!attendanceDoc.exists) {
        print('❌ ERREUR: Document attendance non trouvé: $qrData');
        throw Exception('Session de présence non trouvée');
      }

      final data = attendanceDoc.data()!;
      print('📄 Données document: $data');

      // Vérifications de sécurité
      if (data['isClosed'] == true) {
        print('❌ Session fermée');
        throw Exception('La session de présence est fermée');
      }

      if (data['classId'] != widget.classId) {
        print('❌ Mauvais classId: ${data['classId']} vs ${widget.classId}');
        throw Exception('QR Code non valable pour ce cours');
      }

      // 3. SAUVEGARDER LA PRÉSENCE
      print('➕ Ajout de l\'étudiant: ${widget.userUid}');

      print('🔥 Envoi à Firestore...');
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(qrData)
          .update({
        'presentStudentsUid': FieldValue.arrayUnion([widget.userUid]),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      print('✅ Présence envoyée à Firestore');

      // 4. ATTENDRE ET VÉRIFIER
      print('⏳ Attente vérification...');
      await Future.delayed(Duration(seconds: 2));

      print('🔍 Vérification Firestore...');
      final verificationDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(qrData)
          .get();

      final verificationData = verificationDoc.data()!;
      final presentStudents = List<String>.from(verificationData['presentStudentsUid'] ?? []);

      print('✅ Vérification Firestore: ${presentStudents.length} étudiants présents');
      print('✅ Liste actuelle: $presentStudents');
      print('✅ Notre étudiant présent: ${presentStudents.contains(widget.userUid)}');

      if (!presentStudents.contains(widget.userUid)) {
        print('❌ ÉCHEC: Étudiant non ajouté après vérification');
        throw Exception('Échec de la sauvegarde Firestore');
      }

      // 5. SAUVEGARDER L'HISTORIQUE
      print('📝 Sauvegarde historique...');
      await FirebaseFirestore.instance.collection('attendance_history').add({
        'classId': widget.classId,
        'className': widget.className,
        'userId': widget.userUid,
        'userName': 'Étudiant',
        'date': Timestamp.now(),
        'status': 'present',
        'scannedAt': Timestamp.now(),
        'teacherName': widget.teacherName,
        'attendanceId': qrData,
        'locationVerified': true,
        'faceVerified': true,
        'similarityScore': _similarityScore,
        'method': 'qr_face_verification_facepp',
        'confidence': _similarityScore,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('🎉 HISTORIQUE SAUVEGARDÉ - SUCCÈS COMPLET');

      // 6. NETTOYER LES DONNÉES TEMPORAIRES
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_scanned_qr');
      await prefs.remove('last_scanned_class');
      await prefs.remove('last_scanned_user');

      // 7. AFFICHER LE SUCCÈS
      print('🔄 Affichage dialogue succès...');
      await _showSuccess();
      print('✅ Dialogue succès terminé');

    } catch (e) {
      print('❌ ERREUR CRITIQUE dans _saveAttendance: $e');
      print('❌ Type erreur: ${e.runtimeType}');
      print('❌ Stack trace: ${e.toString()}');
      _showError('Erreur: ${e.toString()}');
    } finally {
      print('🔴 FIN _saveAttendance()');
    }
  }

  Future<bool> _checkIfAlreadyPresent([String? qrData]) async {
    try {
      // Utiliser le QR code fourni ou _scannedQRData
      final String targetQrData = qrData ?? _scannedQRData ?? '';

      if (targetQrData.isEmpty) {
        print('❌ QR Data est vide dans _checkIfAlreadyPresent');
        return false;
      }

      print('🔍 Vérification présence pour QR: $targetQrData');

      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc(targetQrData)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        final presentStudents = List<String>.from(data['presentStudentsUid'] ?? []);

        print('🔍 Vérification présence - Étudiant: ${widget.userUid}');
        print('📋 Liste des présents: $presentStudents');
        print('📊 Nombre d\'étudiants présents: ${presentStudents.length}');
        print('✅ Déjà présent: ${presentStudents.contains(widget.userUid)}');

        return presentStudents.contains(widget.userUid);
      } else {
        print('❌ Document attendance non trouvé: $targetQrData');
        return false;
      }
    } catch (e) {
      print('❌ Erreur vérification présence: $e');
      return false;
    }
  }

  Future<void> _showAlreadyPresentDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_rounded, color: warningColor, size: 30),
            SizedBox(width: 10),
            Text('Déjà Présent', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: warningColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 40, color: warningColor),
            ),
            SizedBox(height: 16),
            Text(
              'Vous avez déjà marqué votre présence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'pour cette session de cours.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Cours:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    widget.className,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enseignant: ${widget.teacherName}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  print('🔙 Retour à la liste des cours');
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Retour aux cours', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccess() async {
    print('🎉 Affichage du dialogue de succès');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: successColor, size: 30),
            SizedBox(width: 10),
            Text('Présence Validée!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.face_retouching_natural_rounded, size: 40, color: successColor),
            ),
            SizedBox(height: 16),
            Text('✅ QR Code validé', style: TextStyle(fontSize: 14)),
            Text('✅ Reconnaissance faciale IA réussie', style: TextStyle(fontSize: 14)),
            Text('✅ Localisation vérifiée', style: TextStyle(fontSize: 14)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Score Face++:', style: TextStyle(fontSize: 12)),
                  Text('${_similarityScore.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: successColor)),
                ],
              ),
            ),
            SizedBox(height: 10),
            Text('${widget.className}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: 4),
            Text('Enseignant: ${widget.teacherName}', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          Center(
            child: Container(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  print('🔙 Retour à la liste des cours');
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text('Fermer', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    print('❌ Affichage erreur: $message');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(Icons.error_rounded, color: errorColor),
          SizedBox(width: 8),
          Text('Erreur'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_qrScanned) {
                _resetFaceDetection();
              } else {
                _resetQRScan();
              }
            },
            child: Text('Réessayer', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  void _resetQRScan() {
    print('🔄 Reset scan QR');

    setState(() {
      _qrScanned = false;
      _scannedQRData = null;
      _isProcessing = false;
    });

    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _qrController.start().catchError((e) {
          print('❌ Erreur démarrage scanner QR: $e');
        });
      }
    });
  }

  void _resetFaceDetection() {
    print('🔄 Reset détection faciale');

    if (_cameraController != null) {
      _cameraController!.dispose();
      _cameraController = null;
    }

    setState(() {
      _faceVerified = false;
      _isProcessing = false;
      _similarityScore = 0.0;
      _verificationStatus = 'En attente...';
      _qrScanned = false;
      _isInitializing = false;
      _cameraReady = false;
    });

    Future.delayed(Duration(milliseconds: 1000), () {
      if (mounted) {
        _resetQRScan();
      }
    });
  }

  void _toggleFlash() {
    _qrController.toggleTorch();
  }

  void _switchCamera() {
    _qrController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            _qrScanned ? 'Reconnaissance Faciale IA' : 'Scan QR Code',
            style: TextStyle(color: Colors.white)
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: _qrScanned ? [] : [
          IconButton(onPressed: _toggleFlash, icon: Icon(Icons.flash_on), tooltip: 'Flash'),
          IconButton(onPressed: _switchCamera, icon: Icon(Icons.cameraswitch), tooltip: 'Caméra'),
        ],
      ),
      body: _qrScanned ? _buildFaceRecognitionUI() : _buildQRScannerUI(),
    );
  }

  Widget _buildQRScannerUI() {
    return Stack(
      children: [
        MobileScanner(
          controller: _qrController,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null && !_qrScanned && !_isProcessing) {
                print('📱 QR Code détecté: ${barcode.rawValue}');
                _qrController.stop();
                _processQRCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        _buildScannerOverlay(),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 16),
                  Text('Validation QR Code...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFaceRecognitionUI() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusIndicator('📍 Localisation', _locationVerified),
              _buildStatusIndicator('📱 QR Code', _qrScanned),
              _buildStatusIndicator('👤 IA Visage', _faceVerified),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (_cameraController != null && _cameraController!.value.isInitialized && !_isInitializing)
                CameraPreview(_cameraController!),

              if (_isInitializing)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      SizedBox(height: 16),
                      Text('Initialisation caméra...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),

              if (_cameraController == null || !_cameraController!.value.isInitialized)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 50, color: Colors.white54),
                      SizedBox(height: 16),
                      Text('Caméra non disponible', style: TextStyle(color: Colors.white)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _resetFaceDetection,
                        child: Text('Retour au scan QR'),
                      ),
                    ],
                  ),
                ),

              if (_cameraController != null && _cameraController!.value.isInitialized && !_isInitializing)
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _faceVerified ? successColor : primaryColor,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

              if (!_isInitializing && _cameraController != null && _cameraController!.value.isInitialized)
                Positioned(
                  bottom: 120,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        _faceVerified ? '✅ Visage vérifié!' : 'Appuyez pour capturer',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _verificationStatus,
                        style: TextStyle(
                          color: _faceVerified ? successColor : Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_similarityScore > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Score Face++: ${(_similarityScore).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _similarityScore > 70 ? successColor : warningColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              if (!_isInitializing &&
                  !_isProcessing &&
                  _cameraController != null &&
                  _cameraController!.value.isInitialized &&
                  _cameraReady)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _captureAndVerifyFace,
                      backgroundColor: primaryColor,
                      child: Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),

              if (_isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        SizedBox(height: 16),
                        Text(_verificationStatus, style: TextStyle(color: Colors.white, fontSize: 16)),
                        if (_similarityScore > 0)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Confiance: ${_similarityScore.toStringAsFixed(1)}%',
                              style: TextStyle(color: Colors.white70),
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
    );
  }

  Widget _buildScannerOverlay() {
    return Column(
      children: [
        Expanded(child: Container(color: Colors.black.withOpacity(0.4))),
        Container(
          height: 300,
          child: Row(
            children: [
              Expanded(child: Container(color: Colors.black.withOpacity(0.4))),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(),
                ),
              ),
              Expanded(child: Container(color: Colors.black.withOpacity(0.4))),
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
                SizedBox(height: 16),
                Text('Scannez le QR Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Positionnez le QR Code dans le cadre', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(String label, bool isVerified) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isVerified ? successColor : Colors.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isVerified
                ? Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : Icon(Icons.access_time_rounded, size: 20, color: Colors.white),
          ),
        ),
        SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _qrController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFF6366F1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(20, 0)..lineTo(0, 0)..lineTo(0, 20)
      ..moveTo(0, size.height - 20)..lineTo(0, size.height)..lineTo(20, size.height)
      ..moveTo(size.width - 20, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - 20)
      ..moveTo(size.width, 20)..lineTo(size.width, 0)..lineTo(size.width - 20, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}