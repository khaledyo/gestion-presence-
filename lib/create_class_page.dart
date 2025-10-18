import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  final TextEditingController _nbCtrl = TextEditingController(text: '0');

  bool _isSaving = false;
  String? _generatedCode;

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final uuid = const Uuid();
    final String codeUnique = uuid.v4();
    _generatedCode = codeUnique;

    final docRef = FirebaseFirestore.instance.collection('classes').doc();

    await docRef.set({
      'nom': _nomCtrl.text.trim(),
      'horaire': _horaireCtrl.text.trim(),
      'nombreEtudiants': int.tryParse(_nbCtrl.text) ?? 0,
      'code': codeUnique,
      'enseignantUid': widget.enseignantUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _isSaving = false);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Classe créée avec succès 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Code : $codeUnique'),
            const SizedBox(height: 12),
            SizedBox(
              width: 150,
              height: 150,
              child: QrImageView(
                data: codeUnique,
                version: QrVersions.auto,
                size: 150.0,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (mounted) Navigator.pop(context); // retour au Dashboard
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _horaireCtrl.dispose();
    _nbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une classe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nbCtrl,
                  decoration: const InputDecoration(labelText: "Nombre d'étudiants"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                _isSaving
                    ? const CircularProgressIndicator()
                    : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveClass,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
                const SizedBox(height: 20),
                if (_generatedCode != null) ...[
                  Text('Code généré : $_generatedCode'),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: QrImageView(
                        data: _generatedCode!,
                        version: QrVersions.auto,
                        size: 120,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
