import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The 60 icons of the Pyro design system (its Icons group), drawn
/// from Lucide (`lucide_icons_flutter`).
///
/// Widgets use these rather than `LucideIcons` directly, so the design
/// system's names stay in one place. Each member takes the design system's
/// icon name, camel-cased (`chevron-down` is [chevronDown]); its doc comment
/// names the Lucide glyph. Several differ from Lucide's own name, and for
/// five the same name in Lucide is a different glyph ([scale], [pointer],
/// [sliders], [stepForward], [checkCircle]); `test/icons_test.dart` pins
/// them.
///
/// Node types are a Pyro concept, so the app maps them to icons (its
/// `nodeKindIcon`). The design's convention: camera → [video], sprite →
/// [image], sprite animation → [film], text → [type], collision shape →
/// [hitbox], group → [layers], world → [globe], particles → [sparkle],
/// generic component → [circleDot], component or prefab → [box], script →
/// [fileCode].
///
/// Icons are outlines; only the Play button draws a filled triangle
/// ([PrPlayGlyph]).
abstract final class PrIcons {
  /// `alert-circle`: Lucide `circle-alert`.
  static const IconData alertCircle = LucideIcons.circleAlert;

  /// `alert-triangle`: Lucide `triangle-alert`.
  static const IconData alertTriangle = LucideIcons.triangleAlert;

  /// `box` (Lucide `box`).
  static const IconData box = LucideIcons.box;

  /// `check` (Lucide `check`).
  static const IconData check = LucideIcons.check;

  /// `check-circle`: Lucide `circle-check`.
  ///
  /// Not `LucideIcons.checkCircle`, an alias for circle-check-big.
  static const IconData checkCircle = LucideIcons.circleCheck;

  /// `chevron-down` (Lucide `chevron-down`).
  static const IconData chevronDown = LucideIcons.chevronDown;

  /// `chevron-right` (Lucide `chevron-right`).
  static const IconData chevronRight = LucideIcons.chevronRight;

  /// `circle-dot` (Lucide `circle-dot`).
  static const IconData circleDot = LucideIcons.circleDot;

  /// `code` (Lucide `code`).
  static const IconData code = LucideIcons.code;

  /// `copy` (Lucide `copy`).
  static const IconData copy = LucideIcons.copy;

  /// `crosshair` (Lucide `crosshair`).
  static const IconData crosshair = LucideIcons.crosshair;

  /// `external`: Lucide `external-link`.
  static const IconData external = LucideIcons.externalLink;

  /// `eye` (Lucide `eye`).
  static const IconData eye = LucideIcons.eye;

  /// `eye-off` (Lucide `eye-off`).
  static const IconData eyeOff = LucideIcons.eyeOff;

  /// `file` (Lucide `file`).
  static const IconData file = LucideIcons.file;

  /// `file-code` (Lucide `file-code`).
  static const IconData fileCode = LucideIcons.fileCode;

  /// `film` (Lucide `film`).
  static const IconData film = LucideIcons.film;

  /// `filter`: Lucide `funnel`.
  static const IconData filter = LucideIcons.funnel;

  /// `folder` (Lucide `folder`).
  static const IconData folder = LucideIcons.folder;

  /// `globe` (Lucide `globe`).
  static const IconData globe = LucideIcons.globe;

  /// `grid`: Lucide `grid-3x3`.
  static const IconData grid = LucideIcons.grid3x3;

  /// `hitbox`: Lucide `square-dashed`.
  static const IconData hitbox = LucideIcons.squareDashed;

  /// `image` (Lucide `image`).
  static const IconData image = LucideIcons.image;

  /// `info` (Lucide `info`).
  static const IconData info = LucideIcons.info;

  /// `layers` (Lucide `layers`).
  static const IconData layers = LucideIcons.layers;

  /// `link` (Lucide `link`).
  static const IconData link = LucideIcons.link;

  /// `list-tree` (Lucide `list-tree`).
  static const IconData listTree = LucideIcons.listTree;

  /// `lock` (Lucide `lock`).
  static const IconData lock = LucideIcons.lock;

  /// `magnet` (Lucide `magnet`).
  static const IconData magnet = LucideIcons.magnet;

  /// `minus` (Lucide `minus`).
  static const IconData minus = LucideIcons.minus;

  /// `monitor` (Lucide `monitor`).
  static const IconData monitor = LucideIcons.monitor;

  /// `more`: Lucide `ellipsis`.
  static const IconData more = LucideIcons.ellipsis;

  /// `move` (Lucide `move`).
  static const IconData move = LucideIcons.move;

  /// `music` (Lucide `music`).
  static const IconData music = LucideIcons.music;

  /// `panel-bottom` (Lucide `panel-bottom`).
  static const IconData panelBottom = LucideIcons.panelBottom;

  /// `pause` (Lucide `pause`).
  static const IconData pause = LucideIcons.pause;

  /// `pipette` (Lucide `pipette`).
  static const IconData pipette = LucideIcons.pipette;

  /// `play` (Lucide `play`).
  ///
  /// The outline; the Play button draws the filled [PrPlayGlyph].
  static const IconData play = LucideIcons.play;

  /// `plus` (Lucide `plus`).
  static const IconData plus = LucideIcons.plus;

  /// `pointer`: Lucide `mouse-pointer-2`.
  ///
  /// Not `LucideIcons.pointer`, which is a hand.
  static const IconData pointer = LucideIcons.mousePointer2;

  /// `redo` (Lucide `redo`).
  static const IconData redo = LucideIcons.redo;

  /// `reset`: Lucide `rotate-ccw`.
  static const IconData reset = LucideIcons.rotateCcw;

  /// `rotate`: Lucide `rotate-cw`.
  static const IconData rotate = LucideIcons.rotateCw;

  /// `save` (Lucide `save`).
  static const IconData save = LucideIcons.save;

  /// `scale`: Lucide `maximize-2`.
  ///
  /// Not `LucideIcons.scale`, which is a balance scale.
  static const IconData scale = LucideIcons.maximize2;

  /// `search` (Lucide `search`).
  static const IconData search = LucideIcons.search;

  /// `sliders`: Lucide `sliders-horizontal`.
  ///
  /// Not `LucideIcons.sliders`, an alias for sliders-vertical.
  static const IconData sliders = LucideIcons.slidersHorizontal;

  /// `smartphone` (Lucide `smartphone`).
  static const IconData smartphone = LucideIcons.smartphone;

  /// `sparkle` (Lucide `sparkle`).
  static const IconData sparkle = LucideIcons.sparkle;

  /// `step-forward`: Lucide `skip-forward`.
  ///
  /// Not `LucideIcons.stepForward`, which has the bar on the left.
  static const IconData stepForward = LucideIcons.skipForward;

  /// `stop`: Lucide `square`.
  ///
  /// Lucide has no `stop`; its square is 18px against the design's 14px, so it looks slightly larger.
  static const IconData stop = LucideIcons.square;

  /// `terminal` (Lucide `terminal`).
  static const IconData terminal = LucideIcons.terminal;

  /// `trash` (Lucide `trash`).
  ///
  /// Not `trash2`, which has two inner lines.
  static const IconData trash = LucideIcons.trash;

  /// `type` (Lucide `type`).
  static const IconData type = LucideIcons.type;

  /// `undo` (Lucide `undo`).
  static const IconData undo = LucideIcons.undo;

  /// `unlock`: Lucide `lock-open`.
  static const IconData unlock = LucideIcons.lockOpen;

  /// `user` (Lucide `user`).
  static const IconData user = LucideIcons.user;

  /// `video` (Lucide `video`).
  static const IconData video = LucideIcons.video;

  /// `x` (Lucide `x`).
  static const IconData x = LucideIcons.x;

  /// `zap` (Lucide `zap`).
  static const IconData zap = LucideIcons.zap;
}

/// The filled Play triangle of the Play button, the design system's only
/// filled icon.
///
/// An icon font can only draw Lucide's outline ([PrIcons.play], used in
/// menus and elsewhere), so this paints the design's rounded triangle. It
/// takes the colour of the surrounding [IconTheme] unless [color] is set.
class PrPlayGlyph extends StatelessWidget {
  /// Creates the glyph.
  const PrPlayGlyph({super.key, this.size = 16, this.color});

  /// Width and height.
  final double size;

  /// Fill colour; the [IconTheme] colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? IconTheme.of(context).color!;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PlayPainter(fill)),
    );
  }
}

class _PlayPainter extends CustomPainter {
  const _PlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The design's path on its 24×24 grid:
    // M6 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L7.5 3.64A1 1 0 0 0 6 4.5Z
    // filled and stroked 2px with round joins, like every icon.
    const r = Radius.circular(1);
    final path = Path()
      ..moveTo(6, 4.5)
      ..lineTo(6, 19.5)
      ..arcToPoint(const Offset(7.5, 20.36), radius: r, clockwise: false)
      ..lineTo(20, 12.86)
      ..arcToPoint(const Offset(20, 11.14), radius: r, clockwise: false)
      ..lineTo(7.5, 3.64)
      ..arcToPoint(const Offset(6, 4.5), radius: r, clockwise: false)
      ..close();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) => color != oldDelegate.color;
}
