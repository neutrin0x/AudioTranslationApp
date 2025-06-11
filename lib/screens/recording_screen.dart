import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../services/api_service.dart';
import 'translation_progress_screen.dart';

class RecordingScreen extends StatefulWidget {
  final String sourceLanguage;
  final String targetLanguage;

  const RecordingScreen({
    super.key,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();

  bool _isRecording = false;
  bool _isUploading = false;
  String? _audioPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;

  // Animaciones
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Verificar permisos
      if (!await _audioRecorder.hasPermission()) {
        _showErrorDialog('Sin permisos de micrófono');
        return;
      }

      // Crear directorio para grabaciones
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Configurar path del archivo
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _audioPath = '${recordingsDir.path}/$fileName';

      // Configurar grabación
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // Compatible con la API
        bitRate: 128000,
        sampleRate: 16000,
      );

      // Iniciar grabación
      await _audioRecorder.start(config, path: _audioPath!);

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Iniciar animaciones
      _pulseController.repeat(reverse: true);
      _waveController.repeat();

      // Iniciar timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
      });

      print('Grabación iniciada: $_audioPath');
    } catch (e) {
      _showErrorDialog('Error al iniciar grabación: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      // Detener grabación
      await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      // Detener animaciones y timer
      _pulseController.stop();
      _waveController.stop();
      _timer?.cancel();

      print('Grabación detenida: $_audioPath');

      // Verificar que el archivo existe
      if (_audioPath != null && await File(_audioPath!).exists()) {
        _showRecordingActions();
      } else {
        _showErrorDialog('Error: No se pudo guardar la grabación');
      }
    } catch (e) {
      _showErrorDialog('Error al detener grabación: $e');
    }
  }

  void _showRecordingActions() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Grabación completada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Duración: ${_formatDuration(_recordingDuration)}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _discardRecording,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _uploadRecording,
                    child: const Text('Traducir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadRecording() async {
    if (_audioPath == null) return;

    Navigator.pop(context); // Cerrar bottom sheet

    setState(() {
      _isUploading = true;
    });

    try {
      final audioFile = File(_audioPath!);
      
      // Verificar que el archivo existe y tiene contenido
      if (!await audioFile.exists() || await audioFile.length() == 0) {
        throw Exception('Archivo de audio no válido');
      }

      print('Subiendo archivo: $_audioPath (${await audioFile.length()} bytes)');

      // Subir a la API
      final response = await _apiService.uploadAudio(
        audioFile: audioFile,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );

      print('Upload exitoso: ${response.translationId}');

      // Navegar a pantalla de progreso
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TranslationProgressScreen(
              translationId: response.translationId,
              sourceLanguage: widget.sourceLanguage,
              targetLanguage: widget.targetLanguage,
              originalAudioPath: _audioPath!,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('Error en upload: $e');
      _showErrorDialog('Error al subir archivo: $e');
    }
  }

  void _discardRecording() {
    Navigator.pop(context); // Cerrar bottom sheet
    
    // Eliminar archivo
    if (_audioPath != null) {
      File(_audioPath!).deleteSync();
    }
    
    // Resetear estado
    setState(() {
      _audioPath = null;
      _recordingDuration = Duration.zero;
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grabar Audio'),
        leading: _isRecording || _isUploading
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isUploading
          ? _buildUploadingView()
          : _buildRecordingView(),
    );
  }

  Widget _buildUploadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Subiendo audio...',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Por favor espera',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Información de idiomas
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
                  const Icon(Icons.arrow_forward, size: 24),
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

          const Spacer(),

          // Visualización de grabación
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ondas de audio (cuando está grabando)
                if (_isRecording) ...[
                  AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 200 + (_waveAnimation.value * 100),
                        height: 200 + (_waveAnimation.value * 100),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(
                              0.3 - (_waveAnimation.value * 0.3)
                            ),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 160 + (_waveAnimation.value * 60),
                        height: 160 + (_waveAnimation.value * 60),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withOpacity(
                              0.5 - (_waveAnimation.value * 0.5)
                            ),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Botón central
                AnimatedBuilder(
                  animation: _isRecording ? _pulseAnimation : 
                             const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: ElevatedButton(
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(32),
                          minimumSize: const Size(120, 120),
                          backgroundColor: _isRecording 
                              ? Colors.red 
                              : Theme.of(context).colorScheme.primary,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Duración de grabación
          if (_isRecording)
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

          const Spacer(),

          // Instrucciones
          Text(
            _isRecording 
                ? 'Presiona el botón rojo para detener'
                : 'Presiona el micrófono para comenzar a grabar',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}