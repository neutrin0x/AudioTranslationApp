import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'recording_screen.dart';
import 'translation_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  String _selectedSourceLanguage = 'es';
  String _selectedTargetLanguage = 'en';
  bool _isConnectedToAPI = false;

  @override
  void initState() {
    super.initState();
    _checkAPIConnection();
  }

  Future<void> _checkAPIConnection() async {
    try {
      final isConnected = await _apiService.checkConnection();
      setState(() {
        _isConnectedToAPI = isConnected;
      });
    } catch (e) {
      setState(() {
        _isConnectedToAPI = false;
      });
    }
  }

  Future<void> _startRecording() async {
    // Verificar permisos
    final micPermission = await Permission.microphone.status;
    if (!micPermission.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _showPermissionDialog();
        return;
      }
    }

    // Navegar a pantalla de grabación
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecordingScreen(
            sourceLanguage: _selectedSourceLanguage,
            targetLanguage: _selectedTargetLanguage,
          ),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso Requerido'),
        content: const Text(
          'Para grabar audio necesitamos acceso al micrófono. '
          'Por favor, habilita el permiso en configuración.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Configuración'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(bool isSource) {
    final languages = {
      'es': '🇪🇸 Español',
      'en': '🇺🇸 English',
      'fr': '🇫🇷 Français',
      'pt': '🇧🇷 Português',
      'it': '🇮🇹 Italiano',
      'de': '🇩🇪 Deutsch',
    };

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSource ? 'Idioma de origen' : 'Idioma de destino',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...languages.entries.map((entry) => ListTile(
              leading: Text(entry.value.split(' ')[0], style: const TextStyle(fontSize: 24)),
              title: Text(entry.value.split(' ')[1]),
              trailing: (isSource ? _selectedSourceLanguage : _selectedTargetLanguage) == entry.key
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                setState(() {
                  if (isSource) {
                    _selectedSourceLanguage = entry.key;
                  } else {
                    _selectedTargetLanguage = entry.key;
                  }
                });
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
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
        title: const Text('Audio Translation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TranslationHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isConnectedToAPI ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnectedToAPI ? Colors.green : Colors.red,
            ),
            onPressed: _checkAPIConnection,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado de conexión
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isConnectedToAPI 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConnectedToAPI ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnectedToAPI ? Icons.check_circle : Icons.error,
                    color: _isConnectedToAPI ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnectedToAPI 
                        ? 'Servicio disponible'
                        : 'Desconectado',
                    style: TextStyle(
                      color: _isConnectedToAPI ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (!_isConnectedToAPI)
                    TextButton(
                      onPressed: _checkAPIConnection,
                      child: const Text('Reintentar'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Selector de idiomas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Configuración de idiomas',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Idioma de origen
                    ListTile(
                      leading: const Icon(Icons.mic),
                      title: const Text('Desde'),
                      subtitle: Text(_getLanguageDisplayName(_selectedSourceLanguage)),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () => _showLanguageSelector(true),
                    ),
                    
                    const Divider(),
                    
                    // Idioma de destino
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Hacia'),
                      subtitle: Text(_getLanguageDisplayName(_selectedTargetLanguage)),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () => _showLanguageSelector(false),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Botón principal de grabación
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Círculo de fondo
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ),
                  ),
                  
                  // Botón de grabación
                  ElevatedButton(
                    onPressed: _isConnectedToAPI ? _startRecording : null,
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(32),
                      minimumSize: const Size(120, 120),
                    ),
                    child: const Icon(
                      Icons.mic,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Texto instructivo
            Text(
              _isConnectedToAPI 
                  ? 'Presiona el micrófono para comenzar a grabar'
                  : 'Verifica que la API esté corriendo para continuar',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}