import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_create_class_page.dart';
import 'dart:async';
import 'admin_edit_session_page.dart';

class AdminManageSessionsPage extends StatefulWidget {
  final String userName;
  final String userUid;

  const AdminManageSessionsPage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AdminManageSessionsPage> createState() =>
      _AdminManageSessionsPageState();
}

class _AdminManageSessionsPageState extends State<AdminManageSessionsPage> {
  // Couleurs modernes
  final Color _primaryColor = Color(0xFF7F5BFF);
  final Color _secondaryColor = Color(0xFF6A5AE0);
  final Color _accentColor = Color(0xFF06D6A0);
  final Color _backgroundColor = Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _cardColor = Colors.white;
  final Color _textColor = Color(0xFF1E293B);
  final Color _hintColor = Color(0xFF64748B);
  final Color _dangerColor = Color(0xFFEF4444);
  final Color _warningColor = Color(0xFFF59E0B);
  final Color _borderColor = Color(0xFFE2E8F0);

  bool _isLoading = true;
  bool _isDeleteMode = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allSessions = [];
  List<Map<String, dynamic>> _filteredSessions = [];
  StreamSubscription<QuerySnapshot>? _sessionsSubscription;

  // Liste des icônes disponibles (doit correspondre à celle dans admin_create_class_page.dart)
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
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtimeListener() {
    _sessionsSubscription = FirebaseFirestore.instance
        .collection('classes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            _updateSessionsFromSnapshot(snapshot);
          },
          onError: (error) {
            print('Error listening to sessions: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );
  }

  void _updateSessionsFromSnapshot(QuerySnapshot snapshot) {
    try {
      final sessions = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          sessions.add({'id': doc.id, ...data});
        } catch (e) {
          print('Error processing document ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _allSessions = sessions;
          _filteredSessions = _filterSessions(sessions);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error updating sessions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterSessions(
    List<Map<String, dynamic>> sessions,
  ) {
    if (_searchQuery.isEmpty) return sessions;

    final query = _searchQuery.toLowerCase();
    return sessions.where((session) {
      try {
        final sessionName = session['nom']?.toString().toLowerCase() ?? '';
        final teacherName =
            session['enseignantName']?.toString().toLowerCase() ?? '';
        final className =
            session['schoolClass']?.toString().toLowerCase() ?? '';

        return sessionName.contains(query) ||
            teacherName.contains(query) ||
            className.contains(query);
      } catch (e) {
        print('Error filtering session: $e');
        return false;
      }
    }).toList();
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(sessionId)
          .delete();

      _showSnackBar('Séance supprimée avec succès', _accentColor);
    } catch (e) {
      _showSnackBar('Erreur lors de la suppression: $e', _dangerColor);
    }
  }

  void _showDeleteConfirmation(String sessionId, String sessionName) {
    showDialog(
      context: context,
      builder: (context) => _buildConfirmationDialog(sessionId, sessionName),
    );
  }

  Widget _buildConfirmationDialog(String sessionId, String sessionName) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _dangerColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, size: 32, color: _dangerColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Supprimer la séance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Êtes-vous sûr de vouloir supprimer "$sessionName" ?',
              textAlign: TextAlign.center,
              style: TextStyle(color: _hintColor, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textColor,
                      side: BorderSide(color: _borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteSession(sessionId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dangerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editSession(Map<String, dynamic> sessionData) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminEditSessionPage(
            adminName: widget.userName,
            adminUid: widget.userUid,
            sessionId: sessionData['id'] ?? '',
            initialData: sessionData,
          ),
        ),
      );
    } catch (e) {
      print('Error editing session: $e');
      _showSnackBar('Erreur lors de l\'édition: $e', _dangerColor);
    }
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionName = _getSafeString(session['nom'], 'Séance sans nom');
    final className = _getSafeString(
      session['schoolClass'],
      'Classe non spécifiée',
    );
    final studentCount = _getSafeInt(session['nombreEtudiants'], 0);
    final teacherName = _getSafeString(
      session['enseignantName'],
      'Enseignant non spécifié',
    );

    // Récupérer l'index de l'icône depuis les données de la session
    final iconIndex = _getSafeInt(session['iconIndex'], 0);
    final sessionIcon = classIcons[iconIndex.clamp(0, classIcons.length - 1)];

    DateTime date;
    try {
      final dateTimestamp = session['dateDebut'];
      if (dateTimestamp is Timestamp) {
        date = dateTimestamp.toDate();
      } else {
        date = DateTime.now();
      }
    } catch (e) {
      date = DateTime.now();
    }

    final startTime = _getSafeString(session['horaireDebut'], '');
    final endTime = _getSafeString(session['horaireFin'], '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Carte principale avec effet 3D
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Partie gauche : Contenu principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête avec titre
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icône de session (utilise l'icône sauvegardée)
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primaryColor, _secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                sessionIcon, // Utilise l'icône spécifique de la session
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 10),

                            // Titre et classe
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: _textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    className,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _hintColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Informations compactes
                        Row(
                          children: [
                            // Enseignant
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 14,
                                    color: _primaryColor,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      teacherName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),

                            // Date
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: _secondaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM').format(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        // Horaire et étudiants
                        Row(
                          children: [
                            // Horaire
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: _hintColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '$startTime - $endTime',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            Spacer(),

                            // Nombre d'étudiants
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 10,
                                    color: _accentColor,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    studentCount.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Partie droite : Boutons d'action en icônes 3D
                  SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bouton Modifier
                      _buildIconButton3D(
                        Icons.edit_rounded,
                        _primaryColor,
                        () => _editSession(session),
                      ),

                      // Bouton Supprimer (seulement en mode suppression)
                      if (_isDeleteMode)
                        _buildIconButton3D(
                          Icons.delete_rounded,
                          _dangerColor,
                          () => _showDeleteConfirmation(
                            session['id'] ?? '',
                            sessionName,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton3D(
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  // Méthodes utilitaires pour la gestion sécurisée des données
  String _getSafeString(dynamic value, String defaultValue) {
    try {
      if (value == null) return defaultValue;
      return value.toString();
    } catch (e) {
      return defaultValue;
    }
  }

  int _getSafeInt(dynamic value, int defaultValue) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      if (value is double) return value.toInt();
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 35,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune séance',
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première séance',
              style: TextStyle(color: _hintColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Chargement...',
            style: TextStyle(color: _hintColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header compact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Bouton de retour
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: 18,
                            color: _textColor,
                          ),
                          padding: EdgeInsets.zero,
                          splashRadius: 20,
                        ),
                      ),
                      SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'Séances',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                          ),
                        ),
                      ),
                      if (_isDeleteMode)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _dangerColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Suppression',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barre de recherche compacte
                  Container(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: _textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: TextStyle(color: _hintColor),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: _hintColor,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 16,
                                  color: _hintColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _filteredSessions = _allSessions;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) => setState(() {
                        _searchQuery = value;
                        _filteredSessions = _filterSessions(_allSessions);
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Boutons d'action compacts
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isDeleteMode = !_isDeleteMode;
                              });
                            },
                            icon: Icon(
                              _isDeleteMode
                                  ? Icons.cancel_outlined
                                  : Icons.delete_outline_rounded,
                              size: 16,
                            ),
                            label: Text(
                              _isDeleteMode ? 'Annuler' : 'Supprimer',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isDeleteMode
                                  ? _dangerColor
                                  : _textColor,
                              side: BorderSide(
                                color: _isDeleteMode
                                    ? _dangerColor
                                    : _borderColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminCreateClassPage(
                                    adminName: widget.userName,
                                    adminUid: widget.userUid,
                                  ),
                                ),
                              );
                            },
                            icon: Icon(Icons.add_rounded, size: 16),
                            label: Text('Nouvelle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Liste des séances
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredSessions.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: _filteredSessions
                          .map((session) => _buildSessionCard(session))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
