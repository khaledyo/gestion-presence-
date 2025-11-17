import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

class SchoolClassSelection {
  final String id;
  final String name;
  final List<String> studentUids;
  bool isSelected;

  SchoolClassSelection({
    required this.id,
    required this.name,
    required this.studentUids,
    this.isSelected = false,
  });
}

class CreateClassPage extends StatefulWidget {
  final String enseignantUid;
  final String userName;

  const CreateClassPage({
    super.key,
    required this.enseignantUid,
    required this.userName,
  });

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _jourCtrl = TextEditingController();
  final TextEditingController _heureDebutCtrl = TextEditingController();
  final TextEditingController _heureFinCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  bool _isSaving = false;
  bool _isLoadingClasses = true;
  int _selectedIconIndex = 0;
  String searchClassQuery = '';

  List<SchoolClassSelection> allSchoolClasses = [];
  SchoolClassSelection? _selectedClass;
  StreamSubscription<QuerySnapshot>? _classesSubscription;

  // Couleurs modernes
  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _backgroundColor = const Color(0xFFF8FAFD);
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3748);
  final Color _hintColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

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
    _fetchSchoolClasses();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    _classesSubscription = FirebaseFirestore.instance
        .collection('school_classes')
        .snapshots()
        .listen((snapshot) {
      _updateClassesFromSnapshot(snapshot);
    });
  }

  void _updateClassesFromSnapshot(QuerySnapshot snapshot) {
    final updatedClasses = <SchoolClassSelection>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final className = data['name'] ?? 'Classe sans nom';

      List<String> studentUids = [];
      if (data['students'] != null && data['students'] is List) {
        studentUids = List<String>.from(data['students']);
      } else if (data['studentUids'] != null && data['studentUids'] is List) {
        studentUids = List<String>.from(data['studentUids']);
      }

      final wasSelected = allSchoolClasses
          .firstWhere((c) => c.id == doc.id,
          orElse: () => SchoolClassSelection(id: '', name: '', studentUids: []))
          .isSelected;

      updatedClasses.add(SchoolClassSelection(
        id: doc.id,
        name: className,
        studentUids: studentUids,
        isSelected: wasSelected,
      ));
    }

    if (mounted) {
      setState(() {
        allSchoolClasses = updatedClasses;
        if (_selectedClass != null) {
          _selectedClass = updatedClasses.firstWhere(
                (c) => c.id == _selectedClass!.id,
            orElse: () => _selectedClass!,
          );
        }
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _fetchSchoolClasses() async {
    try {
      setState(() {
        _isLoadingClasses = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('school_classes')
          .orderBy('name')
          .get();

      _updateClassesFromSnapshot(snapshot);

    } catch (e) {
      print('Erreur initiale: $e');
      if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    }
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // CORRECTION : Session de 15 minutes exactement
  Future<String> _generateInitialAttendanceSession(String classId, String className, DateTime dateDebut, DateTime dateFin) async {
    final now = DateTime.now();

    // VÉRIFIER SI ON EST DANS LES HORAIRES DU COURS
    final isDuringClass = now.isAfter(dateDebut) && now.isBefore(dateFin);

    if (!isDuringClass) {
      print('🕒 Hors horaire cours - Pas de session créée');
      return ""; // Retourner une chaîne vide si hors horaire
    }

    // CRÉER LA SESSION UNIQUEMENT SI DANS LES HORAIRES
    final sessionId = "${classId}_${DateTime.now().millisecondsSinceEpoch}";

    // CORRECTION : Toujours 15 minutes exactement
    final sessionEnd = now.add(Duration(minutes: 15));

    print('🕒 Création session depuis create_class: ${DateFormat('HH:mm').format(now)}');
    print('⏰ Expiration session: ${DateFormat('HH:mm').format(sessionEnd)}');
    print('⏱️ Durée totale: 15 minutes');

    await FirebaseFirestore.instance
        .collection('attendances')
        .doc(sessionId)
        .set({
      'classId': classId,
      'className': className,
      'createdAt': Timestamp.now(),
      'dateDebut': Timestamp.fromDate(dateDebut),
      'dateFin': Timestamp.fromDate(dateFin),
      'expiresAt': Timestamp.fromDate(sessionEnd), // ← CORRIGÉ : 15 minutes
      'presentStudentsUid': [],
      'isClosed': false,
      'sessionCode': _generateSessionCode(),
      'sessionDuration': 15, // Durée fixe de 15 minutes
    });

    return sessionId;
  }

  List<SchoolClassSelection> get filteredClasses {
    if (searchClassQuery.isEmpty) return allSchoolClasses;
    final query = searchClassQuery.toLowerCase();
    return allSchoolClasses
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  void _selectClass(SchoolClassSelection selectedClass) {
    setState(() {
      if (_selectedClass?.id == selectedClass.id) {
        _selectedClass = null;
        selectedClass.isSelected = false;
      } else {
        if (_selectedClass != null) {
          _selectedClass!.isSelected = false;
        }
        _selectedClass = selectedClass;
        selectedClass.isSelected = true;
      }
    });
  }

  Future<void> _selectDay() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _jourCtrl.text = DateFormat('dd/MM/yyyy').format(pickedDate);
      _heureDebutCtrl.clear();
      _heureFinCtrl.clear();
      _selectedStartTime = null;
      _selectedEndTime = null;
    });
  }

  Future<void> _selectStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedStartTime = pickedTime;
      _heureDebutCtrl.text = pickedTime.format(context);
    });
  }

  Future<void> _selectEndTime() async {
    if (_selectedStartTime == null) {
      _showSnackBar('Choisissez d\'abord l\'heure de début.');
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              surface: _surfaceColor,
              onSurface: _textColor,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;

    final startMinutes = _selectedStartTime!.hour * 60 + _selectedStartTime!.minute;
    final endMinutes = pickedTime.hour * 60 + pickedTime.minute;

    if (endMinutes <= startMinutes) {
      _showSnackBar('L\'heure de fin doit être postérieure à l\'heure de début.');
      return;
    }

    setState(() {
      _selectedEndTime = pickedTime;
      _heureFinCtrl.text = pickedTime.format(context);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _primaryColor,
      ),
    );
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedStartTime == null || _selectedEndTime == null) {
      _showSnackBar('Veuillez choisir la date, l\'heure de début et l\'heure de fin.');
      return;
    }

    if (_selectedClass == null) {
      _showSnackBar('Veuillez sélectionner une classe.');
      return;
    }

    setState(() => _isSaving = true);

    final dateDebut = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedStartTime!.hour,
      _selectedStartTime!.minute,
    );
    final dateFin = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedEndTime!.hour,
      _selectedEndTime!.minute,
    );

    try {
      // CORRECTION : Générer la session UNIQUEMENT si dans les horaires
      final sessionId = await _generateInitialAttendanceSession(
        _selectedClass!.id,
        _nomCtrl.text.trim(),
        dateDebut,
        dateFin,
      );

      final classData = {
        'nom': _nomCtrl.text.trim(),
        'jour': DateFormat('dd/MM/yyyy').format(_selectedDate!),
        'dateDebut': Timestamp.fromDate(dateDebut),
        'dateFin': Timestamp.fromDate(dateFin),
        'horaireDebut': _heureDebutCtrl.text,
        'horaireFin': _heureFinCtrl.text,
        'nombreEtudiants': _selectedClass!.studentUids.length,
        'iconIndex': _selectedIconIndex,
        'enseignantUid': widget.enseignantUid,
        'enseignantName': widget.userName,
        'studentsUid': _selectedClass!.studentUids,
        'schoolClass': _selectedClass!.name,
        'schoolClassId': _selectedClass!.id,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Ajouter l'ID de session seulement si créé
      if (sessionId.isNotEmpty) {
        classData['attendanceSessionId'] = sessionId;
      }

      await FirebaseFirestore.instance.collection('classes').add(classData);

      setState(() => _isSaving = false);
      if (mounted) {
        final now = DateTime.now();
        final isDuringClass = now.isAfter(dateDebut) && now.isBefore(dateFin);

        if (isDuringClass) {
          _showSnackBar('Séance créée avec succès 🎉 - QR Code activé');
        } else {
          _showSnackBar('Séance créée avec succès 🎉 - QR Code activera à l\'heure du cours');
        }
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Erreur lors de la création: $e');
    }
  }
  // ... (le reste du code reste identique - _buildIconPicker, _buildClassCard, build, etc.)
  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icône de la séance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: classIcons.length,
            itemBuilder: (context, index) {
              final selected = index == _selectedIconIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIconIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: selected ? _primaryColor.withOpacity(0.1) : _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? _primaryColor : _borderColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      classIcons[index],
                      color: selected ? _primaryColor : _hintColor,
                      size: 22,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(SchoolClassSelection schoolClass) {
    final isSelected = _selectedClass?.id == schoolClass.id;
    final hasStudents = schoolClass.studentUids.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () => _selectClass(schoolClass),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? _primaryColor : _borderColor,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: _primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolClass.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${schoolClass.studentUids.length} étudiant${schoolClass.studentUids.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: _hintColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasStudents ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasStudents ? 'Actif' : 'Vide',
                    style: TextStyle(
                      color: hasStudents ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Nouvelle Séance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _surfaceColor,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section informations de base
                Card(
                  elevation: 0,
                  color: _surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations de base',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nomCtrl,
                          style: TextStyle(color: _textColor),
                          decoration: InputDecoration(
                            labelText: 'Nom de la séance',
                            labelStyle: TextStyle(color: _hintColor),
                            filled: true,
                            fillColor: _backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _jourCtrl,
                          readOnly: true,
                          style: TextStyle(color: _textColor),
                          decoration: InputDecoration(
                            labelText: 'Date de la séance',
                            labelStyle: TextStyle(color: _hintColor),
                            filled: true,
                            fillColor: _backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onTap: _selectDay,
                          validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _heureDebutCtrl,
                                  readOnly: true,
                                  style: TextStyle(color: _textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Heure de début',
                                    labelStyle: TextStyle(color: _hintColor),
                                    filled: true,
                                    fillColor: _backgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: Icon(Icons.access_time, color: _primaryColor, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onTap: _selectStartTime,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _heureFinCtrl,
                                  readOnly: true,
                                  style: TextStyle(color: _textColor),
                                  decoration: InputDecoration(
                                    labelText: 'Heure de fin',
                                    labelStyle: TextStyle(color: _hintColor),
                                    filled: true,
                                    fillColor: _backgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: Icon(Icons.access_time, color: _primaryColor, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  onTap: _selectEndTime,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Section icône
                Card(
                  elevation: 0,
                  color: _surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildIconPicker(),
                  ),
                ),
                const SizedBox(height: 10),

                // Section sélection de classe
                Card(
                  elevation: 0,
                  color: _surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sélection de la classe',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.autorenew_rounded, size: 14, color: _primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Auto',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'La liste se met à jour automatiquement',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hintColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedClass != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _primaryColor, width: 2),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: _primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedClass!.name,
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        '${_selectedClass!.studentUids.length} étudiant${_selectedClass!.studentUids.length > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: _primaryColor.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: _primaryColor, size: 20),
                                  onPressed: () => setState(() => _selectedClass = null),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Rechercher une classe...',
                            labelStyle: TextStyle(color: _hintColor),
                            filled: true,
                            fillColor: _backgroundColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(Icons.search_rounded, color: _primaryColor, size: 20),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (v) => setState(() => searchClassQuery = v),
                        ),
                        const SizedBox(height: 16),

                        _isLoadingClasses
                            ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: _primaryColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Chargement en temps réel...',
                                  style: TextStyle(color: _hintColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                            : filteredClasses.isEmpty
                            ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: _hintColor),
                                const SizedBox(height: 8),
                                Text(
                                  'Aucune classe trouvée',
                                  style: TextStyle(color: _hintColor, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                            : Column(
                          children: [
                            ...filteredClasses.map(_buildClassCard),
                            if (filteredClasses.any((c) => c.studentUids.isEmpty))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Certaines classes n\'ont pas d\'étudiants',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
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
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveClass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Créer la séance',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}