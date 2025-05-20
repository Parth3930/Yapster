import 'dart:convert';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:yapster/app/core/utils/storage_service.dart';

class EncryptionService extends GetxService {
  static EncryptionService get to => Get.find<EncryptionService>();
  final StorageService _storageService = Get.find<StorageService>();
  
  // Encryption key and IV
  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;
  late encrypt.Encrypter _encrypter;
  
  // User ID for key derivation
  String? _userId;
  
  // Initialize the encryption service
  Future<EncryptionService> init(String userId) async {
    _userId = userId;
    await _setupEncryption();
    return this;
  }
  
  // Set up the encryption key and IV
  Future<void> _setupEncryption() async {
    if (_userId == null) return;
    
    // Check if we already have keys stored
    String? storedKey = await _storageService.getString('encryption_key_$_userId');
    String? storedIv = await _storageService.getString('encryption_iv_$_userId');
    
    if (storedKey != null && storedIv != null) {
      // Use stored keys
      _encryptionKey = encrypt.Key(base64Decode(storedKey));
      _iv = encrypt.IV(base64Decode(storedIv));
    } else {
      // Generate new keys
      // Create a key based on the user ID for deterministic encryption
      final keyBytes = sha256.convert(utf8.encode(_userId! + 'yapster_secret_salt')).bytes;
      _encryptionKey = encrypt.Key(Uint8List.fromList(keyBytes));
      
      // Generate a random IV
      _iv = encrypt.IV.fromSecureRandom(16);
      
      // Store keys for later use
      await _storageService.saveString('encryption_key_$_userId', base64Encode(_encryptionKey.bytes));
      await _storageService.saveString('encryption_iv_$_userId', base64Encode(_iv.bytes));
    }
    
    // Create encrypter with AES in CBC mode with PKCS7 padding
    _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey, mode: encrypt.AESMode.cbc));
  }
  
  // Encrypt a message
  String encryptMessage(String message) {
    try {
      if (message.isEmpty) return '';
      
      final encrypted = _encrypter.encrypt(message, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      return '🔒 Error encrypting message';
    }
  }
  
  // Decrypt a message
  String decryptMessage(String encryptedMessage) {
    try {
      if (encryptedMessage.isEmpty) return '';
      
      final encrypted = encrypt.Encrypted(base64Decode(encryptedMessage));
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      print('Decryption error: $e');
      return '🔒 Encrypted message';
    }
  }
} 