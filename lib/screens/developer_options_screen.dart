import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class DeveloperOptionsScreen extends StatefulWidget {
  const DeveloperOptionsScreen({super.key});

  @override
  State<DeveloperOptionsScreen> createState() => _DeveloperOptionsScreenState();
}

class _DeveloperOptionsScreenState extends State<DeveloperOptionsScreen> {
  final BackendService _backendService = BackendService();
  final TextEditingController _customInputController = TextEditingController();

  bool _isLoading = false;
  String _resultOutput = '';

  @override
  void dispose() {
    _customInputController.dispose();
    super.dispose();
  }

  Future<void> _runTest(String query) async {
    setState(() {
      _isLoading = true;
      _resultOutput = 'Running prepareMeal for: "$query"...';
    });

    try {
      final proposal = await _backendService.prepareMeal(query);

      final StringBuffer sb = StringBuffer();
      sb.writeln('========================================');
      sb.writeln('PREPARE MEAL RESULT FOR: "$query"');
      sb.writeln('========================================');
      sb.writeln('mealType: ${proposal['mealType']}');
      sb.writeln('readyToLog: ${proposal['readyToLog']}');
      sb.writeln('needsClarification: ${proposal['needsClarification']}');
      sb.writeln('clarificationQuestion: ${proposal['clarificationQuestion']}');
      sb.writeln('resolvedItemCount: ${proposal['resolvedItemCount']}');
      sb.writeln('unresolvedItemCount: ${proposal['unresolvedItemCount']}');
      sb.writeln('resolvedNutritionTotal: ${proposal['resolvedNutritionTotal']}');
      sb.writeln('');

      final items = (proposal['items'] as List<dynamic>?) ?? [];
      sb.writeln('ITEMS (${items.length}):');
      sb.writeln('----------------------------------------');

      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        sb.writeln('[Item ${i + 1}]');
        sb.writeln('  interpretedName: ${item['interpretedName']}');
        sb.writeln('  matchedFoodName: ${item['matchedFoodName']}');
        sb.writeln('  requestedQuantity: ${item['requestedQuantity']}');
        sb.writeln('  requestedUnit: ${item['requestedUnit']}');
        sb.writeln('  matchedServingDescription: ${item['matchedServingDescription']}');
        sb.writeln('  weightGrams: ${item['weightGrams']}');
        sb.writeln('  matchConfidence: ${item['matchConfidence']}');
        sb.writeln('  status: ${item['status']}');
        sb.writeln('  clarificationQuestion: ${item['clarificationQuestion']}');
        sb.writeln('  nutrition: ${item['nutrition']}');
        sb.writeln('');
      }

      final formattedText = sb.toString();
      debugPrint(formattedText);

      setState(() {
        _resultOutput = formattedText;
      });
    } catch (e) {
      final errorMsg = 'Error running prepareMeal: $e';
      debugPrint(errorMsg);
      setState(() {
        _resultOutput = errorMsg;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Options'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ask Ele Orchestration Tests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runTest('I had 4 idlis for lunch'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test 1: "I had 4 idlis for lunch"'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _runTest('I had filter coffee and 2 idlis with chutney'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test 2: "I had filter coffee and 2 idlis with chutney"'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customInputController,
              decoration: const InputDecoration(
                labelText: 'Custom Meal Input',
                hintText: 'e.g. 2 eggs and a glass of milk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      final text = _customInputController.text.trim();
                      if (text.isNotEmpty) {
                        _runTest(text);
                      }
                    },
              child: const Text('Run Custom Test'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_resultOutput.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _resultOutput,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
