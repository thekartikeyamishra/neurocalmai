import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/waitlist_service.dart';

class OfflineWaitlistScreen extends StatefulWidget {
  const OfflineWaitlistScreen({Key? key}) : super(key: key);

  @override
  State<OfflineWaitlistScreen> createState() => _OfflineWaitlistScreenState();
}

class _OfflineWaitlistScreenState extends State<OfflineWaitlistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _waitlistService = WaitlistService();

  // Controllers
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _expectationsController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _willingToLead = false;
  final List<String> _selectedNeeds = [];

  // Data options (Can be fetched dynamically from backend in the future)
  final List<String> _availableNeeds = [
    'Accountability',
    'Anxiety Support',
    'Guided Meditation',
    'Safe Venting Space',
    'Habit Building',
    'Social Connection'
  ];

  @override
  void dispose() {
    _cityController.dispose();
    _pincodeController.dispose();
    _expectationsController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedNeeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one primary need.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Dynamic responses bundle (e.g., open text questions)
      final dynamicResponses = {
        'open_expectations': _expectationsController.text.trim(),
        'app_version': '1.0.0', // Helpful for telemetry
      };

      await _waitlistService.joinOfflineWaitlist(
        city: _cityController.text,
        pincode: _pincodeController.text,
        primaryNeeds: _selectedNeeds,
        willingToLead: _willingToLead,
        dynamicFormResponses: dynamicResponses,
      );

      if (!mounted) return;

      // Psychological Reward: Immediate Positive Reinforcement
      _showSuccessDialog();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('You\'re on the list!'),
          ],
        ),
        content: Text(
          _willingToLead 
            ? 'Thank you for stepping up! We will contact you first when we are ready to launch the ${_cityController.text} chapter.'
            : 'You are now an official founding waitlist member for ${_cityController.text}. We will notify you the moment local chapters go live.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to dashboard
            },
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Chapters'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Psychological Nudge: Belonging & Vision)
                Text(
                  "Bring support to your city.",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "AI is powerful, but human connection is the ultimate moat. Help us map the demand to launch secure, offline community chapters near you.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Location Data
                Text("Where are you located?", style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_city),
                        ),
                        validator: (value) => 
                            value == null || value.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Pincode',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => 
                            value == null || value.trim().length < 5 ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Needs Selection (Dynamic Data Collection for SLM context)
                Text("What do you need most from a local group?", 
                  style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _availableNeeds.map((need) {
                    final isSelected = _selectedNeeds.contains(need);
                    return ChoiceChip(
                      label: Text(need),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedNeeds.add(need);
                          } else {
                            _selectedNeeds.remove(need);
                          }
                        });
                      },
                      selectedColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer 
                            : theme.colorScheme.onSurface,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Dynamic/Open Ended Question
                Text("Any specific expectations? (Optional)", 
                  style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expectationsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'E.g., I prefer small groups of 4-5 people...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 32),

                // Leadership Nudge (Psychological Nudge: Status & Ownership)
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                  ),
                  child: SwitchListTile(
                    title: const Text('I want to be a Founding Leader', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Help facilitate the first meetings in your city. We provide the training and framework.'),
                    value: _willingToLead,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (bool value) {
                      setState(() {
                        _willingToLead = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 48),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _willingToLead ? 'Claim Leadership Spot' : 'Join the Waitlist',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}