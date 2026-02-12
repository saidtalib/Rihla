import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Type of chat message content.
enum MessageType { text, image, pdf }

/// A single chat message in a trip's conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final String? fileUrl; // image or PDF URL
  final String? fileName; // original file name (for PDFs)
  final MessageType type;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    this.fileUrl,
    this.fileName,
    this.type = MessageType.text,
    required this.timestamp,
  });

  bool get isPhoto => type == MessageType.image;
  bool get isPdf => type == MessageType.pdf;
  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;

  // Backward-compatible: old messages stored image in 'image_url'
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    final rawType = d['type'] as String?;
    MessageType type;
    if (rawType == 'pdf') {
      type = MessageType.pdf;
    } else if (rawType == 'image' ||
        (d['image_url'] != null && (d['image_url'] as String).isNotEmpty)) {
      type = MessageType.image;
    } else {
      type = MessageType.text;
    }

    return ChatMessage(
      id: doc.id,
      senderId: d['sender_id'] ?? '',
      senderName: d['sender_name'] ?? 'Anonymous',
      senderPhotoUrl: d['sender_photo_url'],
      text: d['text'] ?? '',
      fileUrl: d['file_url'] ?? d['image_url'],
      fileName: d['file_name'],
      type: type,
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_photo_url': senderPhotoUrl,
        'text': text,
        'file_url': fileUrl,
        'file_name': fileName,
        'type': type.name,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

/// Manages chat messages, file uploads, and vault sync for a trip.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  User? get _user => FirebaseAuth.instance.currentUser;
  String get _uid => _user?.uid ?? 'anonymous';
  String get _displayName => _user?.displayName ?? 'Traveller';
  String? get _photoUrl => _user?.photoURL;

  CollectionReference<Map<String, dynamic>> _messages(String tripId) =>
      _db.collection('trips').doc(tripId).collection('messages');

  CollectionReference<Map<String, dynamic>> _vault(String tripId) =>
      _db.collection('trips').doc(tripId).collection('vault');

  // ── Stream of messages (real-time) ──────────
  Stream<List<ChatMessage>> messagesStream(String tripId) {
    return _messages(tripId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  // ── Send a text message ─────────────────────
  Future<void> sendText(String tripId, String text) async {
    if (text.trim().isEmpty) return;
    final msg = ChatMessage(
      id: '',
      senderId: _uid,
      senderName: _displayName,
      senderPhotoUrl: _photoUrl,
      text: text.trim(),
      type: MessageType.text,
      timestamp: DateTime.now(),
    );
    await _messages(tripId).add(msg.toFirestore());
  }

  // ── Send a photo message + vault sync ───────
  Future<void> sendPhoto(String tripId, File imageFile) async {
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}_$_uid.jpg';
      final ref = _storage.ref('trips/$tripId/chat_files/$name');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      final msg = ChatMessage(
        id: '',
        senderId: _uid,
        senderName: _displayName,
        senderPhotoUrl: _photoUrl,
        text: '',
        fileUrl: url,
        fileName: name,
        type: MessageType.image,
        timestamp: DateTime.now(),
      );
      await _messages(tripId).add(msg.toFirestore());

      // Vault sync
      await _addToVault(tripId, url, 'image', name);
    } catch (e) {
      debugPrint('ChatService.sendPhoto error: $e');
      rethrow;
    }
  }

  // ── Send a PDF file + vault sync ────────────
  Future<void> sendPdf(String tripId, File pdfFile, String originalName) async {
    try {
      final safeName =
          '${DateTime.now().millisecondsSinceEpoch}_${_uid}_$originalName';
      final ref = _storage.ref('trips/$tripId/chat_files/$safeName');
      await ref.putFile(pdfFile);
      final url = await ref.getDownloadURL();

      final msg = ChatMessage(
        id: '',
        senderId: _uid,
        senderName: _displayName,
        senderPhotoUrl: _photoUrl,
        text: '',
        fileUrl: url,
        fileName: originalName,
        type: MessageType.pdf,
        timestamp: DateTime.now(),
      );
      await _messages(tripId).add(msg.toFirestore());

      // Vault sync
      await _addToVault(tripId, url, 'pdf', originalName);
    } catch (e) {
      debugPrint('ChatService.sendPdf error: $e');
      rethrow;
    }
  }

  // ── Vault sync helper ──────────────────────
  Future<void> _addToVault(
      String tripId, String fileUrl, String fileType, String fileName) async {
    await _vault(tripId).add({
      'file_url': fileUrl,
      'file_type': fileType,
      'file_name': fileName,
      'uploaded_by_id': _uid,
      'uploaded_by_name': _displayName,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Delete a message ────────────────────────
  Future<bool> deleteMessage(
    String tripId,
    ChatMessage message, {
    required bool isAdminUser,
  }) async {
    if (message.senderId != _uid && !isAdminUser) return false;

    await _messages(tripId).doc(message.id).delete();

    // Delete file from Storage if present
    if (message.hasFile) {
      try {
        await _storage.refFromURL(message.fileUrl!).delete();
      } catch (_) {}

      // Also delete vault record
      try {
        final vaultSnap = await _vault(tripId)
            .where('file_url', isEqualTo: message.fileUrl)
            .get();
        for (final doc in vaultSnap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
    return true;
  }

  // ── Get all photos (for legacy Vault tab) ───
  Stream<List<ChatMessage>> photosStream(String tripId) {
    return messagesStream(tripId).map(
      (msgs) => msgs.where((m) => m.isPhoto).toList(),
    );
  }

  // ── Vault stream (files sub-collection) ─────
  Stream<List<Map<String, dynamic>>> vaultStream(String tripId) {
    return _vault(tripId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}
