import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/translation_models.dart';

class ApiService {
  // URL base de tu API Docker
  // NOTA: Para emulador usar 10.0.2.2, para dispositivo físico usar la IP de tu PC
  // static const String baseUrl = 'http://192.168.1.2'; // Para emulador Android
  static const String baseUrl = 'http://192.168.1.2:8080'; // Para dispositivo físico
  
  static const String apiEndpoint = '$baseUrl/api/v1/AudioTranslation';
  static const Duration timeoutDuration = Duration(seconds: 30);

  /// Verifica si la API está disponible
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeoutDuration);
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error verificando conexión con el servicio: $e');
      return false;
    }
  }

  /// Sube un archivo de audio para traducción
  Future<TranslationResponse> uploadAudio({
    required File audioFile,
    required String sourceLanguage,
    required String targetLanguage,
    String? userId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
      
      // Agregar archivo de audio
      final audioMultipart = await http.MultipartFile.fromPath(
        'AudioFile',
        audioFile.path,
        filename: 'audio.m4a',
      );
      request.files.add(audioMultipart);
      
      // Agregar campos del formulario
      request.fields['SourceLanguage'] = sourceLanguage;
      request.fields['TargetLanguage'] = targetLanguage;
      if (userId != null) {
        request.fields['UserId'] = userId;
      }
      
      // Enviar request
      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 202) {
        final jsonData = json.decode(response.body);
        return TranslationResponse.fromJson(jsonData);
      } else {
        throw ApiException(
          'Error al subir audio: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ApiException('Error de red al subir audio', e.toString());
    }
  }

  /// Obtiene el estado de una traducción
  Future<TranslationStatus> getTranslationStatus(String translationId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiEndpoint/$translationId/status'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return TranslationStatus.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException('Traducción no encontrada', response.body);
      } else {
        throw ApiException(
          'Error al obtener estado: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ApiException('Error de red al obtener estado', e.toString());
    }
  }

  /// Descarga el audio traducido
  Future<List<int>> downloadTranslatedAudio(String translationId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiEndpoint/$translationId/download'),
      ).timeout(const Duration(minutes: 2)); // Timeout más largo para descarga
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw ApiException('Audio traducido no encontrado', response.body);
      } else if (response.statusCode == 409) {
        throw ApiException('La traducción aún no está completada', response.body);
      } else {
        throw ApiException(
          'Error al descargar audio: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ApiException('Error de red al descargar audio', e.toString());
    }
  }

  /// Cancela una traducción en proceso
  Future<bool> cancelTranslation(String translationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiEndpoint/$translationId'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeoutDuration);
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelando traducción: $e');
      return false;
    }
  }

  /// Obtiene el historial de traducciones del usuario
  Future<List<TranslationStatus>> getTranslationHistory({String? userId}) async {
    try {
      String url = '$apiEndpoint/history';
      if (userId != null) {
        url += '?userId=$userId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final jsonList = json.decode(response.body) as List;
        return jsonList.map((json) => TranslationStatus.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Error al obtener historial: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw ApiException('Error de red al obtener historial', e.toString());
    }
  }
}

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final String message;
  final String details;
  
  ApiException(this.message, this.details);
  
  @override
  String toString() => 'ApiException: $message\nDetails: $details';
}