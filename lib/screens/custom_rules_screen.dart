// lib/screens/custom_rules_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/scam_detection_service.dart';

class CustomRule {
  String pattern;
  String description;
  bool isEnabled;
  bool isRegex;
  
  CustomRule({
    required this.pattern, 
    required this.description, 
    this.isEnabled = true, 
    this.isRegex = false
  });
  
  // Convert to Map for storage in ScamDetectionService
  Map<String, dynamic> toMap() {
    return {
      'pattern': pattern,
      'description': description,
      'isEnabled': isEnabled,
      'isRegex': isRegex,
    };
  }
  
  // Create from Map stored in ScamDetectionService
  factory CustomRule.fromMap(Map<String, dynamic> map) {
    return CustomRule(
      pattern: map['pattern'] as String,
      description: map['description'] as String,
      isEnabled: map['isEnabled'] as bool,
      isRegex: map['isRegex'] as bool,
    );
  }
}

class CustomRulesScreen extends StatefulWidget {
  const CustomRulesScreen({super.key});

  @override
  CustomRulesScreenState createState() => CustomRulesScreenState();
}

class CustomRulesScreenState extends State<CustomRulesScreen> {
  final List<CustomRule> _rules = [
    CustomRule(
      pattern: "gift card",
      description: "Blocks messages mentioning gift cards",
      isEnabled: true,
    ),
    CustomRule(
      pattern: "urgent action required",
      description: "Blocks urgent action requests",
      isEnabled: true,
    ),
    CustomRule(
      pattern: r"\b\d{16}\b",
      description: "Blocks messages with credit card numbers",
      isEnabled: true,
      isRegex: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: _rules.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final scamService = Provider.of<SmartScamDetectionService>(context, listen: false);
                return _buildRuleItem(_rules[index], index, scamService);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rule,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No custom rules yet',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add rules to improve scam detection',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Rule'),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(CustomRule rule, int index, SmartScamDetectionService scamService) {
    return Dismissible(
      key: Key('rule_$index'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        setState(() {
          _rules.removeAt(index);
        });
        // Update the service
        final scamService = Provider.of<SmartScamDetectionService>(context, listen: false);
        scamService.removeCustomRule(index);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rule deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                setState(() {
                  _rules.insert(index, rule);
                });
                scamService.addCustomRule(rule.toMap());
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: ListTile(
          title: Text(rule.pattern),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rule.description),
              const SizedBox(height: 4),
              if (rule.isRegex)
                const Chip(
                  label: Text('Regex'),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: TextStyle(fontSize: 10),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          trailing: Switch(
            value: rule.isEnabled,
            onChanged: (value) {
              setState(() {
                rule.isEnabled = value;
              });
              // Update in service
              final scamService = Provider.of<SmartScamDetectionService>(context, listen: false);
              scamService.updateCustomRule(index, rule.toMap());
            },
          ),
          onTap: () => _showEditRuleDialog(context, rule, index),
        ),
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    final patternController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isRegex = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Custom Rule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: patternController,
                    decoration: const InputDecoration(
                      labelText: 'Pattern to detect',
                      hintText: 'e.g., "gift card", "urgent action"',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What does this rule detect?',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isRegex,
                        onChanged: (value) {
                          setState(() {
                            isRegex = value ?? false;
                          });
                        },
                      ),
                      const Text('Use regular expression'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    if (patternController.text.isEmpty) {
                      return;
                    }
                    final newRule = CustomRule(
                      pattern: patternController.text,
                      description: descriptionController.text.isNotEmpty
                          ? descriptionController.text
                          : 'Custom rule',
                      isRegex: isRegex,
                    );
                    
                    setState(() {
                      _rules.add(newRule);
                    });
                    
                    // Add to service
                    final scamService = Provider.of<SmartScamDetectionService>(context, listen: false);
                    scamService.addCustomRule(newRule.toMap());
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('ADD'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRuleDialog(BuildContext context, CustomRule rule, int index) {
    final patternController = TextEditingController(text: rule.pattern);
    final descriptionController = TextEditingController(text: rule.description);
    bool isRegex = rule.isRegex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Custom Rule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: patternController,
                    decoration: const InputDecoration(
                      labelText: 'Pattern to detect',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isRegex,
                        onChanged: (value) {
                          setState(() {
                            isRegex = value ?? false;
                          });
                        },
                      ),
                      const Text('Use regular expression'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    if (patternController.text.isEmpty) {
                      return;
                    }
                    setState(() {
                      rule.pattern = patternController.text;
                      rule.description = descriptionController.text;
                      rule.isRegex = isRegex;
                    });
                    
                    // Update in service
                    final scamService = Provider.of<SmartScamDetectionService>(context, listen: false);
                    scamService.updateCustomRule(index, rule.toMap());
                    
                    Navigator.of(context).pop();
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
