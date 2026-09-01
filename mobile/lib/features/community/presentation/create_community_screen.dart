import 'package:flutter/material.dart';
import '../../../core/constants/legal_constants.dart';
import '../services/community_service.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({Key? key}) : super(key: key);

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  bool _acceptedCharter = false;
  bool _acceptedDisclaimer = false;
  bool _isLoading = false;

  final CommunityService _communityService = CommunityService();

  // Primary Brand Colors
  final Color primarySage = const Color(0xFF2F5244);
  final Color creamBg = const Color(0xFFFBFAF6);

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  /// Generates a rudimentary geohash based on city and country for clustering.
  /// In a full production environment, replace this with a package like `geohash_plus`
  /// fed by actual device GPS coordinates (Lat/Lng).
  String _generateCityGeoHash(String city, String country) {
    return "${country.substring(0, 2).toLowerCase()}_${city.toLowerCase().replaceAll(' ', '_')}";
  }

  Future<void> _submitCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    // Google Play UGC Compliance: Mandatory EULA & Waiver check
    if (!_acceptedCharter || !_acceptedDisclaimer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must accept both the Facilitator Charter and the EULA to proceed."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String generatedGeoHash = _generateCityGeoHash(
        _cityController.text,
        _countryController.text,
      );

      await _communityService.createCommunity(
        name: _nameController.text,
        city: _cityController.text,
        country: _countryController.text,
        geoHash: generatedGeoHash,
        acceptedCharter: _acceptedCharter,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Local Chapter created successfully!"),
            backgroundColor: primarySage,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        title: const Text(
          "Establish a Chapter",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Fraunces'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primarySage,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lead a local mindful circle.",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: primarySage,
                    fontFamily: 'Fraunces',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Create a safe, offline space for people in your city to connect, breathe, and reset.",
                  style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 32),

                // -- Chapter Details --
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Chapter Name (e.g., Bengaluru Mindful Collective)",
                    labelStyle: TextStyle(color: primarySage.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primarySage.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primarySage, width: 2),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter a chapter name." : null,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: "City",
                          labelStyle: TextStyle(color: primarySage.withOpacity(0.7)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primarySage, width: 2),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "City required" : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _countryController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: "Country",
                          hintText: "IN, US, UK...",
                          labelStyle: TextStyle(color: primarySage.withOpacity(0.7)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primarySage, width: 2),
                          ),
                        ),
                        maxLength: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Req" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // -- Google Play UGC & Liability Compliance --
                Text(
                  "Facilitator Charter & Legal",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primarySage,
                  ),
                ),
                const SizedBox(height: 12),

                // Checkbox 1: UGC EULA (Required by Google Play)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedCharter,
                        activeColor: primarySage,
                        onChanged: (v) => setState(() => _acceptedCharter = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, right: 8.0),
                          child: Text(
                            LegalConstants.ugcEulaAgreement,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Checkbox 2: Facilitator Medical & Safety Disclaimer (Required for Health & Wellness Apps)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptedDisclaimer,
                        activeColor: Colors.amber.shade700,
                        onChanged: (v) => setState(() => _acceptedDisclaimer = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0, right: 8.0),
                          child: Text(
                            LegalConstants.hostFacilitatorCharter,
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // -- Submit Button --
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarySage,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitCommunity,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            "Establish Chapter",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
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