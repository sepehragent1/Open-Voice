class TurnConfig {
  const TurnConfig({
    required this.name,
    required this.turnUrl,
    required this.username,
    required this.password,
  });

  final String name;
  final String turnUrl;
  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
    'name': name,
    'turnUrl': turnUrl,
    'username': username,
    'password': password,
  };

  factory TurnConfig.fromJson(Map<String, dynamic> json) {
    return TurnConfig(
      name: json['name'] as String,
      turnUrl: json['turnUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}
