import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/translation_models.dart';

class TranslationHistoryScreen extends StatefulWidget {
  const TranslationHistoryScreen({super.key});

  @override
  State<TranslationHistoryScreen> createState() => _TranslationHistoryScreenState();
}

class _TranslationHistoryScreenState extends State<TranslationHistoryScreen> {
  List<TranslationItem> _translations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('translation_history') ?? [];
      
      setState(() {
        _translations = historyJson
            .map((jsonStr) => TranslationItem.fromJson(json.decode(jsonStr)))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Más recientes primero
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTranslation(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('translation_history') ?? [];
      
      // Filtrar el item a eliminar
      final updatedHistory = historyJson.where((jsonStr) {
        final item = TranslationItem.fromJson(json.decode(jsonStr));
        return item.id != id;
      }).toList();
      
      await prefs.setStringList('translation_history', updatedHistory);
      
      setState(() {
        _translations.removeWhere((item) => item.id == id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traducción eliminada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Historial'),
        content: const Text('¿Estás seguro de que quieres eliminar todo el historial?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Todo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('translation_history');
      
      setState(() {
        _translations.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial eliminado')),
      );
    }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'N/A';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          if (_translations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _translations.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay traducciones',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus traducciones aparecerán aquí',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.mic),
            label: const Text('Crear Primera Traducción'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _translations.length,
      itemBuilder: (context, index) {
        final translation = _translations[index];
        return _buildTranslationCard(translation);
      },
    );
  }

  Widget _buildTranslationCard(TranslationItem translation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con idiomas y estado
            Row(
              children: [
                // Idiomas
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        _getLanguageDisplayName(translation.sourceLanguage).split(' ')[0],
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _getLanguageDisplayName(translation.targetLanguage).split(' ')[0],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
                
                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(translation.status.statusColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(translation.status.statusColor),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        IconData(translation.status.statusIcon, fontFamily: 'MaterialIcons'),
                        size: 16,
                        color: Color(translation.status.statusColor),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        translation.status.status,
                        style: TextStyle(
                          color: Color(translation.status.statusColor),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Menú
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteTranslation(translation.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Información adicional
            Row(
              children: [
                // Fecha
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(translation.createdAt),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                // Duración (si está disponible)
                if (translation.originalDuration != null)
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(translation.originalDuration),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),

            // Progreso si está procesando
            if (translation.status.isProcessing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: translation.status.progress / 100.0,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(translation.status.statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${translation.status.progress}% - ${translation.status.currentStep}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            // Error message si falló
            if (translation.status.isFailed && translation.status.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translation.status.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Acciones si está completado
            if (translation.status.isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Reproducir audio original
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Función en desarrollo')),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Original', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Reproducir audio traducido
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Función en desarrollo')),
                        );
                      },
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: const Text('Traducido', style: TextStyle(fontSize: 12)),
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