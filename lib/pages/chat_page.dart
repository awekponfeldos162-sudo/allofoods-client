// lib/pages/chat_page.dart é Client ? Driver real-time chat
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

class ChatPage extends StatefulWidget {
  final String orderId;
  final String driverName;

  const ChatPage({
    super.key,
    required this.orderId,
    required this.driverName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scroll  = ScrollController();
  final _db      = FirebaseFirestore.instance;
  final _uid     = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _name    = FirebaseAuth.instance.currentUser?.displayName ??
                   FirebaseAuth.instance.currentUser?.email?.split('@').first ??
                   'Client';
  bool _markingRead = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    await _db
        .collection('orders')
        .doc(widget.orderId)
        .collection('messages')
        .add({
      'senderId':   _uid,
      'senderName': _name,
      'senderRole': 'client',
      'text':       text,
      'isRead':     false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markMessagesRead(List<QueryDocumentSnapshot> docs) async {
    if (_markingRead) return;
    final unread = docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      return m['senderRole'] == 'driver' &&
          (m['isRead'] as bool? ?? false) == false;
    }).toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final batch = _db.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } finally {
      _markingRead = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.orange.shade100,
            child: const Icon(Icons.delivery_dining, size: 18, color: Colors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.driverName.isNotEmpty ? widget.driverName : t.driverLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
              Text(
                t.driverOnline,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ]),
          ),
        ]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: Colors.orange.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${t.orderNumber} #${widget.orderId.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              color: Colors.orange.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('orders')
                .doc(widget.orderId)
                .collection('messages')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              final docs = snap.data?.docs ?? [];

              if (docs.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _markMessagesRead(docs));
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scroll.hasClients &&
                    _scroll.position.hasContentDimensions) {
                  _scroll.jumpTo(_scroll.position.maxScrollExtent);
                }
              });

              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(t.sendMessageToDriver,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(t.chatExampleHint,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ]),
                );
              }

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == _uid;
                  final ts   = data['createdAt'] as Timestamp?;
                  final time = ts != null
                      ? DateFormat('HH:mm').format(ts.toDate())
                      : '';
                  return _Bubble(
                    text:       data['text']       as String? ?? '',
                    senderName: data['senderName'] as String? ?? '',
                    time:       time,
                    isMe:       isMe,
                    role:       data['senderRole'] as String? ?? '',
                    isRead:     data['isRead']     as bool?   ?? false,
                  );
                },
              );
            },
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: t.messageToDriverHint,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text, senderName, time, role;
  final bool isMe;
  final bool isRead;
  const _Bubble({
    required this.text,
    required this.senderName,
    required this.time,
    required this.isMe,
    required this.role,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.delivery_dining,
                  size: 16, color: Colors.orange),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.orange : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: isRead
                              ? Colors.orange.shade200
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
