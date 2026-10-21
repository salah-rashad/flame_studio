import 'dart:ui' show Image;

import 'package:flame/components.dart';

import 'animation_file.dart';

/// The animation [name] of [file], cut from [image] (the file's
/// spritesheet) with the rules of contracts/anim-file-v1.md § Frames.
///
/// Throws a [RangeError] naming the file, the animation and the frame when
/// a frame lies outside the image, and an [ArgumentError] when [file] has
/// no animation [name].
SpriteAnimation toSpriteAnimation(
  AnimationFile file,
  String name,
  Image image,
) {
  final clip = file.animations[name];
  if (clip == null) {
    throw ArgumentError.value(
      name,
      'name',
      'Animation file ${file.path} has no animation "$name"',
    );
  }
  final grid = file.grid;
  final pitchX = grid.cellSize.x + grid.spacing.x;
  final pitchY = grid.cellSize.y + grid.spacing.y;
  final columns = ((image.width - grid.offset.x + grid.spacing.x) / pitchX)
      .floor();
  final rows = ((image.height - grid.offset.y + grid.spacing.y) / pitchY)
      .floor();
  final cells = columns < 0 || rows < 0 ? 0 : columns * rows;
  final size = Vector2(grid.cellSize.x, grid.cellSize.y);
  final sprites = [
    for (final frame in clip.frames)
      if (frame >= cells)
        throw RangeError(
          'Animation file ${file.path}, animation "$name": frame $frame is '
          'outside ${file.image}, which holds $cells cells of '
          '${grid.cellSize.x}×${grid.cellSize.y} ($columns × $rows)',
        )
      else
        Sprite(
          image,
          srcPosition: Vector2(
            grid.offset.x + (frame % columns) * pitchX,
            grid.offset.y + (frame ~/ columns) * pitchY,
          ),
          srcSize: size,
        ),
  ];
  return switch ((clip.stepTime, clip.stepTimes)) {
    (final double time, _) => SpriteAnimation.spriteList(
      sprites,
      stepTime: time,
      loop: clip.loop,
    ),
    (_, final times!) => SpriteAnimation.variableSpriteList(
      sprites,
      stepTimes: times,
      loop: clip.loop,
    ),
  };
}
