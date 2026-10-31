import 'dart:math';
import 'dart:typed_data';

import '../models/evidence.dart';

String imageOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final raw = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
}

class MediaFailure implements Exception {
  const MediaFailure(this.status, [this.code = '', this.retryAfter]);
  final int status;
  final String code;
  final int? retryAfter;
}

class SelectedImage {
  const SelectedImage({
    required this.bytes,
    required this.name,
    required this.mime,
  });
  final Uint8List bytes;
  final String name, mime;
}

class ImageReceipt {
  const ImageReceipt(this.operation, this.state, this.photoId, this.revision);
  final String operation, state;
  final String? photoId, revision;
  factory ImageReceipt.fromJson(Map<String, dynamic> data) {
    final op = data['operation_id']?.toString() ?? '';
    if (!evidenceUuid(op) ||
        !['processing', 'committed', 'failed'].contains(data['state']) ||
        (data['state'] == 'committed' &&
            !evidenceUuid(data['revision']?.toString() ?? ''))) {
      throw const MediaFailure(502);
    }
    return ImageReceipt(
      op,
      data['state'] as String,
      data['photo_id']?.toString(),
      data['revision']?.toString(),
    );
  }
}

class ReviewImage {
  const ReviewImage({
    required this.id,
    required this.revision,
    required this.reviewId,
    required this.description,
    required this.state,
    required this.imageUrl,
    required this.thumbUrl,
    this.canDelete = false,
    this.canReport = false,
    this.rejectionReason,
  });
  final String id, revision, description, state, imageUrl, thumbUrl;
  final int reviewId;
  final bool canDelete, canReport;
  final String? rejectionReason;
  factory ReviewImage.fromJson(Map<String, dynamic> data) {
    if (!evidenceUuid(data['id']?.toString() ?? '') ||
        !evidenceUuid(data['revision']?.toString() ?? '') ||
        data['review_id'] is! int ||
        !['pending', 'approved', 'rejected'].contains(data['state']) ||
        data['description'] is! String) {
      throw const MediaFailure(502);
    }
    return ReviewImage(
      id: data['id'],
      revision: data['revision'],
      reviewId: data['review_id'],
      description: data['description'],
      state: data['state'],
      imageUrl: data['image_url'],
      thumbUrl: data['thumb_url'],
      canDelete: data['can_delete'] == true,
      canReport: data['can_report'] == true,
      rejectionReason: data['rejection_reason'] as String?,
    );
  }
}

class PhotoPage {
  const PhotoPage(this.photos, this.next);
  final List<ReviewImage> photos;
  final Uri? next;
}

class AvatarData {
  const AvatarData({
    required this.version,
    required this.hasAvatar,
    this.legacy = '',
    this.imageUrl,
  });
  final String version, legacy;
  final bool hasAvatar;
  final String? imageUrl;
  factory AvatarData.fromJson(Map<String, dynamic> data) {
    if (!evidenceUuid(data['version']?.toString() ?? '') ||
        data['has_avatar'] is! bool) {
      throw const MediaFailure(502);
    }
    return AvatarData(
      version: data['version'],
      hasAvatar: data['has_avatar'],
      legacy: data['foto_perfil']?.toString() ?? '',
      imageUrl: data['image_url'],
    );
  }
}
