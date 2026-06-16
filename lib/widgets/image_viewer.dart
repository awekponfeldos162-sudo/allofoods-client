// lib/widgets/image_viewer.dart
// Visualiseur d'image plein écran avec animation Hero + zoom pinch
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Widget d'affichage d'image cliquable qui ouvre un visualiseur plein écran.
/// Utilisation :
///   ImageViewer(imageUrl: url, heroTag: 'plat_$id', size: 90)
class ImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;
  final double size;
  final BoxShape shape;
  final Widget? placeholder;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.heroTag,
    this.size = 60,
    this.shape = BoxShape.rectangle,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final tag = heroTag ?? imageUrl;
    final fallback = placeholder ??
        Icon(Icons.image_outlined, color: Colors.grey.shade400, size: size * 0.4);

    Widget content;
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      content = fallback;
    } else {
      content = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: Colors.grey.shade100,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.orange,
                    strokeWidth: 1.5,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade100,
          child: fallback,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openViewer(context, tag),
      child: Hero(
        tag: tag,
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: shape == BoxShape.rectangle
                ? BorderRadius.circular(12)
                : null,
            color: Colors.grey.shade100,
          ),
          child: content,
        ),
      ),
    );
  }

  /// Ouvre le visualiseur sans passer par le widget ImageViewer.
  /// Utile pour les images non carrées ou déjà wrappées dans un autre widget.
  static void open(BuildContext context, String imageUrl, String heroTag) {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => _ImageViewerPage(
          imageUrl: imageUrl,
          heroTag: heroTag,
          animation: animation,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openViewer(BuildContext context, String tag) {
    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, animation, __) => _ImageViewerPage(
          imageUrl: imageUrl,
          heroTag: tag,
          animation: animation,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

// PAGE PLEIN éCRAN
class _ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final Animation<double> animation;

  const _ImageViewerPage({
    required this.imageUrl,
    required this.heroTag,
    required this.animation,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Animation zoom à l'ouverture é effet vif
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    _scaleAnim = CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _close() {
    _scaleCtrl.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap n'importe oé ? ferme
      onTap: _close,
      // Swipe bas rapide ? ferme
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 300) _close();
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: widget.animation,
          builder: (_, child) => Container(
            // Fond noir progressif
            color: Colors.black.withValues(alpha: widget.animation.value * 0.92),
            child: child,
          ),
          child: Center(
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Hero(
                tag: widget.heroTag,
                child: GestureDetector(
                  // évite fermeture si tap sur l'image elle-même
                  onTap: () {},
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    height: MediaQuery.of(context).size.width * 0.88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: PhotoView(
                        imageProvider: NetworkImage(widget.imageUrl),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                        backgroundDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        loadingBuilder: (_, event) => Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: event?.cumulativeBytesLoaded != null &&
                                    (event?.expectedTotalBytes ?? 0) > 0
                                ? event!.cumulativeBytesLoaded /
                                    event.expectedTotalBytes!
                                : null,
                          ),
                        ),
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
