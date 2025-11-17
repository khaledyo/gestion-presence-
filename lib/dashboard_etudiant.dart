// lib/pages/dashboard_etudiant.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'classes_list_page.dart';
import 'student_history_page.dart';
import 'student_profile_page.dart';

class DashboardEtudiant extends StatefulWidget {
  final String userName;
  final String userUid;

  const DashboardEtudiant({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<DashboardEtudiant> createState() => _DashboardEtudiantState();
}

class _DashboardEtudiantState extends State<DashboardEtudiant> {
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readNotifications = {};
  bool _isLoadingNotifications = true;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeNotifications();
  }

  void _loadNotifications() {
    _readNotifications = {};
  }

  void _setupRealtimeNotifications() {
    FirebaseFirestore.instance
        .collection('attendances')
        .where('isClosed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _processActiveSessions();
    });
  }

  Future<void> _processActiveSessions() async {
    try {
      setState(() {
        _isLoadingNotifications = true;
      });

      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('studentsUid', arrayContains: widget.userUid)
          .get();

      final List<Map<String, dynamic>> activeNotifications = [];

      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final classId = classDoc.id;

        final sessionsSnapshot = await FirebaseFirestore.instance
            .collection('attendances')
            .where('classId', isEqualTo: classId)
            .where('isClosed', isEqualTo: false)
            .get();

        for (final sessionDoc in sessionsSnapshot.docs) {
          final sessionData = sessionDoc.data();
          final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

          if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
            final teacherUid = classData['enseignantUid'];
            String teacherName = 'Enseignant';

            if (teacherUid != null) {
              final teacherDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(teacherUid)
                  .get();

              if (teacherDoc.exists) {
                final teacherData = teacherDoc.data();
                teacherName = teacherData?['nom'] ?? teacherData?['name'] ?? 'Enseignant';
              }
            }

            final remainingMinutes = expiresAt.difference(DateTime.now()).inMinutes;
            final notificationId = '${classId}_${sessionDoc.id}';

            final createdAt = (sessionData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final isNew = DateTime.now().difference(createdAt).inMinutes < 5;

            activeNotifications.add({
              'id': notificationId,
              'classId': classId,
              'className': classData['nom'] ?? 'Cours sans nom',
              'teacherName': teacherName,
              'sessionId': sessionDoc.id,
              'expiresAt': expiresAt,
              'remainingTime': remainingMinutes,
              'createdAt': createdAt,
              'isNew': isNew && !_readNotifications.contains(notificationId),
              'sessionCode': sessionData['sessionCode'] ?? '',
            });
          }
        }
      }

      activeNotifications.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

      setState(() {
        _notifications = activeNotifications;
        _isLoadingNotifications = false;
      });

    } catch (e) {
      print('Erreur chargement notifications: $e');
      setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  void _markAsRead(String notificationId) {
    setState(() {
      _readNotifications.add(notificationId);
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['isNew'] = false;
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        _readNotifications.add(notification['id']);
        notification['isNew'] = false;
      }
    });
  }

  // BADGE DE NOTIFICATION - Cercle et positionné plus haut
  Widget _buildNotificationBadge(int count) {
    if (count == 0) return const SizedBox.shrink();

    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: errorColor,
          shape: BoxShape.circle,
          border: Border.all(color: surfaceColor, width: 0.2),
          boxShadow: [
            BoxShadow(
              color: errorColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(
          minWidth: 17,
          minHeight: 17,
        ),
        child: Center(
          child: Text(
            count > 9 ? '9+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  int get _unreadNotificationCount {
    return _notifications.where((notification) => notification['isNew'] == true).length;
  }

  void _openNotificationsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationsPanel(),
    );
  }

  // PANEL DE NOTIFICATIONS MODERNE
  Widget _buildNotificationsPanel() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendances')
          .where('isClosed', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _processActiveSessions();
          });
        }

        final unreadCount = _unreadNotificationCount;
        final totalNotifications = _notifications.length;

        return Container(
          height: MediaQuery.of(context).size.height * 0.73,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 42),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // POIGNÉE DRAGGABLE
              Container(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // EN-TÊTE AVEC TITRE ET ACTIONS
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Sessions Actives',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (totalNotifications > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          totalNotifications.toString(),
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const Spacer(),

                    if (unreadCount > 0)
                      TextButton(
                        onPressed: _markAllAsRead,
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Tout lire',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
              ),

              // LISTE DES NOTIFICATIONS
              Expanded(
                child: _isLoadingNotifications
                    ? _buildLoadingNotifications()
                    : _notifications.isEmpty
                    ? _buildEmptyNotifications()
                    : _buildNotificationsList(),
              ),

              // PIED DE PAGE
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: const Text('Fermer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassesListPage(userUid: widget.userUid),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Scanner'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des sessions...',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded,
              size: 80, color: textSecondary.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'Aucune session en cours',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Revenez quand vos enseignants\nactiveront les sessions de présence',
            style: TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClassesListPage(userUid: widget.userUid),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Voir mes cours'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        final isNew = notification['isNew'] == true;

        return _buildNotificationItem(notification, isNew);
      },
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, bool isNew) {
    final remainingTime = notification['remainingTime'] as int;
    final isExpiringSoon = remainingTime < 10;
    final isUrgent = remainingTime < 3;

    Color statusColor = successColor;
    String statusText = 'Disponible';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (isUrgent) {
      statusColor = errorColor;
      statusText = 'Dernières minutes!';
      statusIcon = Icons.error_outline_rounded;
    } else if (isExpiringSoon) {
      statusColor = warningColor;
      statusText = 'Bientôt terminé';
      statusIcon = Icons.access_time_rounded;
    }

    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        onTap: () {
          _markAsRead(notification['id']);
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassesListPage(userUid: widget.userUid),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isNew ? primaryColor.withOpacity(0.3) : Colors.transparent,
              width: isNew ? 2 : 0,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.qr_code_rounded,
                        color: primaryColor, size: 24),
                  ),
                  if (isNew)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: errorColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: surfaceColor, width: .8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification['className'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Prof. ${notification['teacherName']}',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(statusIcon, color: statusColor, size: 16),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: remainingTime,
                            child: Container(
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 15 - remainingTime.clamp(0, 15),
                            child: const SizedBox(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          '$statusText • $remainingTime min',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                      ],
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

  Stream<String?> getProfilePictureStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userUid)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final userData = snapshot.data() as Map<String, dynamic>;
        return userData['profilePicture'] as String?;
      }
      return null;
    });
  }

  Widget _buildDefaultProfileAvatar(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        color: primaryColor,
        size: isSmallScreen ? 18 : 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildActionsGrid(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
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
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentProfilePage(
                      userUid: widget.userUid,
                      userName: widget.userName,
                      userEmail: '',
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    StreamBuilder<String?>(
                      stream: getProfilePictureStream(),
                      builder: (context, snapshot) {
                        final profilePictureUrl = snapshot.data;

                        return Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                                ? Image.network(
                              profilePictureUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultProfileAvatar(true);
                              },
                            )
                                : _buildDefaultProfileAvatar(true),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Étudiant",
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _openNotificationsPanel(context),
                    icon: Icon(
                        Icons.notifications_outlined,
                        color: primaryColor,
                        size: 22
                    ),
                    tooltip: 'Sessions actives',
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                _buildNotificationBadge(_unreadNotificationCount),
              ],
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: IconButton(
              onPressed: () {
                _showLogoutConfirmation(context);
              },
              icon: Icon(
                  Icons.logout_rounded,
                  color: textSecondary,
                  size: 20
              ),
              tooltip: 'Déconnexion',
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: errorColor),
            const SizedBox(width: 8),
            Text(
              'Déconnexion',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(color: textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, 'login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  // SECTION WELCOME AVEC DESIGN 3D
  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.08),
            secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 20,
            offset: const Offset(-4, -4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // ICONE AVEC EFFET 3D
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withOpacity(0.2),
                  secondaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 15,
                  offset: const Offset(-4, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Effet de lumière
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.waving_hand_rounded,
                    color: primaryColor,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bon retour ${widget.userName.split(' ').first}!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Prêt à scanner vos présences ?",
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
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

  // GRILLE D'ACTIONS AVEC DESIGN 3D NÉOMORPHE
  Widget _buildActionsGrid(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      children: [
        _build3DActionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: "Scanner\nQR Code",
          subtitle: "Marquer présence",
          color: primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClassesListPage(userUid: widget.userUid),
              ),
            );
          },
        ),
        _build3DActionCard(
          icon: Icons.history_rounded,
          title: "Historique\nde présence",
          subtitle: "Voir mes statistiques",
          color: successColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentHistoryPage(
                  userUid: widget.userUid,
                  userName: widget.userName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // CARTE D'ACTION AVEC EFFET 3D NÉOMORPHE
  Widget _build3DActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              surfaceColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Ombre externe pour effet 3D
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(8, 8),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.9),
              blurRadius: 20,
              offset: const Offset(-8, -8),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Effet de lumière en arrière-plan
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ICONE AVEC EFFET 3D
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(4, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: const Offset(-4, -4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Reflet de lumière
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            icon,
                            color: color,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                      height: 1.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 2,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // BOUTON FLOTTANT 3D
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.2),
                            color.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 6,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: color,
                        size: 16,
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
  }
}