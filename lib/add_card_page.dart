import 'package:flutter/material.dart';
import 'database_helper.dart';

class AddCardPage extends StatefulWidget {
  @override
  _AddCardPageState createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers to capture text input
  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _backController = TextEditingController();
  final TextEditingController _kanjiController = TextEditingController();
  
  String _selectedCardType = 'flip'; // Default to flip card

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _kanjiController.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (_formKey.currentState!.validate()) {
      // 1. Prepare the new card data
      Map<String, dynamic> newCard = {
        'front_text': _frontController.text.trim(),
        'back_text': _backController.text.trim(),
        'card_type': _selectedCardType,
        'kanji': _selectedCardType == 'writing' ? _kanjiController.text.trim() : null,
        // Initialize brand new SRS stats
        'next_review_date': DateTime.now().millisecondsSinceEpoch,
        'interval': 0,
        'repetitions': 0,
        'ease_factor': 2.5,
      };

      // 2. Insert into SQLite
      await DatabaseHelper.instance.insertCard(newCard);

      // 3. Show success message and clear form
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added successfully!'), backgroundColor: Colors.green),
      );
      
      _frontController.clear();
      _backController.clear();
      _kanjiController.clear();
      
      // Optional: pop back to the previous screen
      // Navigator.pop(context); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Card')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Card Type Selector
              DropdownButtonFormField<String>(
                value: _selectedCardType,
                decoration: const InputDecoration(labelText: 'Card Type'),
                items: const [
                  DropdownMenuItem(value: 'flip', child: Text('Flip Card (Reading)')),
                  DropdownMenuItem(value: 'writing', child: Text('Writing Card (S Pen)')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCardType = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Front Text (Prompt)
              TextFormField(
                controller: _frontController,
                decoration: InputDecoration(
                  labelText: _selectedCardType == 'flip' ? 'Front Text (e.g., ねこ)' : 'Prompt (e.g., Water)',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter the front text' : null,
              ),
              const SizedBox(height: 20),

              // Back Text (Answer/Meaning)
              TextFormField(
                controller: _backController,
                decoration: InputDecoration(
                  labelText: _selectedCardType == 'flip' ? 'Back Text (e.g., Cat)' : 'Answer (e.g., 水)',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'Please enter the back text' : null,
              ),
              const SizedBox(height: 20),

              // Kanji Target (Only shows if 'writing' is selected)
              if (_selectedCardType == 'writing') ...[
                TextFormField(
                  controller: _kanjiController,
                  decoration: const InputDecoration(
                    labelText: 'Target Kanji for ML Kit (e.g., 水)',
                    border: OutlineInputBorder(),
                    helperText: 'This is the exact character the S Pen will grade against.',
                  ),
                  validator: (value) {
                    if (_selectedCardType == 'writing' && value!.isEmpty) {
                      return 'Please enter the target Kanji';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Save Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                onPressed: _saveCard,
                child: const Text('Save Card', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}