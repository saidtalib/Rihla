import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// A single chat message in a trip's conversation.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;     // null for text-only messages
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.imageUrl,
    required this.timestamp,
  });

  bool get isPhoto => imageUrl != null && imageUrl!.isNotEmpty;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: d['sender_id'] ?? '',
      senderName: d['sender_name'] ?? 'Anonymous',
      text: d['text'] ?? '',
      imageUrl: d['image_url'],
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sender_id': senderId,
        'sender_name': senderName,
        'text': text,
        'image_url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };
}

/// Manages chat messages and photo uploads for a trip.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  String get _displayName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Traveller';

  CollectionReference<Map<String, dynamic>> _messages(String tripId) =>
      _db.collection('trips').doc(tripId).collection('messages');

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
    await _messages(tripId).add(ChatMessage(
      id: '',
      senderId: _uid,
      senderName: _displayName,
      text: text.trim(),
      timestamp: DateTime.now(),
    ).toFirestore());
  }

  // ── Send a photo message ────────────────────
  Future<void> sendPhoto(String tripId, File imageFile) async {
    try {
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_$_uid.jpg';
      final ref = _storage.ref('trips/$tripId/photos/$name');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      await _messages(tripId).add(ChatMessage(
        id: '',
        senderId: _uid,
        senderName: _displayName,
        text: '',
        imageUrl: url,
        timestamp: DateTime.now(),
      ).toFirestore());
    } catch (e) {
      debugPrint('ChatService.sendPhoto error: $e');
      rethrow;
    }
  }

  // ── Delete a message ────────────────────────
  /// Returns true if deletion was allowed.
  Future<bool> deleteMessage(
    String tripId,
    ChatMessage message, {
    required bool isAdminUser,
  }) async {
    // Users can delete own messages; admins can delete any.
    if (message.senderId != _uid && !isAdminUser) return false;

    await _messages(tripId).doc(message.id).delete();

    // If it had an image, also delete from Storage.
    if (message.isPhoto) {
      try {
        await _storage.refFromURL(message.imageUrl!).delete();
      } catch (_) {
        // Image may already be gone – ignore.
      }
    }
    return true;
  }

  // ── Get all photos (for Vault) ──────────────
  Stream<List<ChatMessage>> photosStream(String tripId) {
    return messagesStream(tripId).map(
      (msgs) => msgs.where((m) => m.isPhoto).toList(),
    );
  }
}
