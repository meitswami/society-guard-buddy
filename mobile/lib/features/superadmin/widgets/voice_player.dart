import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Compact play / pause + seek bar for a voice note URL (web `<audio controls>`).
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.url});

  final String url;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _failed = false;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _subs
      ..add(p.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _state = s);
      }))
      ..add(p.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }))
      ..add(p.onPositionChanged.listen((d) {
        if (mounted) setState(() => _position = d);
      }))
      ..add(p.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _position = Duration.zero);
      }));
    _player = p;
    return p;
  }

  Future<void> _toggle() async {
    final p = _ensurePlayer();
    try {
      if (_state == PlayerState.playing) {
        await p.pause();
      } else if (_state == PlayerState.paused) {
        await p.resume();
      } else {
        setState(() {
          _loading = true;
          _failed = false;
        });
        await p.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final playing = _state == PlayerState.playing;
    final max = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: t.secondary, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _loading ? null : _toggle,
            icon: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.primary))
                : Icon(_failed ? Icons.error_outline : (playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    color: _failed ? t.destructive : t.primary),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _position.inMilliseconds.toDouble().clamp(0, max),
                max: max,
                onChanged: _duration == Duration.zero
                    ? null
                    : (v) => _player?.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 10),
            child: Text(
              '${_fmt(_position)} / ${_fmt(_duration)}',
              style: AppText.mono(context, size: 11, color: t.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}
