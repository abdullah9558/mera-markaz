class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.city = '',
    this.province = '',
    this.occupation = '',
    this.photoUrl,
    this.isGuest = false,
  });

  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final String province;
  final String occupation;
  final String? photoUrl;
  final bool isGuest;

  String get firstName {
    final value = fullName.trim();
    return value.isEmpty ? '' : value.split(RegExp(r'\s+')).first;
  }

  int get completedFields => [
    fullName,
    email,
    phone,
    city,
    province,
    occupation,
  ].where((value) => value.trim().isNotEmpty).length;

  double get completion => completedFields / 6;

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? city,
    String? province,
    String? occupation,
    String? photoUrl,
  }) => UserProfile(
    userId: userId,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    city: city ?? this.city,
    province: province ?? this.province,
    occupation: occupation ?? this.occupation,
    photoUrl: photoUrl ?? this.photoUrl,
    isGuest: isGuest,
  );

  Map<String, Object?> toJson() => {
    'userId': userId,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'city': city,
    'province': province,
    'occupation': occupation,
    'photoUrl': photoUrl,
    'isGuest': isGuest,
  };

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
    userId: json['userId'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    province: json['province'] as String? ?? '',
    occupation: json['occupation'] as String? ?? '',
    photoUrl: json['photoUrl'] as String?,
    isGuest: json['isGuest'] as bool? ?? false,
  );
}
