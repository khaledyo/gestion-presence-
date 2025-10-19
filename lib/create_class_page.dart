import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modèle pour simplifier la gestion des étudiants dans l'état local
class StudentSelection {
  final String uid;
  final String fullName;
  bool isSelected;


  StudentSelection({required this.uid, required this.fullName, this.isSelected = false});
}

class CreateClassPage extends StatefulWidget {
  final String enseignantUid;
  const CreateClassPage({super.key, required this.enseignantUid});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _horaireCtrl = TextEditingController();

  List<StudentSelection> allStudents = [];
  String searchStudentQuery = '';
  bool _isLoadingStudents = true;
  bool _isSaving = false;

  int _selectedIconIndex = 0;

  final List<IconData> classIcons = const [

    Icons.school,
    Icons.menu_book,
    Icons.computer,
    Icons.science,
    Icons.architecture,
    Icons.group,
    Icons.calculate,
    Icons.psychology,
    Icons.model_training,
    Icons.code,
    Icons.memory,
    Icons.language,
    Icons.storage,
    Icons.cloud,
    Icons.smart_toy,
    Icons.engineering,
    Icons.laptop_mac,
  ];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Étudiant')
          .get();

      final fetchedStudents = snapshot.docs.map((doc) {
        final data = doc.data();
        final fullName = data['nom'] ?? 'Nom Inconnu';
        return StudentSelection(
          uid: doc.id,
          fullName: fullName,
          isSelected: false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          allStudents = fetchedStudents;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des étudiants: $e')),
        );
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  List<StudentSelection> get filteredStudents {
    if (searchStudentQuery.isEmpty) return allStudents;
    final query = searchStudentQuery.toLowerCase();
    return allStudents
        .where((student) => student.fullName.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final List<String> selectedStudentsUids =
    allStudents.where((s) => s.isSelected).map((s) => s.uid).toList();

    if (selectedStudentsUids.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins un étudiant.')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('classes').doc();

    await docRef.set({
      'nom': _nomCtrl.text.trim(),
      'horaire': _horaireCtrl.text.trim(),
      'nombreEtudiants': selectedStudentsUids.length,
      'iconIndex': _selectedIconIndex,
      'enseignantUid': widget.enseignantUid,
      'studentsUid': selectedStudentsUids,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Classe créée avec succès 🎉')),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choisir une icône pour la classe',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: classIcons.length,
            itemBuilder: (context, idx) {
              final icon = classIcons[idx];
              final selected = idx == _selectedIconIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedIconIndex = idx),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).primaryColor.withOpacity(0.12)
                        : Colors.white,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                      size: 32,
                      color: selected
                          ? Theme.of(context).primaryColor
                          : Colors.black87),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
      true, // ✅ pour que le clavier ne provoque plus d’overflow
      appBar: AppBar(
        title: const Text('Créer une classe'),
        backgroundColor: const Color(0xFFFFFF),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Partie 1 : Informations de base ---
                TextFormField(
                  controller: _nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom de la classe'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _horaireCtrl,
                  decoration: const InputDecoration(labelText: 'Horaire'),
                ),
                const SizedBox(height: 16),

                _buildIconPicker(),
                const SizedBox(height: 16),

                const Text(
                  'Attribution des étudiants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Rechercher un étudiant...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) =>
                      setState(() => searchStudentQuery = value),
                ),
                const SizedBox(height: 10),

                _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                  shrinkWrap: true, // ✅ évite overflow dans ScrollView
                  physics:
                  const NeverScrollableScrollPhysics(), // pas de conflit de scroll
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return CheckboxListTile(
                      title: Text(student.fullName),
                      subtitle: Text('UID: ${student.uid.substring(0, 6)}...'),
                      value: student.isSelected,
                      onChanged: (bool? newValue) {
                        setState(() {
                          student.isSelected = newValue ?? false;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                Center(
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                    onPressed: _saveClass,
                    icon: const Icon(Icons.save),
                    label: const Text(
                        'Créer la Classe et Attribuer les Étudiants'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
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
