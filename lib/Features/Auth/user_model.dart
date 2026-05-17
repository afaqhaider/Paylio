class UserModel {
  final int? id;
  final String ledgixId; // Unique LedGix User ID
  final String? username;
  final String name;
  final String email;
  final String? password;
  final String? profilePhoto;
  final String? phoneNumber;
  final String? preferredCurrency;
  final String? country;
  final String? themePreference; // 'light', 'dark', 'system'

  UserModel({
    this.id,
    required this.ledgixId,
    this.username,
    required this.name,
    required this.email,
    this.password,
    this.profilePhoto,
    this.phoneNumber,
    this.preferredCurrency,
    this.country,
    this.themePreference,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgixId': ledgixId,
      'username': username,
      'name': name,
      'email': email,
      'password': password,
      'profilePhoto': profilePhoto,
      'phoneNumber': phoneNumber,
      'preferredCurrency': preferredCurrency,
      'country': country,
      'themePreference': themePreference,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      ledgixId: map['ledgixId'] ?? '',
      username: map['username'],
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      password: map['password'],
      profilePhoto: map['profilePhoto'],
      phoneNumber: map['phoneNumber'],
      preferredCurrency: map['preferredCurrency'],
      country: map['country'],
      themePreference: map['themePreference'] ?? 'system',
    );
  }

  UserModel copyWith({
    int? id,
    String? ledgixId,
    String? username,
    String? name,
    String? email,
    String? password,
    String? profilePhoto,
    String? phoneNumber,
    String? preferredCurrency,
    String? country,
    String? themePreference,
  }) {
    return UserModel(
      id: id ?? this.id,
      ledgixId: ledgixId ?? this.ledgixId,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      country: country ?? this.country,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}
