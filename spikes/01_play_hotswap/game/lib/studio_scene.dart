import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Throwaway version of the Runtime's `StudioScene` (project-plan §6.2).
///
/// Loads a scene file from the asset bundle and, in debug builds, re-reads it
/// on every hot reload. If the content hash changed it rebuilds the whole
/// scene; otherwise (a Dart-only reload) it does nothing.
///
/// The driver watches the `[studio_scene]` log lines below, so keep them stable.
class StudioScene extends Component {
  StudioScene._(this.path, this.onReloaded);

  final String path;
  final void Function(StudioScene scene)? onReloaded;

  String hash = '';
  int rebuildCount = 0;
  bool _checking = false;

  static Future<StudioScene> load(
    String path, {
    void Function(StudioScene scene)? onReloaded,
  }) async {
    final scene = StudioScene._(path, onReloaded);
    final source = await rootBundle.loadString(path);
    scene._build(source);
    debugPrint('[studio_scene] loaded $path hash=${scene.hash}');
    return scene;
  }

  @override
  void onHotReload() {
    super.onHotReload();
    if (kDebugMode) unawaited(_checkForChanges());
  }

  Future<void> _checkForChanges() async {
    if (_checking) return;
    _checking = true;
    try {
      // flutter_tools syncs changed assets and evicts them from rootBundle
      // before reassemble, so the default cached load sees the new file.
      final source = await rootBundle.loadString(path);
      final newHash = _hashOf(source);
      if (newHash == hash) {
        debugPrint('[studio_scene] hot reload: scene unchanged hash=$hash');
        return;
      }
      final oldHash = hash;
      _build(source);
      rebuildCount++;
      debugPrint(
        '[studio_scene] hot reload: scene REBUILT #$rebuildCount '
        'hash=$oldHash->$hash',
      );
      onReloaded?.call(this);
    } catch (e, st) {
      debugPrint('[studio_scene] hot reload: FAILED $e\n$st');
    } finally {
      _checking = false;
    }
  }

  static String _hashOf(String source) =>
      sha1.convert(utf8.encode(source)).toString();

  void _build(String source) {
    hash = _hashOf(source);
    removeAll(children);
    final json = jsonDecode(source) as Map<String, dynamic>;
    for (final node in (json['nodes'] as List).cast<Map<String, dynamic>>()) {
      add(_buildNode(node));
    }
  }

  Component _buildNode(Map<String, dynamic> node) {
    final position = Vector2(
      (node['x'] as num).toDouble(),
      (node['y'] as num).toDouble(),
    );
    final paint = Paint()..color = _parseColor(node['color'] as String);
    switch (node['kind']) {
      case 'rect':
        return RectangleComponent(
          position: position,
          size: Vector2(
            (node['w'] as num).toDouble(),
            (node['h'] as num).toDouble(),
          ),
          anchor: Anchor.center,
          paint: paint,
        );
      case 'circle':
        return CircleComponent(
          position: position,
          radius: (node['r'] as num).toDouble(),
          anchor: Anchor.center,
          paint: paint,
        );
      case 'text':
        return TextComponent(
          text: node['text'] as String,
          position: position,
          anchor: Anchor.center,
          textRenderer: TextPaint(
            style: TextStyle(fontSize: 28, color: paint.color),
          ),
        );
      default:
        throw ArgumentError('Unknown node kind ${node['kind']} in $path');
    }
  }

  static Color _parseColor(String hex) =>
      Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}
