// lib/widgets/allofoods_app_bar.dart
// ? Firebase : avatar chargé depuis FirebaseAuth.currentUser + Firestore
//              Plus d'ApiService.getProfile() ? lecture locale instantanée

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/notification_provider.dart';

class allofoodsAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;

  const allofoodsAppBar({
    super.key,
    this.title = 'allofoods',
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<allofoodsAppBar> createState() => _allofoodsAppBarState();
}

class _allofoodsAppBarState extends State<allofoodsAppBar> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Essai rapide : photoURL déjà dans Firebase Auth (mis à jour par ProfilPage)
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        if (mounted) setState(() => _imageUrl = user.photoURL);
        return;
      }

      // 2. Fallback : Firestore users/{uid}
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final url = snap.data()?['imageUrl'] as String?;
      if (mounted && url != null && url.isNotEmpty) {
        setState(() => _imageUrl = url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black12,
      centerTitle: true,
      automaticallyImplyLeading: false,

      // GAUCHE : Avatar profil
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/settings'),
          child: _ProfileAvatar(imageUrl: _imageUrl),
        ),
      ),

      // CENTRE : Logo texte
      title: RichText(
        text: const TextSpan(children: [
          TextSpan(
            text: 'Allo',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5),
          ),
          TextSpan(
            text: 'Foods',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.orange,
                letterSpacing: -0.5),
          ),
        ]),
      ),

      // DROITE : Cloche notifications
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _NotificationBell(),
        ),
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade100, height: 1),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  const _ProfileAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.orange.shade50,
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(imageUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                cacheWidth: 100,
                errorBuilder: (_, __, ___) => const _AvatarFallback(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : const _AvatarFallback())
            : const _AvatarFallback(),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        color: Colors.orange.shade100,
        child: const Icon(Icons.person_outline, color: Colors.orange, size: 20),
      );
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        return GestureDetector(
          onTap: () {
            notifProvider.markAllAsRead();
            Navigator.pushNamed(context, '/notifications');
          },
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200)),
              child: const Icon(Icons.notifications_none_outlined,
                  color: Colors.black87, size: 22),
            ),
            if (notifProvider.hasUnread)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      notifProvider.unreadCount > 99
                          ? '99+'
                          : '${notifProvider.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}
