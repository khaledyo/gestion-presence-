// lib/pages/admin_export_attendance_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class AdminExportAttendancePage extends StatefulWidget {
  final String userName;
  final String userUid;

  const AdminExportAttendancePage({
    Key? key,
    required this.userName,
    required this.userUid,
  }) : super(key: key);

  @override
  State<AdminExportAttendancePage> createState() => _AdminExportAttendancePageState();
}

class _AdminExportAttendancePageState extends State<AdminExportAttendancePage> {
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _students = [];
  List<String> _subjects = [];
  Map<String, Map<String, int>> _absenceData = {};
  bool _isLoading = false;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _loadClasses();
    final now = DateTime.now();
    _selectedStartDate = DateTime(now.year, now.month, 1);
    _selectedEndDate = now;
  }

  Future<void> _loadClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .orderBy('name')
          .get();

      setState(() {
        _classes = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Sans nom',
            'level': data['level'] ?? 'Non spécifié',
            ...data
          };
        }).toList();
      });
    } catch (e) {
      _showMessage('Erreur chargement classes: $e', isError: true);
    }
  }

  Future<void> _loadClassData(String classId) async {
    if (classId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _selectedClassId = classId;
      _selectedClass = _classes.firstWhere((c) => c['id'] == classId);
    });

    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('school_classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        _showMessage('Classe non trouvée', isError: true);
        return;
      }

      final classData = classDoc.data()!;
      final studentUids = (classData['studentUids'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList();

      final students = await _loadStudentsData(studentUids);
      final subjectsData = await _loadSubjectsAndAbsences(classId, studentUids, students);

      setState(() {
        _students = students;
        _subjects = subjectsData['subjects'];
        _absenceData = subjectsData['absenceData'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Erreur chargement données: $e', isError: true);
    }
  }

  Future<List<Map<String, dynamic>>> _loadStudentsData(List<String> studentUids) async {
    if (studentUids.isEmpty) return [];

    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: studentUids)
          .get();

      return usersSnapshot.docs.map((doc) {
        final userData = doc.data();
        return {
          'id': doc.id,
          'name': userData['nom'] ?? userData['name'] ?? 'Sans nom',
          'email': userData['email'] ?? 'Sans email',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadSubjectsAndAbsences(
      String classId, List<String> studentUids, List<Map<String, dynamic>> students) async {
    final subjects = <String>[];
    final absenceData = <String, Map<String, int>>{};

    try {
      final className = _selectedClass?['name'];

      QuerySnapshot snapshot1 = await FirebaseFirestore.instance
          .collection('attendance_history')
          .where('schoolClass', isEqualTo: className)
          .get();

      QuerySnapshot snapshot2 = await FirebaseFirestore.instance
          .collection('attendance_history')
          .where('className', isEqualTo: className)
          .get();

      final allDocs = <QueryDocumentSnapshot>[];
      allDocs.addAll(snapshot1.docs);

      for (final doc in snapshot2.docs) {
        if (!allDocs.any((d) => d.id == doc.id)) {
          allDocs.add(doc);
        }
      }

      for (final doc in allDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final subject = data['className'] ?? data['schoolClass'];

        if (subject == null) continue;

        final date = (data['date'] as Timestamp?)?.toDate();
        if (date != null &&
            (_selectedStartDate != null &&
                _selectedEndDate != null &&
                (date.isBefore(_selectedStartDate!) ||
                    date.isAfter(_selectedEndDate!)))) {
          continue;
        }

        if (!subjects.contains(subject)) subjects.add(subject);

        if (!absenceData.containsKey(subject)) {
          absenceData[subject] = {};
        }

        final absentStudents = data['absentStudents'] as List<dynamic>? ?? [];
        for (final student in absentStudents) {
          if (student is Map<String, dynamic>) {
            final uid = student['uid'];
            if (uid != null && studentUids.contains(uid)) {
              absenceData[subject]![uid] = (absenceData[subject]![uid] ?? 0) + 1;
            }
          }
        }
      }

      for (final subject in subjects) {
        for (final student in students) {
          final id = student['id'];
          absenceData[subject]![id] = absenceData[subject]![id] ?? 0;
        }
      }
    } catch (e) {}

    return {
      'subjects': subjects,
      'absenceData': absenceData,
    };
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate!,
        end: _selectedEndDate!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
      });

      if (_selectedClassId != null) {
        _loadClassData(_selectedClassId!);
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_selectedClass == null || _students.isEmpty) {
      _showMessage('Veuillez sélectionner une classe avec des étudiants', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdf = await _generatePDF();
      await Printing.layoutPdf(
        onLayout: (format) => pdf,
      );
      _showMessage('PDF généré avec succès!');
    } catch (e) {
      _showMessage('Erreur génération PDF: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: pw.TextStyle(fontSize: 10),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Généré le ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
            style: pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          _buildTitleSection(),
          _buildClassInfoSection(),
          _buildPeriodSection(),
          _buildStatisticsSection(),
          _buildAttendanceTable(),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildTitleSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RAPPORT DES ABSENCES PAR MATIÈRE',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Système de Gestion des Présences',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildClassInfoSection() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Classe : ${_selectedClass?['name']}',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Niveau : ${_selectedClass?['level']}',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  pw.Widget _buildPeriodSection() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Période : ${dateFormat.format(_selectedStartDate!)} - ${dateFormat.format(_selectedEndDate!)}',
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  pw.Widget _buildStatisticsSection() {
    int totalAbsences = 0;
    int maxAbs = 0;
    String worst = 'Aucun';

    for (final student in _students) {
      int count = 0;
      for (final subject in _subjects) {
        count += _absenceData[subject]?[student['id']] ?? 0;
      }
      totalAbsences += count;
      if (count > maxAbs) {
        maxAbs = count;
        worst = student['name'];
      }
    }

    final avg = _students.isNotEmpty ? totalAbsences / _students.length : 0;

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total Absences : $totalAbsences'),
            pw.Text('Moyenne par étudiant : ${avg.toStringAsFixed(1)}'),
            pw.Text('Plus absent : $worst ($maxAbs)'),
          ],
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  pw.Widget _buildAttendanceTable() {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: pw.FixedColumnWidth(30), // N°
        1: pw.FlexColumnWidth(3), // Étudiant
        for (int i = 0; i < _subjects.length; i++)
          i + 2: pw.FixedColumnWidth(60), // Augmenté de 40 à 60 pour les matières
        _subjects.length + 2: pw.FixedColumnWidth(50), // Total
      },
      children: [
        _buildHeaderRow(),
        for (int i = 0; i < _students.length; i++)
          _buildStudentRow(_students[i], i + 1),
      ],
    );
  }

  pw.TableRow _buildHeaderRow() {
    return pw.TableRow(
      children: [
        _cell('N°', bold: true, center: true),
        _cell('Étudiant', bold: true),
        for (final subject in _subjects)
          _cell(_abbrev(subject), bold: true, center: true),
        _cell('Total', bold: true, center: true),
      ],
    );
  }

  pw.TableRow _buildStudentRow(Map<String, dynamic> student, int n) {
    int total = 0;
    for (final subject in _subjects) {
      total += _absenceData[subject]?[student['id']] ?? 0;
    }

    return pw.TableRow(
      children: [
        _cell(n.toString(), center: true),
        _cell(student['name']),
        for (final subject in _subjects)
          _buildAbsenceCell(_absenceData[subject]?[student['id']] ?? 0),
        _buildTotalCell(total),
      ],
    );
  }

  // Nouvelle méthode pour les cellules d'absence avec couleur conditionnelle
  pw.Widget _buildAbsenceCell(int absenceCount) {
    final text = absenceCount.toString();
    final shouldColorRed = absenceCount >= 4;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          color: shouldColorRed ? PdfColors.red : PdfColors.black,
        ),
      ),
    );
  }

  // Nouvelle méthode pour la cellule de total avec couleur conditionnelle
  pw.Widget _buildTotalCell(int total) {
    final text = total.toString();
    final shouldColorRed = total >= 4;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: shouldColorRed ? PdfColors.red : PdfColors.black,
        ),
      ),
    );
  }

  String _abbrev(String text) {
    if (text.length <= 10) return text;
    final parts = text.split(' ');
    if (parts.length > 1) {
      return parts.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    }
    return text.substring(0, 10).toUpperCase();
  }

  pw.Widget _cell(String text, {bool bold = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Export des Présences PDF",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black26,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 10,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sélection de la classe avec effet 3D
                _build3DCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Sélection de la Classe', Icons.group),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          decoration: InputDecoration(
                            labelText: 'Choisir une classe',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                          dropdownColor: Colors.white,
                          items: _classes.map((classData) {
                            return DropdownMenuItem<String>(
                              value: classData['id'],
                              child: Text(
                                '${classData['name']} - ${classData['level']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              _loadClassData(newValue);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Sélection de la période avec effet 3D
                _build3DCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Période d\'Analyse', Icons.calendar_today),
                      SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white, Colors.grey.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDateInfo(
                                  'Date de début',
                                  DateFormat('dd/MM/yyyy').format(_selectedStartDate!),
                                  Colors.green,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey.shade300,
                              ),
                              Expanded(
                                child: _buildDateInfo(
                                  'Date de fin',
                                  DateFormat('dd/MM/yyyy').format(_selectedEndDate!),
                                  Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: _build3DButton(
                          onPressed: _selectDateRange,
                          icon: Icons.date_range,
                          label: 'Modifier la période',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Bouton d'export avec effet 3D
                Center(
                  child: _isLoading
                      ? _build3DLoading()
                      : _build3DButton(
                    onPressed: _exportToPDF,
                    icon: Icons.picture_as_pdf,
                    label: 'Générer le Rapport PDF',
                    color: Colors.green,
                    isLarge: true,
                  ),
                ),

                SizedBox(height: 20),

                // Aperçu des données avec effet 3D
                if (_selectedClass != null && _students.isNotEmpty)
                  _build3DCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          'Aperçu des Données \n'
                              '(${_students.length} étudiants)',
                          Icons.preview,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Classe: ${_selectedClass!['name']} | Niveau: ${_selectedClass!['level']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          height: 400,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: DataTable(
                                  headingRowColor: MaterialStateProperty.resolveWith(
                                        (states) => Colors.blue.shade50,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.white, Colors.grey.shade50],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: _buildTableHeader('N°'),
                                    ),
                                    DataColumn(
                                      label: _buildTableHeader('Étudiant'),
                                    ),
                                    ..._subjects.map((subject) => DataColumn(
                                      label: Tooltip(
                                        message: subject,
                                        child: _buildTableHeader(
                                          _abbrev(subject),
                                          center: true,
                                        ),
                                      ),
                                    )),
                                    DataColumn(
                                      label: _buildTableHeader('Total', center: true),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: _students.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final student = entry.value;
                                    int total = 0;
                                    for (final subject in _subjects) {
                                      total += _absenceData[subject]?[student['id']] ?? 0;
                                    }

                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<Color?>(
                                            (Set<MaterialState> states) {
                                          if (index.isEven) {
                                            return Colors.grey.shade50;
                                          }
                                          return Colors.white;
                                        },
                                      ),
                                      cells: [
                                        DataCell(_buildTableCell('${index + 1}')),
                                        DataCell(_buildTableCell(student['name'])),
                                        ..._subjects.map((subject) {
                                          final absenceCount = _absenceData[subject]?[student['id']] ?? 0;
                                          return DataCell(
                                            Center(
                                              child: _buildTableCell(
                                                absenceCount.toString(),
                                                center: true,
                                                isNumber: true,
                                                value: absenceCount,
                                                isAlert: absenceCount >= 4, // Alerte si 4+ absences
                                              ),
                                            ),
                                          );
                                        }),
                                        DataCell(
                                          _buildTableCell(
                                            total.toString(),
                                            center: true,
                                            isTotal: true,
                                            value: total,
                                            isAlert: total >= 4, // Alerte si 4+ absences total
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
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
    );
  }

  Widget _build3DCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(4, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Icon(
            icon,
            color: Colors.blue[700],
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black12,
                offset: Offset(1.0, 1.0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(String label, String date, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _build3DButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isLarge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLarge ? 32 : 20,
              vertical: isLarge ? 16 : 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: isLarge ? 24 : 20,
                ),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 16 : 14,
                    shadows: [
                      Shadow(
                        blurRadius: 2.0,
                        color: Colors.black26,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DLoading() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            strokeWidth: 3,
          ),
          SizedBox(height: 12),
          Text(
            'Génération du PDF...',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {bool center = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {
    bool center = false,
    bool isNumber = false,
    bool isTotal = false,
    int value = 0,
    bool isAlert = false, // Nouveau paramètre pour l'alerte
  }) {
    Color textColor = Colors.black;

    if (isAlert) {
      textColor = Colors.red; // Rouge pour les alertes (4+ absences)
    } else if (isTotal) {
      textColor = value > 0 ? Colors.red : Colors.green;
    } else if (isNumber && value > 0) {
      textColor = Colors.orange.shade700;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          color: textColor,
          fontSize: 11,
        ),
      ),
    );
  }
}