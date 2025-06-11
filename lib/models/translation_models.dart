class TranslationResponse {
  final String translationId;
  final String status;
  final String message;
  final DateTime createdAt;
  final String? estimatedCompletionTime;

  TranslationResponse({
    required this.translationId,
    required this.status,
    required this.message,
    required this.createdAt,
    this.estimatedCompletionTime,
  });

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    return TranslationResponse(
      translationId: json['translationId'] as String,
      status: json['status'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      estimatedCompletionTime: json['estimatedCompletionTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'translationId': translationId,
      'status': status,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'estimatedCompletionTime': estimatedCompletionTime,
    };
  }
}

class TranslationStatus {
  final String translationId;
  final String status;
  final int progress;
  final String currentStep;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? estimatedTimeRemaining;

  TranslationStatus({
    required this.translationId,
    required this.status,
    required this.progress,
    required this.currentStep,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.estimatedTimeRemaining,
  });

  factory TranslationStatus.fromJson(Map<String, dynamic> json) {
    return TranslationStatus(
      translationId: json['translationId'] as String,
      status: json['status'] as String,
      progress: json['progress'] as int,
      currentStep: json['currentStep'] as String,
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      estimatedTimeRemaining: json['estimatedTimeRemaining'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'translationId': translationId,
      'status': status,
      'progress': progress,
      'currentStep': currentStep,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'estimatedTimeRemaining': estimatedTimeRemaining,
    };
  }

  // Estados útiles
  bool get isCompleted => status == 'Completed';
  bool get isFailed => status == 'Failed';
  bool get isProcessing => status == 'ProcessingSpeechToText' || 
                          status == 'ProcessingTranslation' || 
                          status == 'ProcessingTextToSpeech';
  bool get isQueued => status == 'Queued';
  bool get canDownload => isCompleted;
  bool get canRetry => isFailed;

  // Color del estado para UI
  int get statusColor {
    switch (status) {
      case 'Completed':
        return 0xFF4CAF50; // Verde
      case 'Failed':
        return 0xFFF44336; // Rojo
      case 'Queued':
        return 0xFFFF9800; // Naranja
      default:
        return 0xFF2196F3; // Azul (procesando)
    }
  }

  // Icono del estado
  int get statusIcon {
    switch (status) {
      case 'Completed':
        return 0xe5ca; // Icons.check_circle
      case 'Failed':
        return 0xe000; // Icons.error
      case 'Queued':
        return 0xe8b5; // Icons.schedule
      default:
        return 0xe863; // Icons.refresh (procesando)
    }
  }
}

class AudioRecording {
  final String filePath;
  final Duration duration;
  final DateTime recordedAt;
  final String sourceLanguage;
  final String targetLanguage;

  AudioRecording({
    required this.filePath,
    required this.duration,
    required this.recordedAt,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'duration': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    };
  }

  factory AudioRecording.fromJson(Map<String, dynamic> json) {
    return AudioRecording(
      filePath: json['filePath'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
    );
  }
}

class TranslationItem {
  final String id;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  final TranslationStatus status;
  final String? originalAudioPath;
  final String? translatedAudioPath;
  final Duration? originalDuration;

  TranslationItem({
    required this.id,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.status,
    this.originalAudioPath,
    this.translatedAudioPath,
    this.originalDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toJson(),
      'originalAudioPath': originalAudioPath,
      'translatedAudioPath': translatedAudioPath,
      'originalDuration': originalDuration?.inMilliseconds,
    };
  }

  factory TranslationItem.fromJson(Map<String, dynamic> json) {
    return TranslationItem(
      id: json['id'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: TranslationStatus.fromJson(json['status'] as Map<String, dynamic>),
      originalAudioPath: json['originalAudioPath'] as String?,
      translatedAudioPath: json['translatedAudioPath'] as String?,
      originalDuration: json['originalDuration'] != null 
          ? Duration(milliseconds: json['originalDuration'] as int)
          : null,
    );
  }

  // Método de conveniencia para crear desde TranslationStatus
  factory TranslationItem.fromStatus(TranslationStatus status, String sourceLanguage, String targetLanguage) {
    return TranslationItem(
      id: status.translationId,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      createdAt: status.createdAt,
      status: status,
    );
  }
}