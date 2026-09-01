import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// A production-ready service to generate clinical handover documents.
/// Fetches the last 30 days of CBT journal entries and formats them into a 
/// secure, anonymized PDF document designed for therapists and clinical review.
class ClinicalExportService {
  // Singleton instance
  static final ClinicalExportService _instance = ClinicalExportService._internal();
  factory ClinicalExportService() => _instance;
  ClinicalExportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates a 30-day CBT progress PDF.
  /// Note: The [password] parameter can be used to encrypt the PDF if using 
  /// advanced PDF packages (like Syncfusion), but here we focus on saving it 
  /// securely to the app's isolated local directory for the user to share manually.
  Future<File> generateClinicalReport({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Authentication required to generate clinical export.");

    try {
      // 1. Fetch data from the last 30 days
      final DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('journals')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception("No CBT journal entries found in the last 30 days.");
      }

      // 2. Initialize the PDF Document
      final pdf = pw.Document(
        title: 'Clinical CBT Progress Report',
        creator: 'NeuroCalm AI',
      );

      // 3. Build the PDF Pages
      _buildPdfContent(pdf, snapshot.docs, user.uid);

      // 4. Save to secure local application directory
      return await _savePdfToDevice(pdf);

    } catch (e) {
      debugPrint("🚨 PDF Generation Error: $e");
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// Constructs the visual layout of the PDF document.
  void _buildPdfContent(pw.Document pdf, List<QueryDocumentSnapshot> entries, String uid) {
    final primaryColor = PdfColor.fromHex('#2F5244'); // Brand Sage
    
    // Create a formatter for timestamps
    final DateFormat dateFormatter = DateFormat('MMM dd, yyyy - h:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 24),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'NeuroCalm AI',
                  style: pw.TextStyle(color: primaryColor, fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Clinical Handover Report',
                  style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Patient / User Anonymized Metadata
            pw.Text('30-Day Cognitive Behavioral Progress', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Generated: ${dateFormatter.format(DateTime.now())}', style: const pw.TextStyle(color: PdfColors.grey700)),
            pw.Text('Patient ID (Anonymized): ${uid.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(color: PdfColors.grey700)),
            pw.SizedBox(height: 24),

            // Entries List
            ...entries.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              final timestamp = data['timestamp'] as Timestamp?;
              final trigger = data['trigger'] ?? 'Unknown Trigger';
              final distortion = data['distortion'] ?? 'Unclassified';
              final reframe = data['reframe'] ?? 'No reframe generated.';
              
              final dateStr = timestamp != null 
                  ? dateFormatter.format(timestamp.toDate()) 
                  : 'Unknown Date';

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(dateStr, style: pw.TextStyle(fontSize: 10, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    
                    pw.Text('Reported Trigger:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(trigger, style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 8),
                    
                    pw.Text('Cognitive Distortion:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(distortion, style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#D97706'))), // Amber color
                    pw.SizedBox(height: 8),
                    
                    pw.Text('AI Reframe / Insight:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                    pw.Text(reframe, style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
            
            // Medical Disclaimer at the end of the report
            pw.SizedBox(height: 24),
            pw.Text(
              'DISCLAIMER: This document is generated by an automated AI tool designed for personal wellness and cognitive reframing. It is not a clinical diagnosis, nor is it a replacement for professional psychiatric or psychological treatment. This data is provided solely to assist licensed therapists in understanding the user\'s daily cognitive patterns.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.justify,
            ),
          ];
        },
      ),
    );
  }

  /// Saves the PDF to the device's secure application documents directory.
  Future<File> _savePdfToDevice(pw.Document pdf) async {
    // For Flutter Web, file saving requires a different approach (like using the `printing` package).
    // This implementation assumes iOS/Android native compilation.
    if (kIsWeb) {
      throw Exception("PDF generation is currently optimized for mobile devices.");
    }

    // Get the private, secure application directory
    final Directory dir = await getApplicationDocumentsDirectory();
    
    // Create a unique filename
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final String filePath = '${dir.path}/NeuroCalm_Clinical_Report_$timestamp.pdf';
    
    final File file = File(filePath);
    
    // Write the PDF binary data to the file
    await file.writeAsBytes(await pdf.save());
    
    debugPrint("✅ Clinical PDF saved to: $filePath");
    return file;
  }
}