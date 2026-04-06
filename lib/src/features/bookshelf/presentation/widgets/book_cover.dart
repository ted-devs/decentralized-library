import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

class BookCover extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final BoxFit fit;
  final bool useCache;

  const BookCover({
    super.key,
    required this.url,
    this.width = 50,
    this.height = 75,
    this.fit = BoxFit.cover,
    this.useCache = false,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _buildErrorWidget(context);
    }

    if (useCache) {
      return CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildShimmerPlaceholder(context),
        errorWidget: (context, url, error) => _buildErrorWidget(context),
        fadeOutDuration: const Duration(milliseconds: 300),
        fadeInDuration: const Duration(milliseconds: 300),
      );
    } else {
      return Image.network(
        url!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildShimmerPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context),
      );
    }
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(50)),
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: theme.colorScheme.outline,
        size: width * 0.4,
      ),
    );
  }
}
