import '../../utils/constants.dart';
import '../../utils/utilities.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/api_urls.dart';

class Passenger {
  int id;
  String mobileNumber;
  String modelName;
  String name;
  String gender;
  String profileImage;

  Passenger(
      {this.id,
      this.mobileNumber,
      this.modelName,
      this.name,
      this.gender,
      this.profileImage});

  Passenger.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    mobileNumber = json['mobile_number'];
    modelName = json['model_name'];
    name = json['name'];
    gender = json['gender'];
    profileImage = json['profile_image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['mobile_number'] = this.mobileNumber;
    data['model_name'] = this.modelName;
    data['name'] = this.name;
    data['gender'] = this.gender;
    data['profile_image'] = this.profileImage;
    return data;
  }
}

Future<Passenger> passengerDetails(String mobilenumber) async {
  print(Constants.token);
  var body = {};
  var header = {
    'Authorization': 'Bearer ' + Constants.token,
    'Accept': 'application/json'
  };

  final response = await http.get(
    Uri.parse(ApiURLs.phonenumberUrl),
    headers: header,
  );
  // final response2 = await http.post(Urls.checkSubscribe, headers: header);

  // print(response2.body);

  if (Utilities.handleStatus(response.statusCode)) {
    Map<String, dynamic> mapResponse = json.decode(response.body);
    if (!mapResponse["error"]) {
      final data = mapResponse["data"].cast<Map<String, dynamic>>();
      final categs = await data.map<Passenger>((json) {
        return Passenger.fromJson(json);
      }).toList();
      return categs;
    } else {
      print(response.body);
      return null;
    }
  } else {
    print(response.body);

    return null;
  }
}
