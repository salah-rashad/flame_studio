import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The icons of the Flame Studio design system, drawn from Lucide
/// (`lucide_icons_flutter`).
///
/// Widgets use these rather than `LucideIcons` directly, so the design
/// system's names stay in one place. Each is named after its Lucide icon,
/// except where the design system gives the icon a role ([hitbox]).
///
/// So far only the node-type icons the design system names.
abstract final class FsIcons {
  /// Lucide `video`.
  static const IconData video = LucideIcons.video;

  /// Lucide `image`.
  static const IconData image = LucideIcons.image;

  /// Lucide `film`.
  static const IconData film = LucideIcons.film;

  /// Lucide `type`.
  static const IconData type = LucideIcons.type;

  /// Hitbox nodes (Lucide `square-dashed`).
  static const IconData hitbox = LucideIcons.squareDashed;

  /// Lucide `layers`.
  static const IconData layers = LucideIcons.layers;

  /// Lucide `globe`.
  static const IconData globe = LucideIcons.globe;

  /// Lucide `sparkle`.
  static const IconData sparkle = LucideIcons.sparkle;

  /// Lucide `circle-dot`.
  static const IconData circleDot = LucideIcons.circleDot;

  /// Lucide `box`.
  static const IconData box = LucideIcons.box;

  /// Lucide `file-code`.
  static const IconData fileCode = LucideIcons.fileCode;
}
