import 'dart:async';
import 'dart:convert';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Text-to-speech plus offline speech recognition powered by the Vosk engine.
class VoiceService {
  VoiceService();

  static const String _modelAssetPath = 'assets/models/vosk-model-small-en-us-0.15.zip';
  static const int _sampleRate = 16000;

  final FlutterTts _tts = FlutterTts();
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;

  final StreamController<String> _partialController = StreamController<String>.broadcast();
  final StreamController<String> _resultController = StreamController<String>.broadcast();
  String? _lastPartialText;
  bool _isListeningActive = false;
  Completer<void>? _speakingCompleter;

  // TTS queue to ensure sequential speaking
  final List<String> _ttsQueue = [];
  bool _isSpeaking = false;
  double _currentVolume = 1.0;

  Stream<String> get partialResults => _partialController.stream;
  Stream<String> get finalResults => _resultController.stream;

  /// Provides the most recent buffered speech text, typically used when a
  /// final recognition result arrives empty but a partial transcript exists.
  String? consumeResidualTranscript() => _consumeLastPartial();

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(_currentVolume);
  }

  Future<void> speak(String message) async {
    if (message.isEmpty) {
      return;
    }
    
    // Add to queue and process
    _ttsQueue.add(message);
    _processTtsQueue();
    if (_speakingCompleter != null) {
      await _speakingCompleter!.future;
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _currentVolume = clamped;
    await _tts.setVolume(clamped);
  }

  double get volume => _currentVolume;

  Future<void> _processTtsQueue() async {
    if (_isSpeaking || _ttsQueue.isEmpty) {
      return;
    }

    _isSpeaking = true;
    _speakingCompleter = Completer<void>();

    try {
      while (_ttsQueue.isNotEmpty) {
        final message = _ttsQueue.removeAt(0);
        final shouldResume = await _pauseListeningForSpeech();
        try {
          await _tts.speak(message);
        } catch (e) {
          // Continue to next item even if one fails
        } finally {
          if (shouldResume) {
            await _resumeListeningAfterSpeech();
          }
        }
      }
    } finally {
      _isSpeaking = false;
      _speakingCompleter?.complete();
      _speakingCompleter = null;
    }
  }

  Future<bool> startListening() async {
    if (!await _ensureMicrophonePermission()) {
      return false;
    }

    await _ensureRecognizerReady();
    if (_recognizer == null) {
      return false;
    }

    _speechService ??= await _vosk.initSpeechService(_recognizer!);

    if (_partialSubscription == null || _resultSubscription == null) {
      await _attachStreams(_speechService!);
    }

    if (_isListeningActive) {
      return true;
    }

    final started = await _startSpeechService();
    return started;
  }

  Future<void> stopListening() async {
    if (_speechService != null) {
      await _speechService!.stop();
    }
    await _detachStreams();
    _isListeningActive = false;
  }

  Future<void> resetRecognizer() async {
    await _recognizer?.reset();
    _lastPartialText = null;
  }

  Future<void> dispose() async {
    await stopListening();
    await _speechService?.dispose();
    _speechService = null;

    await _partialController.close();
    await _resultController.close();

    await _recognizer?.dispose();
    _recognizer = null;

    _model?.dispose();
    _model = null;

    await _tts.stop();
  }

  Future<void> _ensureRecognizerReady() async {
    if (_model != null && _recognizer != null) {
      return;
    }

    final loader = ModelLoader();
    final modelPath = await loader.loadFromAssets(_modelAssetPath);

    _model ??= await _vosk.createModel(modelPath);
    _recognizer ??= await _vosk.createRecognizer(
      model: _model!,
      sampleRate: _sampleRate,
    );

    if (_recognizer != null) {
      await _recognizer!.setWords(words: true);
      await _recognizer!.setPartialWords(partialWords: true);
      await _recognizer!.setMaxAlternatives(3);
    }
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final requestStatus = await Permission.microphone.request();
    return requestStatus.isGranted;
  }

  Future<void> _attachStreams(SpeechService service) async {
    await _detachStreams();

    _partialSubscription = service.onPartial().listen((payload) {
      final text = _extractText(payload);
      if (text != null && text.isNotEmpty) {
        _lastPartialText = text;
        _partialController.add(text);
      }
    });

    _resultSubscription = service.onResult().listen((payload) {
      final text = _extractText(payload);
      if (text != null) {
        _lastPartialText = null;
        _resultController.add(text);
      }
    });
  }

  Future<void> _detachStreams() async {
    await _partialSubscription?.cancel();
    await _resultSubscription?.cancel();
    _partialSubscription = null;
    _resultSubscription = null;
    _lastPartialText = null;
  }

  String? _extractText(String payload) {
    if (payload.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
      final text = (data['text'] as String?) ?? (data['partial'] as String?);
      if (text == null) {
        return _consumeLastPartial();
      }
      final trimmed = text.trim();
      return trimmed.isEmpty ? _consumeLastPartial() : trimmed;
    } catch (_) {
      final trimmed = payload.trim();
      return trimmed.isEmpty ? _consumeLastPartial() : trimmed;
    }
  }

  String? _consumeLastPartial() {
    if (_lastPartialText == null) {
      return null;
    }
    final value = _lastPartialText;
    _lastPartialText = null;
    return value;
  }

  Future<bool> _startSpeechService() async {
    if (_speechService == null) {
      return false;
    }

    final started = await _speechService!.start(
      onRecognitionError: (Object? error) {
        _resultController.addError(error ?? 'Speech recognition error');
      },
    );

    _isListeningActive = started ?? false;
    return started ?? false;
  }

  Future<bool> _pauseListeningForSpeech() async {
    if (!_isListeningActive || _speechService == null) {
      return false;
    }

    try {
      await _speechService!.stop();
    } finally {
      _isListeningActive = false;
    }

    return true;
  }

  Future<void> _resumeListeningAfterSpeech() async {
    if (_speechService == null) {
      return;
    }

    final restarted = await _startSpeechService();
    if (!restarted) {
      _isListeningActive = false;
    }
  }
}
