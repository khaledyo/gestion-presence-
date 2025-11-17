// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final String userUid;

  NotificationService(this.userUid);

  // Stream pour les notifications en temps réel
  Stream<List<Map<String, dynamic>>> getActiveSessionsStream() {
    return FirebaseFirestore.instance
        .collection('classes')
        .where('studentsUid', arrayContains: userUid)
        .snapshots()
        .asyncMap((classesSnapshot) async {
      final notifications = <Map<String, dynamic>>[];

      for (final classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final classId = classDoc.id;

        // Vérifier s'il y a une session active
        final sessionSnapshot = await FirebaseFirestore.instance
            .collection('attendances')
            .where('classId', isEqualTo: classId)
            .where('isClosed', isEqualTo: false)
            .get();

        for (final sessionDoc in sessionSnapshot.docs) {
          final sessionData = sessionDoc.data();
          final expiresAt = (sessionData['expiresAt'] as Timestamp?)?.toDate();

          // Vérifier si la session n'est pas expirée
          if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {

            // Récupérer les informations de l'enseignant
            final teacherUid = classData['enseignantUid'];
            String teacherName = 'Enseignant';

            if (teacherUid != null) {
              final teacherDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(teacherUid)
                  .get();

              if (teacherDoc.exists) {
                final teacherData = teacherDoc.data();
                teacherName = teacherData?['nom'] ?? 'Enseignant';
              }
            }

            notifications.add({
              'id': '${classId}_${sessionDoc.id}',
              'classId': classId,
              'className': classData['nom'] ?? 'Cours sans nom',
              'teacherName': teacherName,
              'sessionId': sessionDoc.id,
              'expiresAt': expiresAt,
              'remainingTime': expiresAt.difference(DateTime.now()).inMinutes,
              'timestamp': DateTime.now(),
            });
          }
        }
      }

      return notifications;
    });
  }

  // Marquer une notification comme lue
  static Future<void> markAsRead(String notificationId) async {
    // Vous pouvez stocker les IDs des notifications lues localement
    // ou dans Firestore si vous voulez les synchroniser entre appareils
  }
}