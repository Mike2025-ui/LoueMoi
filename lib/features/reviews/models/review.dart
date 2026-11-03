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
    final rawRating = json['rating'];
    final double rating = rawRating is num
        ? rawRating.toDouble()
        : (double.tryParse(rawRating?.toString() ?? '') ?? 5.0);

    return Review(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Utilisateur',
      userPhoto: json['user_photo']?.toString(),
      rating: rating,
      comment: json['comment']?.toString() ?? '',
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
