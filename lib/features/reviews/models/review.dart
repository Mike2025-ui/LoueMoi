import 'package:equatable/equatable.dart';

class Review extends Equatable {
  final String id;
  final String propertyId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'].toString(),
      propertyId: json['property_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] as String? ?? 'Utilisateur',
      userPhoto: json['user_photo'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ??
          (num.tryParse(json['rating']?.toString() ?? '')?.toDouble() ?? 5.0),
      comment: json['comment'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'property_id': propertyId,
        'user_id': userId,
        'user_name': userName,
        'user_photo': userPhoto,
        'rating': rating,
        'comment': comment,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, propertyId, userId, userName, userPhoto, rating, comment, createdAt];
}
