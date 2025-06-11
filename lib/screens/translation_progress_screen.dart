import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../services/api_service.dart';
import '../models/translation_models.dart';

class TranslationProgressScreen extends StatefulWidget {
  final String translationId;
  final String sourceLanguage;
  final String targetLanguage;
  final String originalAudioPath;

  const TranslationProgressScreen({
    super.key,
    required this.translationId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.originalAudioPath,
  });

  @override
  State<TranslationProgressScreen> createState() => _TranslationProgressScreenState();
}

class _TranslationProgressScreenState extends State<TranslationProgressScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  TranslationStatus? _currentStatus;
  Timer? _statusTimer;
  String? _translatedAudioPath;
  bool _isPlayingOriginal = false;
  bool _isPlayingTranslated = false;
  bool _isDownloading = false;

  // Animaciones
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startStatusPolling();
    _setupAudioPlayer();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlayingOriginal = false;
        _isPlayingTranslated = false;
      });
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _progressController.dispose();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startStatusPolling() {
    _fetchStatus(); // Primera consulta inmediata
    
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentStatus?.isCompleted == true || _currentStatus?.isFailed == true) {
        timer.cancel();
        return;
      }
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await _apiService.getTranslationStatus(widget.translationId);
      
      setState(() {
        _currentStatus = status;
      });

      // Animar progreso
      _progressController.animateTo(status.progress / 100.0);

      // Si se completó, descargar automáticamente
      if (status.isCompleted && _translatedAudioPath == null) {
        _downloadTranslatedAudio();
      }

      print('Status actualizado: ${status.status} - ${status.progress}%');
    } catch (e) {
      print('Error fetching status: $e');
    }
  }

  Future<void> _downloadTranslatedAudio() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      print('Descargando audio traducido...');
      
      final audioBytes = await _apiService.downloadTranslatedAudio(widget.translationId);
      
      // Guardar en storage local
      final directory = await getApplicationDocumentsDirectory();
      final translatedDir = Directory('${directory.path}/translated');
      if (!await translatedDir.exists()) {
        await translatedDir.create(recursive: true);
      }

      final fileName = 'translated_${widget.translationId}.wav';
      final file = File('${translatedDir.path}/$fileName');
      await file.writeAsBytes(audioBytes);

      setState(() {
        _translatedAudioPath = file.path;
        _isDownloading = false;
      });

      print('Audio traducido guardado: ${file.path}');
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      _showErrorDialog('Error al descargar audio: $e');
    }
  }

  Future<void> _playOriginalAudio() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingOriginal = true;
        _isPlayingTranslated = false;
      });
      await _audioPlayer.play(DeviceFileSource(widget.originalAudioPath));
    } catch (e) {
      _showErrorDialog('Error al reproducir audio original: $e');
    }
  }

  Future<void> _playTranslatedAudio() async {
    if (_translatedAudioPath == null) return;

    try {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingTranslated = true;
        _isPlayingOriginal = false;
      });
      await _audioPlayer.play(DeviceFileSource(_translatedAudioPath!));
    } catch (e) {
      _showErrorDialog('Error al reproducir audio traducido: $e');
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlayingOriginal = false;
      _isPlayingTranslated = false;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _retryTranslation() {
    // TODO: Implementar retry
    Navigator.pop(context);
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _getLanguageDisplayName(String code) {
    final languages = {
      'es': '🇪🇸 Español',
      'en': '🇺🇸 English',
      'fr': '🇫🇷 Français',
      'pt': '🇧🇷 Português',
      'it': '🇮🇹 Italiano',
      'de': '🇩🇪 Deutsch',
    };
    return languages[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final status = _currentStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traduciendo Audio'),
        leading: status?.isCompleted == true || status?.isFailed == true
            ? IconButton(
                icon: const Icon(Icons.home),
                onPressed: _goHome,
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Información de traducción
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.mic, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            _getLanguageDisplayName(widget.sourceLanguage),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: status?.isProcessing == true ? _pulseAnimation.value : 1.0,
                          child: const Icon(Icons.arrow_forward, size: 24),
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.volume_up, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            _getLanguageDisplayName(widget.targetLanguage),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Estado y progreso
            if (status != null) ...[
              // Icono de estado
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(status.statusColor).withOpacity(0.1),
                ),
                child: Icon(
                  IconData(status.statusIcon, fontFamily: 'MaterialIcons'),
                  size: 40,
                  color: Color(status.statusColor),
                ),
              ),

              const SizedBox(height: 24),

              // Estado actual
              Text(
                status.currentStep,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Barra de progreso
              if (status.isProcessing || status.isQueued) ...[
                LinearProgressIndicator(
                  value: status.progress / 100.0,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(status.statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${status.progress}%'),
              ],

              const SizedBox(height: 16),

              // Tiempo estimado
              if (status.estimatedTimeRemaining != null && status.isProcessing)
                Text(
                  'Tiempo estimado: ${status.estimatedTimeRemaining}',
                  style: const TextStyle(color: Colors.grey),
                ),

              // Error message
              if (status.isFailed && status.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    status.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ] else ...[
              // Loading inicial
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Obteniendo estado...'),
            ],

            const Spacer(),

            // Controles de audio (solo si está completado)
            if (status?.isCompleted == true) ...[
              const Text(
                '¡Traducción completada!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),

              // Controles de reproducción
              Row(
                children: [
                  // Audio original
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.mic, size: 32),
                            const SizedBox(height: 8),
                            const Text('Original'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isPlayingOriginal ? _stopAudio : _playOriginalAudio,
                              icon: Icon(_isPlayingOriginal ? Icons.stop : Icons.play_arrow),
                              label: Text(_isPlayingOriginal ? 'Parar' : 'Reproducir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPlayingOriginal ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Audio traducido
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.volume_up, size: 32),
                            const SizedBox(height: 8),
                            const Text('Traducido'),
                            const SizedBox(height: 12),
                            if (_isDownloading)
                              const CircularProgressIndicator()
                            else if (_translatedAudioPath != null)
                              ElevatedButton.icon(
                                onPressed: _isPlayingTranslated ? _stopAudio : _playTranslatedAudio,
                                icon: Icon(_isPlayingTranslated ? Icons.stop : Icons.play_arrow),
                                label: Text(_isPlayingTranslated ? 'Parar' : 'Reproducir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isPlayingTranslated ? Colors.red : Colors.green,
                                ),
                              )
                            else
                              const Text('Descargando...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Botón para nueva traducción
              ElevatedButton.icon(
                onPressed: _goHome,
                icon: const Icon(Icons.add),
                label: const Text('Nueva Traducción'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],

            // Botón de retry si falló
            if (status?.isFailed == true) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _goHome,
                      icon: const Icon(Icons.home),
                      label: const Text('Inicio'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _retryTranslation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}