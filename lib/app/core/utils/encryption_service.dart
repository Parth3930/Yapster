import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:yapster/app/core/utils/storage_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

class EncryptionService extends GetxService {
  static EncryptionService get to => Get.find<EncryptionService>();
  final StorageService _storageService = Get.find<StorageService>();

  // Encryption keys and IVs for different chats
  final Map<String, encrypt.Encrypter> _chatEncrypters = {};
  final Map<String, encrypt.IV> _chatIVs = {};

  // Default encrypter and IV (for backward compatibility)
  late encrypt.Key _defaultKey;
  late encrypt.IV _defaultIV;
  late encrypt.Encrypter _defaultEncrypter;

  // User ID for storage
  String? _userId;

  // Initialization status
  final RxBool isInitialized = false.obs;

  /// Initialize method for ChatController to call
  Future<void> initialize() async {
    try {
      final userId = Get.find<SupabaseService>().currentUser.value?.id;
      if (userId != null) {
        await init(userId);
        isInitialized.value = true;
      } else {
        throw Exception('Cannot initialize encryption: User ID is null');
      }
    } catch (e) {
      debugPrint('Error initializing encryption service: $e');
      rethrow;
    }
  }

  // Initialize the encryption service
  Future<EncryptionService> init(String userId) async {
    _userId = userId;
    await _setupDefaultEncryption();
    return this;
  }

  // Set up the default encryption key and IV
  Future<void> _setupDefaultEncryption() async {
    if (_userId == null) return;

    // Check if we already have keys stored
    String? storedKey = _storageService.getString('encryption_key_$_userId');
    String? storedIv = _storageService.getString('encryption_iv_$_userId');

    if (storedKey != null && storedIv != null) {
      // Use stored keys
      _defaultKey = encrypt.Key(base64Decode(storedKey));
      _defaultIV = encrypt.IV(base64Decode(storedIv));
    } else {
      // Generate new keys
      // Create a deterministic key based on a fixed salt
      final keyBytes =
          sha256.convert(utf8.encode('yapster_global_secret_salt')).bytes;
      _defaultKey = encrypt.Key(Uint8List.fromList(keyBytes));

      // Use a fixed IV for all users
      _defaultIV = encrypt.IV.fromUtf8('yapsterFixedIV16');

      // Store keys for later use
      await _storageService.saveString(
        'encryption_key_$_userId',
        base64Encode(_defaultKey.bytes),
      );
      await _storageService.saveString(
        'encryption_iv_$_userId',
        base64Encode(_defaultIV.bytes),
      );
    }

    // Create default encrypter with AES in CBC mode with PKCS7 padding
    _defaultEncrypter = encrypt.Encrypter(
      encrypt.AES(_defaultKey, mode: encrypt.AESMode.cbc),
    );
  }

  // Get or create encrypter for a specific chat
  Future<Map<String, dynamic>> _getEncrypterForChat(String chatId) async {
    // If we already have an encrypter for this chat, use it
    if (_chatEncrypters.containsKey(chatId) && _chatIVs.containsKey(chatId)) {
      return {'encrypter': _chatEncrypters[chatId]!, 'iv': _chatIVs[chatId]!};
    }

    // Check if we have stored keys for this chat
    String? storedKey = _storageService.getString('chat_key_$chatId');
    String? storedIv = _storageService.getString('chat_iv_$chatId');

    encrypt.Key chatKey;
    encrypt.IV chatIV;

    if (storedKey != null && storedIv != null) {
      // Use stored keys
      chatKey = encrypt.Key(base64Decode(storedKey));
      chatIV = encrypt.IV(base64Decode(storedIv));
    } else {
      // Generate deterministic keys based on chat ID
      // This ensures all participants generate the same key
      final keyBytes =
          sha256.convert(utf8.encode('${chatId}yapster_chat_salt')).bytes;
      chatKey = encrypt.Key(Uint8List.fromList(keyBytes));

      // Create a deterministic IV from the chat ID
      final ivHash = sha256.convert(utf8.encode('${chatId}iv_salt')).bytes;
      final ivBytes = ivHash.sublist(0, 16); // Take first 16 bytes for IV
      chatIV = encrypt.IV(Uint8List.fromList(ivBytes));

      // Store keys for later use
      await _storageService.saveString(
        'chat_key_$chatId',
        base64Encode(chatKey.bytes),
      );
      await _storageService.saveString(
        'chat_iv_$chatId',
        base64Encode(chatIV.bytes),
      );
    }

    // Create encrypter with AES in CBC mode with PKCS7 padding
    final chatEncrypter = encrypt.Encrypter(
      encrypt.AES(chatKey, mode: encrypt.AESMode.cbc),
    );

    // Cache for future use
    _chatEncrypters[chatId] = chatEncrypter;
    _chatIVs[chatId] = chatIV;

    return {'encrypter': chatEncrypter, 'iv': chatIV};
  }

  // Encrypt a message for a specific chat
  Future<String> encryptMessageForChat(String message, String chatId) async {
    try {
      if (message.isEmpty) return '';

      final encryption = await _getEncrypterForChat(chatId);
      final encrypted = encryption['encrypter'].encrypt(
        message,
        iv: encryption['iv'],
      );
      return encrypted.base64;
    } catch (e) {
      debugPrint('Encryption error: $e');
      return '🔒 Error encrypting message';
    }
  }

  // Decrypt a message for a specific chat
  Future<String> decryptMessageForChat(
    String encryptedMessage,
    String chatId,
  ) async {
    try {
      if (encryptedMessage.isEmpty) return '';
      
      // Check if message is already decrypted or not in base64 format
      if (!_isBase64(encryptedMessage)) {
        debugPrint('Message appears to be already decrypted or not in base64 format: ${encryptedMessage.substring(0, math.min(10, encryptedMessage.length))}...');
        return encryptedMessage; // Return as-is if not valid base64
      }

      final encryption = await _getEncrypterForChat(chatId);
      final encrypted = encrypt.Encrypted(base64Decode(encryptedMessage));
      return encryption['encrypter'].decrypt(encrypted, iv: encryption['iv']);
    } catch (e) {
      debugPrint('Decryption error for message: ${encryptedMessage.substring(0, math.min(20, encryptedMessage.length))}... Error: $e');
      // Return original message instead of error placeholder to avoid showing "Encrypted message" everywhere
      return encryptedMessage;
    }
  }
  
  // Helper to check if a string is base64 encoded
  bool _isBase64(String str) {
    try {
      if (str.isEmpty || str.length % 4 != 0) return false;
      final regex = RegExp(r'^(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?$');
      if (!regex.hasMatch(str)) return false;
      base64Decode(str); // Try to decode it
      return true;
    } catch (e) {
      return false;
    }
  }

  // For backward compatibility
  String encryptMessage(String message) {
    try {
      if (message.isEmpty) return '';

      final encrypted = _defaultEncrypter.encrypt(message, iv: _defaultIV);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Encryption error: $e');
      return '🔒 Error encrypting message';
    }
  }

  // For backward compatibility
  String decryptMessage(String encryptedMessage) {
    try {
      if (encryptedMessage.isEmpty) return '';

      final encrypted = encrypt.Encrypted(base64Decode(encryptedMessage));
      return _defaultEncrypter.decrypt(encrypted, iv: _defaultIV);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return '🔒 Encrypted message';
    }
  }
}
