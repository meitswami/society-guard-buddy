import 'package:flutter/material.dart';

import '../../../core/media/lazy_photos.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../utils/member_photo.dart';

/// Web `PersonAvatar` sizes (`xs` h-7, `sm` h-9, `md` h-10, `lg` h-14).
enum PersonAvatarSize {
  xs(28, 10),
  sm(36, 12),
  md(40, 14),
  lg(56, 16);

  const PersonAvatarSize(this.dimension, this.fontSize);

  final double dimension;
  final double fontSize;
}

/// Circular face photo with initial fallback — use wherever a person name is shown
/// (port of `src/components/PersonAvatar.tsx`). Accepts http(s) and `data:image` photos.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(
      {super.key,
      required this.name,
      this.photo,
      this.memberId,
      this.size = PersonAvatarSize.md,
      this.onTap});

  final String name;
  final String? photo;

  /// When [photo] is not loaded yet, fetch `members.photo` for this id on demand
  /// (society-wide lists do not download photos up front).
  final String? memberId;
  final PersonAvatarSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final id = memberId;
    if ((photo ?? '').trim().isEmpty && id != null && id.isNotEmpty) {
      final loader = LazyPhotoLoader.members;
      if (loader.isCached(id)) {
        return PersonAvatar(name: name, photo: loader.cached(id), size: size, onTap: onTap);
      }
      return FutureBuilder<String?>(
        future: loader.get(id),
        builder: (context, snap) => PersonAvatar(name: name, photo: snap.data, size: size, onTap: onTap),
      );
    }
    final t = context.tokens;
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final provider = memberPhotoProvider(photo);
    final d = size.dimension;
    Widget fallback() => Center(
          child: Text(
            initial,
            style: TextStyle(
                fontSize: size.fontSize,
                fontWeight: FontWeight.w600,
                color: t.primary),
          ),
        );
    final avatar = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTokens.tint(t.primary, 0.10),
        border: Border.all(color: AppTokens.tint(t.border, 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: provider == null
          ? fallback()
          : Image(
              image: provider,
              width: d,
              height: d,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback(),
            ),
    );
    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

/// Circular photo seated to the side of a name/detail block (port of `PersonPhotoSide.tsx`).
class PersonPhotoSide extends StatelessWidget {
  const PersonPhotoSide({
    super.key,
    required this.name,
    this.photo,
    this.memberId,
    this.size = PersonAvatarSize.md,
    required this.child,
  });

  final String name;
  final String? photo;
  final String? memberId;
  final PersonAvatarSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonAvatar(name: name, photo: photo, memberId: memberId, size: size),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}
