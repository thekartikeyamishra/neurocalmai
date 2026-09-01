import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/community_service.dart';

/// Displays the details of a local community meetup.
/// Enforces Google Play policies by prominently displaying the Health App 
/// medical disclaimer and providing accessible UGC Report/Block mechanisms.
class EventDetailScreen extends StatefulWidget {
  final String communityId;
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventDetailScreen({
    Key? key,
    required this.communityId,
    required this.eventId,
    required this.eventData,
  }) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final CommunityService _communityService = CommunityService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = false;
  late List<String> _attendeeIds;

  // Brand Colors
  final Color primarySage = const Color(0xFF2F5244);
  final Color creamBg = const Color(0xFFFBFAF6);

  @override
  void initState() {
    super.initState();
    _attendeeIds = List<String>.from(widget.eventData['attendeeIds'] ?? []);
  }

  bool get _isHost => _currentUserId == widget.eventData['hostId'];
  bool get _isAttending => _currentUserId != null && _attendeeIds.contains(_currentUserId);
  bool get _isFull => _attendeeIds.length >= (widget.eventData['maxAttendees'] as int);

  Future<void> _toggleRsvp() async {
    if (_currentUserId == null) return;
    if (_isFull && !_isAttending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This micro-group is currently full.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bool willJoin = !_isAttending;
      await _communityService.toggleRsvp(
        communityId: widget.communityId,
        eventId: widget.eventId,
        isJoining: willJoin,
      );

      setState(() {
        if (willJoin) {
          _attendeeIds.add(_currentUserId!);
        } else {
          _attendeeIds.remove(_currentUserId);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(willJoin ? "You're going! See you there." : "RSVP cancelled."),
            backgroundColor: primarySage,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update RSVP. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // GOOGLE PLAY UGC MODERATION MENUS
  // =========================================================================

  void _showReportDialog() {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Event", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Does this event violate our safety guidelines or promote medical advice?",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Reason for reporting...",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              
              await _communityService.reportContent(
                reportedUserId: widget.eventData['hostId'],
                contentType: 'event',
                contentId: widget.eventId,
                reason: reasonController.text.trim(),
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Report submitted to our moderation team.")),
                );
              }
            },
            child: const Text("Submit Report", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Block Host?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "You will no longer see communities or events created by this host. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              
              await _communityService.blockUser(
                blockedUserId: widget.eventData['hostId'],
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Host blocked successfully.")),
                );
                // Pop back to the feed since the user shouldn't see this host's event anymore
                Navigator.pop(context);
              }
            },
            child: const Text("Block Host", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.eventData['title'] ?? 'Meetup';
    final String description = widget.eventData['description'] ?? '';
    final String hostName = widget.eventData['hostName'] ?? 'Community Member';
    final String venueName = widget.eventData['venueName'] ?? 'Public Venue';
    final String address = widget.eventData['address'] ?? '';
    final int maxAttendees = widget.eventData['maxAttendees'] ?? 5;
    
    final Timestamp? timestamp = widget.eventData['scheduledAt'] as Timestamp?;
    final DateTime scheduledAt = timestamp?.toDate() ?? DateTime.now();
    final String dateStr = DateFormat('EEEE, MMM d • h:mm a').format(scheduledAt);

    return Scaffold(
      backgroundColor: creamBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: primarySage,
        actions: [
          if (!_isHost)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'report') _showReportDialog();
                if (value == 'block') _showBlockDialog();
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report Event'),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Text('Block Host', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: primarySage.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Public Meetup",
                        style: TextStyle(color: primarySage, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primarySage, fontFamily: 'Fraunces'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Hosted by $hostName",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),

                    // Date & Location Info Cards
                    _buildInfoRow(Icons.calendar_today_rounded, dateStr, "Scheduled Time"),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.location_on_rounded, venueName, address),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.people_alt_rounded,
                      "${_attendeeIds.length} / $maxAttendees Attendees",
                      "Micro-group setting for low pressure.",
                    ),
                    const SizedBox(height: 32),

                    // Description
                    const Text("About this meetup", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 40),

                    // Google Play Medical Disclaimer (Strict Compliance)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.amber.shade900),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Disclaimer: This meetup is a casual peer-support social gathering. It is not clinical therapy. NeuroCalm AI is not a medical device and does not diagnose or treat medical conditions.",
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Fixed Bottom RSVP Area
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: _isHost
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.grey.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: null,
                        child: const Text("You are the host", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isAttending ? Colors.redAccent.withOpacity(0.1) : primarySage,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isLoading ? null : _toggleRsvp,
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                _isAttending ? "Cancel RSVP" : (_isFull ? "Event Full" : "Join Meetup"),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isAttending ? Colors.redAccent : Colors.white,
                                ),
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(icon, color: primarySage, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ],
          ),
        )
      ],
    );
  }
}