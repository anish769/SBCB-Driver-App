import 'dart:convert';



import 'package:http/http.dart' as http;

import '../../utils/api_urls.dart';
import '../../utils/constants.dart';
import '../../utils/utilities.dart';
import 'vehicle.dart';

class Taxi extends Vehicle {
  int deviceId;
  String address;

  String devicetime;
  int altitude;
  int clientId;
  String phone;
  String driverImage;

  // Taxi(
  //     {this.uniqueid,
  //     this.deviceId,
  //     this.address,
  //     this.course,
  //     this.speed,
  //     this.attributes,
  //     this.devicetime,
  //     this.valid,
  //     this.serverTime,
  //     this.latitude,
  //     this.altitude,
  //     this.longitude,
  //     this.uniqueId,
  //     this.clientId,
  //     this.phone,
  //     this.distance});

  Taxi.fromJson(Map<String, dynamic> json) {
    uniqueId = json['uniqueid'];
    print(uniqueId);
    name = json['uniqueId']; // name is uniqueID
    driverImage = json['image'] != null
        ? (ApiURLs.driverPicUrl + json['image'])
        : json["image"];
    deviceId = json['device_id'];
    address = json['address'];
    course = json['course'].toDouble();
    speed = json['speed'].toDouble();
    attributes = json['attributes'];
    devicetime = json['devicetime'];
    valid = json['valid'];
    servertime = json['serverTime'];
    latitude = json['latitude'];
    altitude = json['altitude'].toInt();
    longitude = json['longitude'];
    uniqueId = json['uniqueId'];
    clientId = json['client_id'];
    phone = json['phone'];
    distance = json['distance'].toDouble();
    vehicleType = json['vehicle_type'];
  }

  get appUserId => null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['uniqueid'] = this.uniqueId;
    data['device_id'] = this.deviceId;
    data['image'] = this.driverImage;
    data['address'] = this.address;
    data['course'] = this.course;
    data['speed'] = this.speed;
    data['attributes'] = this.attributes;
    data['devicetime'] = this.devicetime;
    data['valid'] = this.valid;
    data['serverTime'] = this.servertime;
    data['latitude'] = this.latitude;
    data['altitude'] = this.altitude;
    data['longitude'] = this.longitude;
    data['uniqueId'] = this.uniqueId;
    data['client_id'] = this.clientId;
    data['phone'] = this.phone;
    data['distance'] = this.distance;
    return data;
  }



//static methods
Future<List<Taxi>> getTaxisAPI(double lat, double long) async {
  print(Constants.token);

  var body = {
    'latitude': lat.toString(),
    'longitude': long.toString(),
    'email': Constants.accessEmail
  };
  var header = {
    'Authorization': 'Bearer ' + Constants.token,
    'Accept': 'application/json'
  };
  // try {
  final response =
      await http.post(Uri.parse(ApiURLs.taxiList), headers: header, body: body);
  // final response2 = await http.post(Urls.checkSubscribe, headers: header);

  // print(response2.body);

  if (Utilities.handleStatus(response.statusCode)) {
    Map<String, dynamic> mapResponse = json.decode(response.body);
    if (!mapResponse["error"]) {
      final data = mapResponse["data"].cast<Map<String, dynamic>>();
      final taxis = await data.map<Taxi>((json) {
        return Taxi.fromJson(json);
      }).toList();
      return taxis;
    } else {
      print(response.body);
      return null;
    }
  } else {
    print(response.body);

    return null;
  }
}

}
