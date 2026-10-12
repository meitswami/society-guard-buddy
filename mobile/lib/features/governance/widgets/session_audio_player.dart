import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// Inline player for the meeting session recording (web `<audio controls>`).
class SessionAudioPlayer extends StatefulWidget {
  const SessionAudioPlayer({super.key, required this.url});

  final String url;

  @override
  State<SessionAudioPlayer> createState() => _SessionAudioPlayerState();
}

class _SessionAudioPlayerState extends State<SessionAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = Duration.zero);
    }));
  }

  @override
  void didUpdateWidget(covariant SessionAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _player.stop();
      setState(() {
        _pos = Duration.zero;
        _dur = Duration.zero;
        _failed = false;
      });
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else if (_state == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final max = _dur.inMilliseconds <= 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: t.muted, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
                _state == PlayerState.playing ? Icons.pause : Icons.play_arrow,
                color: t.foreground),
          ),
          Text('${_fmt(_pos)} / ${_fmt(_dur)}',
              style: AppText.mono(context, size: 11)),
          Expanded(
            child: Slider(
              value: _pos.inMilliseconds.clamp(0, max).toDouble(),
              max: max,
              onChanged: _dur == Duration.zero
                  ? null
                  : (v) => _player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          if (_failed)
            Icon(Icons.error_outline, size: 16, color: t.destructive),
        ],
      ),
    );
  }
}
