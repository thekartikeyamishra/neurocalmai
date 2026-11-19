import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/waitlist_service.dart';

class OfflineWaitlistScreen extends StatefulWidget {
  const OfflineWaitlistScreen({super.key});

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
  int _currentStep = 1;
  final int _totalSteps = 3;

  // Data options mapped to therapeutic needs (SLM feature engineered)
  final List<String> _availableNeeds = [
    'Accountability',
    'Anxiety Support',
    'Guided Meditation',
    'Safe Venting Space',
    'Habit Building',
    'Social Connection',
    'Body Double (ADHD)',
  ];

  @override
  void dispose() {
    _cityController.dispose();
    _pincodeController.dispose();
    _expectationsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1 && (_cityController.text.isEmpty || _pincodeController.text.length < 5)) {
      _formKey.currentState!.validate(); // Trigger red text
      HapticFeedback.heavyImpact();
      return;
    }
    
    if (_currentStep == 2 && _selectedNeeds.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one primary need to continue.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      if (_currentStep < _totalSteps) {
        _currentStep++;
      }
    });
  }

  void _previousStep() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentStep > 1) {
        _currentStep--;
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedNeeds.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one primary need.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Dynamic responses bundle (Telemetry payload mapping)
      final dynamicResponses = {
        'open_expectations': _expectationsController.text.trim(),
        'app_version': '1.0.0',
        'telemetry_context': 'offline_chapter_intent'
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
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('You\'re on the list!', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          _willingToLead 
            ? 'Thank you for stepping up! We will contact you first when we are ready to launch the ${_cityController.text} chapter.'
            : 'You are now an official founding waitlist member for ${_cityController.text}. We will notify you the moment local chapters go live.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to dashboard
            },
            child: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Local Chapters', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _currentStep > 1 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _previousStep)
            : const BackButton(),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: _currentStep / _totalSteps,
                backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                minHeight: 4,
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(theme),
                  ),
                ),
              ),

              // Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 16,
                    )
                  ]
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading 
                          ? null 
                          : (_currentStep == _totalSteps ? _submitForm : _nextStep),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _currentStep == _totalSteps 
                                  ? (_willingToLead ? 'Claim Leadership Spot' : 'Join the Waitlist')
                                  : 'Continue',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(theme);
      case 2:
        return _buildStep2(theme);
      case 3:
        return _buildStep3(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // STEP 1: Location & Mapping Demand
  // =========================================================================
  Widget _buildStep1(ThemeData theme) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bring support to your city.",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "AI is powerful, but human connection is the ultimate moat. Help us map the demand to launch secure, offline community chapters near you.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),

        Text("Where are you located?", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'City',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.location_city_rounded),
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                validator: (value) => 
                    value == null || value.trim().length < 5 ? 'Invalid' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 2: Needs & Intent
  // =========================================================================
  Widget _buildStep2(ThemeData theme) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Shape your chapter.",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "What do you need most from a local, in-person group?",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: _availableNeeds.map((need) {
            final isSelected = _selectedNeeds.contains(need);
            return FilterChip(
              label: Text(need),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (selected) {
                    _selectedNeeds.add(need);
                  } else {
                    _selectedNeeds.remove(need);
                  }
                });
              },
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer 
                    : theme.colorScheme.onSurfaceVariant,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 3: Expectations & Leadership
  // =========================================================================
  Widget _buildStep3(ThemeData theme) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Final touches.",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 32),

        Text("Any specific expectations? (Optional)", 
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _expectationsController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'E.g., I prefer small groups of 4-5 people...\\nOr, I hope this includes weekend coffee meetups.',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 48),

        // Leadership Nudge (Psychological Nudge: Status & Ownership)
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2), width: 1.5),
          ),
          child: SwitchListTile(
            title: const Text('I want to be a Founding Leader', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4.0),
              child: Text('Help facilitate the first meetings in your city. We provide the training and framework.'),
            ),
            value: _willingToLead,
            activeThumbColor: theme.colorScheme.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onChanged: (bool value) {
              if (value) HapticFeedback.heavyImpact();
              setState(() {
                _willingToLead = value;
              });
            },
          ),
        ),
      ],
    );
  }
}