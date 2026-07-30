import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'voice_service.dart';

/// Cross-platform VoiceService implementation using:
///   - `speech_to_text` plugin for STT (SFSpeechRecognizer on iOS, Google Speech on Android)
///   - `flutter_tts` for TTS (AVSpeechSynthesizer on iOS, Android TTS engine)
///
/// Sentence-chunked TTS queue for streaming model output in live voice mode.
class RescueMeshVoiceService implements VoiceService {
  RescueMeshVoiceService();

  final _stt = SpeechToText();
  final _tts = FlutterTts();

  bool _sttInitialized = false;
  bool _ttsInitialized = false;
  bool _disposed = false;
  bool _listening = false;
  bool _speaking = false;
  String _lastTranscript = '';

  VoiceOption? _currentVoice;
  double _speechRate = 0.5;
  Duration _listeningPatience = const Duration(seconds: 5);
  bool _voiceAutoPickAttempted = false;
  static const _kPrefVoiceName = 'tts_voice_name';
  static const _kPrefVoiceLocale = 'tts_voice_locale';
  static const _kPrefVoiceQuality = 'tts_voice_quality';
  static const _kPrefVoiceGender = 'tts_voice_gender';
  static const _kPrefSpeechRate = 'tts_speech_rate';
  static const _kPrefListeningPatience = 'stt_listening_patience_s';
  static const _kPrefPatienceDefaultMigration = 'stt_patience_default_5_v1';

  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  final _speakingController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  final _ttsBuffer = StringBuffer();
  final _ttsQueue = <String>[];
  bool _ttsDraining = false;

  static final _boundaryRegex = RegExp(r'[.!?\n]');

  Future<void> _ensureInit() async {
    if (_sttInitialized && _ttsInitialized) return;
    if (!_sttInitialized) {
      try {
        _sttInitialized = await _stt.initialize(
          onError: (e) {
            debugPrint('[voice] STT error: $e');
            _errorController.add(e.errorMsg);
          },
          onStatus: (s) {
            debugPrint('[voice] STT status: $s');
            if (s == SpeechToText.notListeningStatus ||
                s == SpeechToText.doneStatus) {
              _listening = false;
            }
          },
          debugLogging: false,
        );
      } catch (e) {
        debugPrint('[voice] STT initialize failed: $e');
        _errorController.add('STT init failed: $e');
      }
    }
    if (!_ttsInitialized) {
      try {
        await _tts.setSharedInstance(true);
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.0);
        await _loadAndApplyPrefs();
        _tts.setStartHandler(() {
          _speaking = true;
          _speakingController.add(true);
        });
        _tts.setCompletionHandler(() {
          _speaking = false;
          _speakingController.add(false);
          _drainTtsQueue();
        });
        _tts.setCancelHandler(() {
          _speaking = false;
          _speakingController.add(false);
        });
        _tts.setErrorHandler((e) {
          debugPrint('[voice] TTS error: $e');
          _speaking = false;
          _speakingController.add(false);
        });
        _ttsInitialized = true;
      } catch (e) {
        debugPrint('[voice] TTS initialize failed: $e');
      }
    }
    if (_ttsInitialized && !_voiceAutoPickAttempted) {
      _voiceAutoPickAttempted = true;
      unawaited(_autoPickBestVoice());
    }
  }

  Future<void> _autoPickBestVoice() async {
    try {
      final picked = await _pickBestVoice();
      if (picked == null) return;
      _currentVoice = picked;
      try {
        await _tts.setVoice({'name': picked.name, 'locale': picked.locale});
      } catch (e) {
        debugPrint('[voice] auto-pick setVoice failed: $e');
        _currentVoice = null;
      }
    } catch (e) {
      debugPrint('[voice] auto-pick scan failed: $e');
    }
  }

  @override
  Future<VoiceStatus> getStatus() async {
    await _ensureInit();
    final micOk = await _stt.hasPermission;
    return VoiceStatus(
      sttReady: _sttInitialized,
      ttsReady: _ttsInitialized,
      micPermitted: micOk,
    );
  }

  @override
  bool get isRecording => _listening;

  @override
  Stream<String> get partialStream => _partialController.stream;

  @override
  Stream<String> get finalStream => _finalController.stream;

  @override
  Future<void> startRecording() async {
    if (_listening) return;
    await _ensureInit();
    if (!_sttInitialized) {
      throw StateError('Speech recognition not available');
    }
    _lastTranscript = '';
    _listening = true;
    try {
      await _stt.listen(
        onResult: _onSttResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
        pauseFor: _listeningPatience,
      );
    } catch (e) {
      _listening = false;
      debugPrint('[voice] listen() threw: $e');
      _errorController.add('Listen failed: $e');
      rethrow;
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    _lastTranscript = result.recognizedWords;
    if (_disposed) return;
    if (result.finalResult) {
      _listening = false;
      _finalController.add(_lastTranscript);
    } else {
      _partialController.add(_lastTranscript);
    }
  }

  @override
  Future<String> stopAndTranscribe() async {
    if (!_listening) return _lastTranscript;
    await _stt.stop();
    _listening = false;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _lastTranscript;
  }

  @override
  Future<void> cancelRecording() async {
    if (!_listening) return;
    await _stt.cancel();
    _listening = false;
    _lastTranscript = '';
  }

  @override
  bool get isSpeaking => _speaking || _ttsQueue.isNotEmpty;

  @override
  Stream<bool> get speakingStream => _speakingController.stream;

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    if (!_ttsInitialized) return;
    await stopSpeaking();
    _speaking = true;
    _speakingController.add(true);
    await _tts.speak(text);
  }

  @override
  Future<void> feedTtsChunk(String chunk) async {
    if (chunk.isEmpty) return;
    await _ensureInit();
    if (!_ttsInitialized) return;
    _ttsBuffer.write(chunk);

    var text = _ttsBuffer.toString();
    while (true) {
      final match = _boundaryRegex.firstMatch(text);
      if (match == null) break;
      final endIdx = match.end;
      final sentence = text.substring(0, endIdx).trim();
      text = text.substring(endIdx);
      if (sentence.isNotEmpty) _ttsQueue.add(sentence);
    }
    _ttsBuffer
      ..clear()
      ..write(text);

    _drainTtsQueue();
  }

  @override
  Future<void> flushTts() async {
    final remainder = _ttsBuffer.toString().trim();
    _ttsBuffer.clear();
    if (remainder.isNotEmpty) _ttsQueue.add(remainder);
    _drainTtsQueue();
  }

  void _drainTtsQueue() {
    if (_ttsDraining || _speaking) return;
    if (_ttsQueue.isEmpty) return;
    _ttsDraining = true;
    final next = _ttsQueue.removeAt(0);
    _tts.speak(next).then((_) {
      _ttsDraining = false;
    }).catchError((Object e) {
      debugPrint('[voice] TTS speak error: $e');
      _ttsDraining = false;
      _drainTtsQueue();
    });
  }

  @override
  Future<void> stopSpeaking() async {
    _ttsBuffer.clear();
    _ttsQueue.clear();
    _ttsDraining = false;
    if (_ttsInitialized) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _speaking = false;
    _speakingController.add(false);
  }

  @override
  VoiceOption? get currentVoice => _currentVoice;

  @override
  double get speechRate => _speechRate;

  @override
  Future<List<VoiceOption>> getAvailableVoices() async {
    await _ensureInit();
    if (!_ttsInitialized) return const [];
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];

      final shortlist = <VoiceOption>[];
      final seenNames = <String>{};
      for (final v in raw) {
        if (v is! Map) continue;
        final name = (v['name'] as String?) ?? '';
        final locale = (v['locale'] as String?) ?? '';
        if (name.isEmpty) continue;
        if (!locale.toLowerCase().startsWith('en')) continue;
        final quality = (v['quality'] as String?)?.toLowerCase() ?? '';
        if (quality != 'enhanced' && quality != 'premium') continue;
        if (!seenNames.add(name)) continue;
        shortlist.add(VoiceOption(
          name: name,
          locale: locale,
          quality: quality,
          gender: (v['gender'] as String?)?.toLowerCase() ?? '',
        ));
      }

      int qRank(String q) => q == 'premium' ? 0 : 1;
      int lRank(String l) => l.toLowerCase() == 'en-us' ? 0 : 1;
      shortlist.sort((a, b) {
        final byQ = qRank(a.quality).compareTo(qRank(b.quality));
        if (byQ != 0) return byQ;
        final byL = lRank(a.locale).compareTo(lRank(b.locale));
        if (byL != 0) return byL;
        return a.name.compareTo(b.name);
      });
      return shortlist;
    } catch (e) {
      debugPrint('[voice] getVoices failed: $e');
      return const [];
    }
  }

  Future<VoiceOption?> _pickBestVoice() async {
    final voices = await getAvailableVoices();
    if (voices.isEmpty) return null;
    return voices.first;
  }

  @override
  Future<void> setVoice(VoiceOption voice) async {
    await _ensureInit();
    if (!_ttsInitialized) return;
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      _currentVoice = voice;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefVoiceName, voice.name);
      await prefs.setString(_kPrefVoiceLocale, voice.locale);
      await prefs.setString(_kPrefVoiceQuality, voice.quality);
      await prefs.setString(_kPrefVoiceGender, voice.gender);
    } catch (e) {
      debugPrint('[voice] setVoice failed: $e');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(0.3, 0.7);
    _speechRate = clamped;
    try {
      await _tts.setSpeechRate(clamped);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPrefSpeechRate, clamped);
    } catch (e) {
      debugPrint('[voice] setSpeechRate failed: $e');
    }
  }

  @override
  Duration get listeningPatience => _listeningPatience;

  @override
  Future<void> setListeningPatience(Duration value) async {
    final seconds = value.inSeconds.clamp(3, 10);
    _listeningPatience = Duration(seconds: seconds);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefListeningPatience, seconds);
    } catch (e) {
      debugPrint('[voice] setListeningPatience failed: $e');
    }
  }

  @override
  Future<void> previewVoice(VoiceOption voice, String text) async {
    await _ensureInit();
    if (!_ttsInitialized) return;
    await stopSpeaking();
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      await _tts.speak(text);
      if (_currentVoice != null) {
        unawaited(_restoreVoiceAfterPreview());
      }
    } catch (e) {
      debugPrint('[voice] previewVoice failed: $e');
    }
  }

  Future<void> _restoreVoiceAfterPreview() async {
    while (_speaking) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final v = _currentVoice;
    if (v != null) {
      try {
        await _tts.setVoice({'name': v.name, 'locale': v.locale});
      } catch (_) {}
    }
  }

  Future<void> _loadAndApplyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rate = prefs.getDouble(_kPrefSpeechRate);
      _speechRate = (rate ?? 0.5).clamp(0.3, 0.7);
      await _tts.setSpeechRate(_speechRate);
      final migrated =
          prefs.getBool(_kPrefPatienceDefaultMigration) ?? false;
      if (!migrated) {
        await prefs.remove(_kPrefListeningPatience);
        await prefs.setBool(_kPrefPatienceDefaultMigration, true);
      }
      final patience = prefs.getInt(_kPrefListeningPatience);
      _listeningPatience = Duration(seconds: (patience ?? 5).clamp(3, 10));
    } catch (e) {
      debugPrint('[voice] _loadAndApplyPrefs: $e');
      _speechRate = 0.5;
      await _tts.setSpeechRate(_speechRate);
      _listeningPatience = const Duration(seconds: 5);
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await cancelRecording();
    await stopSpeaking();
    await _partialController.close();
    await _finalController.close();
    await _speakingController.close();
    await _errorController.close();
  }

  @override
  Stream<String> get errorStream => _errorController.stream;
}
