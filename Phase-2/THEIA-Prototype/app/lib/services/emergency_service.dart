import 'package:flutter/foundation.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';
import 'storage_service.dart';

/// Service for handling emergency contact calls and SMS
class EmergencyService {
  EmergencyService({required StorageService storageService}) : _storageService = storageService;

  final StorageService _storageService;

  /// Call emergency contact by phone number
  Future<void> callEmergencyContact(String phoneNumber) async {
    try {
      // Remove any non-numeric characters from phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      
      // Place direct call
      await FlutterPhoneDirectCaller.callNumber(cleanNumber);
    } catch (e, stackTrace) {
      debugPrint('Error calling emergency contact: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Send emergency SMS to contact
  Future<void> sendEmergencySMS(String phoneNumber, String message) async {
    try {
      // Remove any non-numeric characters from phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      
      // Create SMS URI
      final smsUri = Uri(
        scheme: 'sms',
        path: cleanNumber,
        queryParameters: {'body': message},
      );
      
      // Launch SMS app with pre-filled message
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw Exception('Could not launch SMS app');
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending emergency SMS: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get primary emergency contact from storage
  Future<EmergencyContact?> getPrimaryContact() async {
    try {
      return await _storageService.getPrimaryEmergencyContact();
    } catch (e, stackTrace) {
      debugPrint('Error getting primary contact: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Call and notify primary emergency contact
  /// Returns true if successful, false if no contact configured
  Future<bool> contactPrimaryEmergency({String? customMessage}) async {
    try {
      final contact = await getPrimaryContact();
      
      if (contact == null) {
        debugPrint('No primary emergency contact configured');
        return false;
      }

      // Prepare emergency message
      final message = customMessage ?? 
          'Emergency alert from THEIA app. ${contact.name} may need assistance. '
          'Please check on them immediately.';

      // Call emergency contact
      await callEmergencyContact(contact.phoneNumber);

      // Send SMS to emergency contact
      await sendEmergencySMS(contact.phoneNumber, message);

      return true;
    } catch (e, stackTrace) {
      debugPrint('Error contacting primary emergency: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Call fallback emergency number when no emergency contact configured
  Future<void> call911() async {
    try {
      await FlutterPhoneDirectCaller.callNumber('+15555555555');
    } catch (e, stackTrace) {
      debugPrint('Error calling emergency fallback number: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
