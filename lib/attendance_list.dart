import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

const Color primaryColor = Color(0xFF1A237E);

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

  @override
  void initState() {
    super.initState();
    _initializeAttendanceSession();
  }

  Future<void> _initializeAttendanceSession() async {
    try {
      // Vérifier si une session de présence est déjà ouverte pour cette classe
      final existingSession = await FirebaseFirestore.instance
          .collection('attendances')
          .where('classId', isEqualTo: widget.classId)
          .where('isClosed', isEqualTo: false)
          .limit(1)
          .get();

      if (existingSession.docs.isNotEmpty) {
        // Session existante trouvée
        sessionId = existingSession.docs.first.id;
      } else {
        // Créer une nouvelle session
        sessionId = "${widget.classId}_${DateTime.now().millisecondsSinceEpoch}";
        await FirebaseFirestore.instance
            .collection('attendances')
            .doc(sessionId)
            .set({
          'classId': widget.classId,
          'className': widget.classData['nom'],
          'date': Timestamp.now(),
          'presentStudentsUid': [],
          'isClosed': false,
        });
      }

      await _loadStudents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'initialisation: $e")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur chargement étudiants: $e")),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Présence enregistrée (${presentStudents.length}/${enrolledStudents.length})'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde: $e")),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text(widget.classData['nom'] ?? 'Session de présence'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
        stream: getAttendanceStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final presentUids =
          List<String>.from(data['presentStudentsUid'] ?? []);
          final isClosed = data['isClosed'] ?? false;

          for (var s in enrolledStudents) {
            if (presentUids.contains(s.uid)) {
              attendanceStatus[s.uid] = true;
            }
          }

          final presentCount =
              attendanceStatus.values.where((v) => v).length;
          final absentCount = enrolledStudents.length - presentCount;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(presentCount, absentCount),
                const SizedBox(height: 16),
                if (!isClosed) _buildQrCodeSection(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, index) {
                      final student = filteredStudents[index];
                      final isPresent =
                          attendanceStatus[student.uid] ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: isPresent
                            ? Colors.green[50]
                            : Colors.red[50],
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPresent
                                ? Colors.green
                                : Colors.redAccent,
                            child: Icon(
                                isPresent
                                    ? Icons.check
                                    : Icons.close,
                                color: Colors.white),
                          ),
                          title: Text(student.fullName),
                          subtitle:
                          Text('Email: ${student.studentIdentifier}'),
                          trailing: TextButton(
                            onPressed: isClosed
                                ? null
                                : () => _toggleStudent(
                                student.uid, !isPresent),
                            child: Text(
                              isPresent ? 'Présent' : 'Absent',
                              style: TextStyle(
                                  color: isPresent
                                      ? Colors.green
                                      : Colors.redAccent),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed:
                  isClosed ? null : _saveAndCloseSession,
                  icon: Icon(
                    isClosed ? Icons.lock : Icons.save,
                    color: Colors.white,
                  ),
                  label: Text(
                    isClosed
                        ? 'Session Clôturée'
                        : 'Enregistrer et Clôturer',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(int presentCount, int absentCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Classe : ${widget.classData['nom']}",
          style: const TextStyle(
              color: primaryColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statusDot(Colors.green, "Présents: $presentCount"),
            const SizedBox(width: 12),
            _statusDot(Colors.red, "Absents: $absentCount"),
            const SizedBox(width: 12),
            _statusDot(Colors.grey, "Total: ${enrolledStudents.length}"),
          ],
        ),
      ],
    );
  }

  Widget _buildQrCodeSection() {
    return Column(
      children: [
        const Text(
          'QR Code de présence (scanné par les étudiants)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor, width: 2),
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
          sessionId != null
              ? "Session ID: ${sessionId!.substring(0, 10)}..."
              : "",
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: primaryColor),
        hintText: 'Rechercher un étudiant...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: (val) => setState(() => searchQuery = val),
    );
  }

  Widget _statusDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        ),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}
