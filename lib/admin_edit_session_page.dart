import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AdminEditSessionPage extends StatefulWidget {
  final String adminName;
  final String adminUid;
  final String sessionId;
  final Map<String, dynamic> initialData;

  const AdminEditSessionPage({
    super.key,
    required this.adminName,
    required this.adminUid,
    required this.sessionId,
    required this.initialData,
  });

  @override
  State<AdminEditSessionPage> createState() => _AdminEditSessionPageState();
}

class _AdminEditSessionPageState extends State<AdminEditSessionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _jourCtrl = TextEditingController();
  final TextEditingController _heureDebutCtrl = TextEditingController();
  final TextEditingController _heureFinCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  bool _isSaving = false;
  bool _isLoadingTeachers = true;
  int _selectedIconIndex = 0;

  List<EnseignantSelection> allTeachers = [];
  EnseignantSelection? _selectedTeacher;
  StreamSubscription<QuerySnapshot>? _teachersSubscription;

  final Color _primaryColor = const Color(0xFF1A237E);
  final Color _backgroundColor = const Color(0xFFF8FAFD);
  final Color _surfaceColor = Colors.white;
  final Color _textColor = const Color(0xFF2D3748);
  final Color _hintColor = const Color(0xFF718096);
  final Color _borderColor = const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchTeachers();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _teachersSubscription?.cancel();
    super.dispose();
  }

  void _initializeData() {
    // Pré-remplir les données existantes
    _nomCtrl.text = widget.initialData['nom'] ?? '';

    // Date
    if (widget.initialData['dateDebut'] != null) {
      final dateDebut = (widget.initialData['dateDebut'] as Timestamp).toDate();
      _selectedDate = dateDebut;
      _jourCtrl.text = DateFormat('dd/MM/yyyy').format(dateDebut);
    }

    // Heures
    _heureDebutCtrl.text = widget.initialData['horaireDebut'] ?? '';
    _heureFinCtrl.text = widget.initialData['horaireFin'] ?? '';

    // Icône
    _selectedIconIndex = widget.initialData['iconIndex'] ?? 0;
  }

  void _setupRealtimeListener() {
    _teachersSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Enseignant')
        .orderBy('nom')
        .snapshots()
        .listen((snapshot) {
      _updateTeachersFromSnapshot(snapshot);
    });
  }

  void _updateTeachersFromSnapshot(QuerySnapshot snapshot) {
    final updatedTeachers = <EnseignantSelection>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final teacherName = data['nom'] ?? 'Enseignant sans nom';
      final teacherEmail = data['email'] ?? '';

      final isCurrentTeacher = doc.id == widget.initialData['enseignantUid'];

      updatedTeachers.add(EnseignantSelection(
        id: doc.id,
        name: teacherName,
        email: teacherEmail,
        isSelected: isCurrentTeacher,
      ));

      if (isCurrentTeacher && _selectedTeacher == null) {
        _selectedTeacher = updatedTeachers.last;
      }
    }

    if (mounted) {
      setState(() {
        allTeachers = updatedTeachers;
        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      setState(() {
        _isLoadingTeachers = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Enseignant')
          .orderBy('nom')
          .get();

      _updateTeachersFromSnapshot(snapshot);

    } catch (e) {
      print('Erreur chargement enseignants: $e');
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  Future<void> _selectDay() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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
    });
  }

  Future<void> _selectStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? TimeOfDay.now(),
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
      initialTime: _selectedEndTime ?? _selectedStartTime!,
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

  Future<void> _updateSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _heureDebutCtrl.text.isEmpty || _heureFinCtrl.text.isEmpty) {
      _showSnackBar('Veuillez choisir la date et les horaires.');
      return;
    }

    if (_selectedTeacher == null) {
      _showSnackBar('Veuillez sélectionner un enseignant.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Convertir les heures en DateTime pour Firestore
      final startParts = _heureDebutCtrl.text.split(' ');
      final startTimeParts = startParts[0].split(':');
      final isStartPM = startParts.length > 1 && startParts[1].toUpperCase() == 'PM';

      final endParts = _heureFinCtrl.text.split(' ');
      final endTimeParts = endParts[0].split(':');
      final isEndPM = endParts.length > 1 && endParts[1].toUpperCase() == 'PM';

      int startHour = int.parse(startTimeParts[0]);
      int startMinute = int.parse(startTimeParts[1]);
      int endHour = int.parse(endTimeParts[0]);
      int endMinute = int.parse(endTimeParts[1]);

      // Convertir en format 24h
      if (isStartPM && startHour < 12) startHour += 12;
      if (isEndPM && endHour < 12) endHour += 12;

      final dateDebut = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        startHour,
        startMinute,
      );

      final dateFin = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        endHour,
        endMinute,
      );

      final updateData = {
        'nom': _nomCtrl.text.trim(),
        'jour': DateFormat('dd/MM/yyyy').format(_selectedDate!),
        'dateDebut': Timestamp.fromDate(dateDebut),
        'dateFin': Timestamp.fromDate(dateFin),
        'horaireDebut': _heureDebutCtrl.text,
        'horaireFin': _heureFinCtrl.text,
        'iconIndex': _selectedIconIndex,
        'enseignantUid': _selectedTeacher!.id,
        'enseignantName': _selectedTeacher!.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByAdmin': true,
        'adminUid': widget.adminUid,
        'adminName': widget.adminName,
      };

      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.sessionId)
          .update(updateData);

      setState(() => _isSaving = false);

      if (mounted) {
        _showSnackBar('Séance modifiée avec succès ✅');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Erreur lors de la modification: $e');
    }
  }

  Widget _buildTeacherCard(EnseignantSelection teacher) {
    final isSelected = _selectedTeacher?.id == teacher.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? _primaryColor.withOpacity(0.05) : _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () => setState(() => _selectedTeacher = teacher),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : _backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(teacher.name),
                      style: TextStyle(
                        color: isSelected ? Colors.white : _primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? _primaryColor : _textColor,
                        ),
                      ),
                      Text(
                        teacher.email,
                        style: TextStyle(
                          color: isSelected ? _primaryColor.withOpacity(0.8) : _hintColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      return name.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Modifier la Séance',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _surfaceColor,
        foregroundColor: _textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations de base
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
                        const SizedBox(height: 16),
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
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sélection de l'enseignant
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
                          'Enseignant assigné',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedTeacher != null)
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
                                        _selectedTeacher!.name,
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _selectedTeacher!.email,
                                        style: TextStyle(
                                          color: _primaryColor.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        _isLoadingTeachers
                            ? Center(
                          child: CircularProgressIndicator(color: _primaryColor),
                        )
                            : Column(
                          children: allTeachers.map(_buildTeacherCard).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Bouton de sauvegarde
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _updateSession,
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
                        Icon(Icons.save_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Enregistrer les modifications',
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

class EnseignantSelection {
  final String id;
  final String name;
  final String email;
  bool isSelected;

  EnseignantSelection({
    required this.id,
    required this.name,
    required this.email,
    this.isSelected = false,
  });
}