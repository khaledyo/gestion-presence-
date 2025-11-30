// lib/pages/classes_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'qr_scanner_face_page.dart';
import '../services/location_service.dart';

class ClassesListPage extends StatefulWidget {
  final String userUid;

  const ClassesListPage({Key? key, required this.userUid}) : super(key: key);

  @override
  State<ClassesListPage> createState() => _ClassesListPageState();
}

class _ClassesListPageState extends State<ClassesListPage> {
  List<Map<String, dynamic>> classes = [];
  bool isLoading = true;
  StreamSubscription? _classesSubscription;
  Map<String, StreamSubscription> _sessionSubscriptions = {};

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  final List<IconData> classIcons = const [
    Icons.school_outlined,
    Icons.menu_book_outlined,
    Icons.computer_outlined,
    Icons.science_outlined,
    Icons.architecture_outlined,
    Icons.groups_outlined,
    Icons.calculate_outlined,
    Icons.psychology_outlined,
    Icons.model_training_outlined,
    Icons.code_outlined,
    Icons.memory_outlined,
    Icons.language_outlined,
    Icons.storage_outlined,
    Icons.cloud_outlined,
    Icons.smart_toy_outlined,
    Icons.engineering_outlined,
    Icons.laptop_mac_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    _sessionSubscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    super.dispose();
  }

  Future<void> _checkGPSAndNavigate(Map<String, dynamic> classe) async {
    bool shouldNavigate = await _verifyLocationAccess();

    if (shouldNavigate) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerFacePage(
            classId: classe['id'],
            className: classe['nom'],
            userUid: widget.userUid,
            teacherName: classe['enseignant'],
          ),
        ),
      );
    }
  }

  Future<bool> _verifyLocationAccess() async {
    try {
      _showLocationVerificationDialog();

      bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!isLocationServiceEnabled) {
        Navigator.of(context, rootNavigator: true).pop();
        _showGPSRequiredDialog(
            title: 'GPS Désactivé',
            message: 'Service de localisation requis',
            subtitle: 'Activez votre GPS pour scanner le QR Code',
            details: [
              _buildDetailItem('📍 Localisation', 'GPS requis'),
              _buildDetailItem('🎯 Objectif', 'Anti-triche géographique'),
              _buildDetailItem('📱 Action', 'Activez votre GPS'),
            ]
        );
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          Navigator.of(context, rootNavigator: true).pop();
          _showGPSRequiredDialog(
              title: 'Permission Refusée',
              message: 'Accès localisation nécessaire',
              subtitle: 'Autorisez l\'accès à votre position pour continuer',
              details: [
                _buildDetailItem('🔧 Solution', 'Autorisez dans paramètres'),
                _buildDetailItem('🎯 Objectif', 'Anti-triche géographique'),
                _buildDetailItem('📱 Action', 'Modifiez les permissions'),
              ]
          );
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Navigator.of(context, rootNavigator: true).pop();
        _showGPSRequiredDialog(
            title: 'Permission Bloquée',
            message: 'Accès définitivement refusé',
            subtitle: 'Activez manuellement dans Paramètres → Applications',
            details: [
              _buildDetailItem('⚙️ Paramètres', 'Ouvrez les paramètres'),
              _buildDetailItem('📱 Applications', 'Trouvez cette app'),
              _buildDetailItem('📍 Permissions', 'Autorisez la localisation'),
            ]
        );
        return false;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        );

        Navigator.of(context, rootNavigator: true).pop();

        final locationResult = await LocationService.verifyLocation();
        final bool isWithinEstablishment = locationResult['isWithinEstablishment'] as bool;
        final double distance = locationResult['distance'] as double;

        if (!isWithinEstablishment) {
          _showGPSRequiredDialog(
              title: 'Hors Campus',
              message: 'Position non autorisée',
              subtitle: 'Rejoignez le campus universitaire pour scanner',
              details: [
                _buildDetailItem('📏 Distance actuelle', '${distance.toStringAsFixed(2)} m'),
                _buildDetailItem('🎯 Périmètre autorisé', '50 mètres'),
                _buildDetailItem('🏫 Université', 'Iset Kélibia'),
              ]
          );
          return false;
        }

        return true;

      } catch (e) {
        Navigator.of(context, rootNavigator: true).pop();
        _showGPSRequiredDialog(
            title: 'Erreur GPS',
            message: 'Impossible de vous localiser',
            subtitle: 'Vérifiez votre connexion et réessayez',
            details: [
              _buildDetailItem('🔧 Solution', 'Redémarrez le GPS'),
              _buildDetailItem('📶 Connexion', 'Vérifiez le signal'),
              _buildDetailItem('🔄 Action', 'Réessayez'),
            ]
        );
        return false;
      }

    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showGPSRequiredDialog(
          title: 'Erreur Inattendue',
          message: 'Problème technique',
          subtitle: 'Une erreur est survenue lors de la vérification',
          details: [
            _buildDetailItem('🔧 Détails', e.toString()),
          ]
      );
      return false;
    }
  }

  void _showLocationVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(4, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 20,
                        offset: const Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        strokeWidth: 4,
                      ),
                      Icon(
                        Icons.my_location_rounded,
                        color: primaryColor,
                        size: 40,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Vérification Position',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vérification de votre accès localisation...',
                  style: TextStyle(
                    fontSize: 16,
                    color: textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sécurité anti-triche activée',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGPSRequiredDialog({
    required String title,
    required String message,
    required String subtitle,
    List<Widget>? details,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        errorColor.withOpacity(0.2),
                        errorColor.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: errorColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(4, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 20,
                        offset: const Offset(-4, -4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.location_off_rounded,
                    color: errorColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: errorColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (details != null && details.isNotEmpty) ...[
                  Column(
                    children: details
                        .map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: detail,
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () => Navigator.pop(context),
                            child: Center(
                              child: Text(
                                'Annuler',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(25),
                            onTap: () {
                              Navigator.pop(context);
                              Geolocator.openLocationSettings();
                            },
                            child: Center(
                              child: Text(
                                'Paramètres',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _setupRealtimeUpdates() {
    _classesSubscription = FirebaseFirestore.instance
        .collection('classes')
        .where('studentsUid', arrayContains: widget.userUid)
        .snapshots()
        .listen((snapshot) {
      _processClassesUpdate(snapshot);
    });
  }

  void _processClassesUpdate(QuerySnapshot snapshot) {
    final List<Map<String, dynamic>> updatedClasses = [];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      String teacherName = 'Enseignant inconnu';
      String? teacherUid = data['enseignantUid'] ?? data['teacherUid'];

      if (teacherUid != null && teacherUid.isNotEmpty) {
        _setupTeacherListener(teacherUid, doc.id);
      }

      int iconIndex = data['iconIndex'] ?? 0;
      if (iconIndex < 0 || iconIndex >= classIcons.length) {
        iconIndex = 0;
      }

      updatedClasses.add({
        'id': doc.id,
        'nom': data['nom'] ?? 'Classe sans nom',
        'description': data['description'] ?? '',
        'enseignant': teacherName,
        'enseignantUid': teacherUid,
        'iconIndex': iconIndex,
        'createdAt': data['createdAt'],
        'hasActiveSession': false,
      });

      _setupSessionListener(doc.id);
    }

    setState(() {
      classes = updatedClasses;
      isLoading = false;
    });

    _debugSessionStatus();
  }

  void _setupTeacherListener(String teacherUid, String classId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid)
        .snapshots()
        .listen((teacherDoc) {
      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data();
        final teacherName = teacherData?['nom'] ?? teacherData?['name'] ?? 'Enseignant inconnu';

        setState(() {
          final classIndex = classes.indexWhere((c) => c['id'] == classId);
          if (classIndex != -1) {
            classes[classIndex]['enseignant'] = teacherName;
          }
        });
      }
    });
  }

  void _setupSessionListener(String classId) {
    final attendanceSubscription = FirebaseFirestore.instance
        .collection('attendances')
        .where('classId', isEqualTo: classId)
        .where('isClosed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      bool hasActiveSession = false;

      if (snapshot.docs.isNotEmpty) {
        final session = snapshot.docs.first;
        final sessionData = session.data();
        final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

        hasActiveSession = expiresAt != null && DateTime.now().isBefore(expiresAt);
      }

      _updateClassSessionStatus(classId, hasActiveSession);
    });

    _sessionSubscriptions['$classId-attendance'] = attendanceSubscription;
  }

  void _updateClassSessionStatus(String classId, bool hasActiveSession) {
    if (mounted) {
      setState(() {
        final classIndex = classes.indexWhere((c) => c['id'] == classId);
        if (classIndex != -1) {
          classes[classIndex]['hasActiveSession'] = hasActiveSession;
        }
      });
      _debugSessionStatus();
    }
  }

  void _debugSessionStatus() {
    print('=== DEBUG SESSION STATUS ===');
    for (var classe in classes) {
      print('📋 ${classe['nom']} (${classe['id']}): ${classe['hasActiveSession'] ? 'ACTIVE ✅' : 'FERMÉE ❌'}');
    }
    print('============================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Mes Cours'),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? _buildLoadingState()
          : classes.isEmpty
          ? _buildEmptyState()
          : _buildClassesList(),
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
          const SizedBox(height: 16),
          Text(
            'Chargement de vos cours...',
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_rounded, size: 80, color: textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Aucun cours trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos enseignants vous ajouteront à leurs cours',
            style: TextStyle(color: textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClassesList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: classes.length,
        itemBuilder: (context, index) {
          final classe = classes[index];
          return _buildClassCard(classe);
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classe) {
    final isQrAvailable = classe['hasActiveSession'] ?? false;
    final int iconIndex = classe['iconIndex'] ?? 0;
    final IconData classIcon = iconIndex < classIcons.length
        ? classIcons[iconIndex]
        : Icons.school_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(classIcon, color: primaryColor, size: 24),
        ),
        title: Text(
          classe['nom'],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textPrimary,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Enseignant: ${classe['enseignant']}',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isQrAvailable ? successColor.withOpacity(0.1) : warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isQrAvailable ? successColor : warningColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isQrAvailable ? 'Présence ouverte' : 'Présence fermée',
                    style: TextStyle(
                      color: isQrAvailable ? successColor : warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (classe['description'] != null && classe['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  classe['description'],
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isQrAvailable
                ? primaryColor.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
                Icons.qr_code_scanner_rounded,
                color: isQrAvailable ? primaryColor : Colors.grey,
                size: 20
            ),
            onPressed: () {
              if (isQrAvailable) {
                _checkGPSAndNavigate(classe);
              } else {
                _showQrNotAvailableDialog(context);
              }
            },
          ),
        ),
      ),
    );
  }

  void _showQrNotAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Présence non disponible'),
        content: const Text('La présence n\'est pas encore ouverte pour ce cours.\n\nVeuillez attendre que votre enseignant active le QR Code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}