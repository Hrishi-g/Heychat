/// UserModel represents user profile data.
/// Includes fromJson and toJson methods for API serialization.
class UserModel {
  final String mblNo;
  final String name;
  final String? email;
  final String? imgUrl;
  final String? gender;
  final String? dob;

  UserModel({
    required this.mblNo,
    required this.name,
    this.email,
    this.imgUrl,
    this.gender,
    this.dob,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      mblNo: json['mblNo'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      imgUrl: json['imgUrl'],
      gender: json['gender'],
      dob: json['dob'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mblNo': mblNo,
      'name': name,
      'email': email,
      'imgUrl': imgUrl,
      'gender': gender,
      'dob': dob,
    };
  }
}

