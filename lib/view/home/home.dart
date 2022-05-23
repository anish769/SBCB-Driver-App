import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sbcb_driver_flutter/core/model/vehicle_request.dart';
import 'package:sbcb_driver_flutter/core/notifiers/providers/auth_state.dart';
import 'package:sbcb_driver_flutter/core/notifiers/providers/location_state.dart';
import 'package:sbcb_driver_flutter/core/notifiers/providers/map_state.dart';
import 'package:sbcb_driver_flutter/utils/api_urls.dart';
import 'package:sbcb_driver_flutter/utils/constants.dart';
import 'package:sbcb_driver_flutter/utils/preferences.dart';
import 'package:lite_rolling_switch/lite_rolling_switch.dart';
import 'package:sbcb_driver_flutter/utils/utilities.dart';
import 'package:sbcb_driver_flutter/view/ad/search_page.dart';
import 'package:sbcb_driver_flutter/view/settings/settings.dart';
import 'package:sbcb_driver_flutter/view/status_page.dart';
import 'package:sbcb_driver_flutter/view/widgets/common_widgets.dart';
import 'package:sbcb_driver_flutter/view/about/about.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sbcb_driver_flutter/core/services/global_config.dart'
    as globals;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/model/taxi.dart';

class HomePage extends StatefulWidget {
  final LocationState locationState;

  HomePage({this.locationState});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Position selfPosition;

  // bool status = false;
  String _passengerNum = '';
  bool isDisplayed = false; // if dialog is displayed or not
  int _earningToday = 0;
  String userReqLat = '', userReqLong = '';
  bool isEnabled = false;

  @override
  void initState() {
    super.initState();
    Preference.getTodaysEarning().then((e) {
      setState(() {
        _earningToday = e;
      });
    });
    getSelfLocation();
    // create user icon for map
    BitmapDescriptor.fromAssetImage(
      ImageConfiguration(
        devicePixelRatio: 2.5,
        size: Size(1000, 1000),
      ),
      "assets/user.png",
    ).then((onValue) {
      Constants.userIcon = onValue;
    });
  }

  List<MapTypeItem> mapTypeList = <MapTypeItem>[
    MapTypeItem(
      name: "Normal",
      icon: Icon(
        Icons.map,
        color: Colors.amber,
      ),
    ),
    MapTypeItem(
      name: "Hybrid",
      icon: Icon(
        Icons.scanner_outlined,
        color: Colors.amber,
      ),
    ),
    MapTypeItem(
      name: "Terrain",
      icon: Icon(
        Icons.monochrome_photos,
        color: Colors.amber,
      ),
    ),
    MapTypeItem(
      name: "Satellite",
      icon: Icon(
        Icons.satellite,
        color: Colors.amber,
      ),
    ),
  ];

  bool checkRequestStatus(bool isRejected, bool isCancelled) {
    Utilities.showInToast("State before accept" + isRejected.toString(),
        toastType: ToastType.ERROR);
    print('Checking request status');
    if (isRejected && isCancelled) {
      return false;
    } else {
      return true;
    }
  }

  acceptRejectRequest(String requestId, String clientId, String action,
      MapState mapState, String uniquedId) async {
    print('inside acceptreject function');
    print(
        'accept reject request body is request_id=$requestId \n client_id=$clientId \n action=$action \n unique_id=$uniquedId');
    await acceptRejectRequestModel(requestId, clientId, action, uniquedId)
        .then((value) {
      print('respose from $action api  $value');

      // userReqLat = value.latitude;
      // userReqLong = value.longitude;
      // Utilities.showInToast("accepted from $clientId",
      //     toastType: ToastType.ERROR);
      // var listOfTaxis = await getTaxisAPI(
      //     double.parse(userReqLat), double.parse(userReqLong));
      // rejectRemainingDrivers(requestId, clientId, listOfTaxis);

// Uncomment later
      widget.locationState.setVehicleRequest(value);
      setState(() {
        isDisplayed = false;

        if (value.isAccepted) {
          globals.isReadyForTrip = false;
          mapState.setActiveTrip(true);
          // add marker for user(client) location
          mapState.createMarker(
              LatLng(
                double.parse(widget.locationState.vehicleRequest.latitude),
                double.parse(widget.locationState.vehicleRequest.longitude),
              ),
              true);

          // add marker for destination location
          mapState.createMarker(
              LatLng(
                double.parse(widget.locationState.vehicleRequest.destLatitude),
                double.parse(widget.locationState.vehicleRequest.destLongitude),
              ),
              false);

          // send request to add route
          mapState.sendRequest(
            LatLng(
              double.parse(widget.locationState.vehicleRequest.latitude),
              double.parse(widget.locationState.vehicleRequest.longitude),
            ),
            LatLng(
              double.parse(widget.locationState.vehicleRequest.destLatitude),
              double.parse(widget.locationState.vehicleRequest.destLongitude),
            ),
          );
        }
      });
    });
  }

  void rejectRemainingDrivers(
      String requestId, String clientId, List<Taxi> listOfTaxi) {
    String totalClientId = ' ';
    for (Taxi taxi in listOfTaxi) {
      if (taxi.clientId.toString() != clientId) {
        totalClientId = totalClientId + "\n" + taxi.clientId.toString();
        // acceptRejectRequestModel(
        //     requestId, taxi.clientId.toString(), 'rejected');
      }
    }
    // Utilities.showInToast("Rejected from $totalClientId",
    //   toastType: ToastType.ERROR);
  }

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
    final response = await http.post(Uri.parse(ApiURLs.taxiList),
        headers: header, body: body);
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

  checkNewVehicleRequest(BuildContext context, MapState mapProvider) {
    // var mapProvider = Provider.of<MapState>(context, listen: false);
    print("👩🏼‍🦰 Inside show dialog of vehicle request");
    // requested dialog
    if (widget.locationState.isRequested &&
        !isDisplayed &&
        globals.isReadyForTrip) {
      setState(() {
        isDisplayed = true;
      });
      showDialog(
          context: context,
          builder: (context) {
            return WillPopScope(
              onWillPop: () {
                return;
              },
              child: AlertDialog(
                title: Text("Taxi Requested"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Start: " +
                        widget.locationState.vehicleRequest.start.toString()),
                    Text("Destination: " +
                        widget.locationState.vehicleRequest.end.toString()),
                    Text("Remarks : " +
                        widget.locationState.vehicleRequest.remarks.toString()),
                    Text("Distance : " +
                        widget.locationState.vehicleRequest.distance
                            .toString() +
                        ' km'),
                    Text("Amount : Rs " +
                        widget.locationState.vehicleRequest.amount.toString()),
                  ],
                ),
                actions: [
                  FlatButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      print('accepted button clicked');
                      Position _pos = await GeolocatorPlatform.instance
                          .getCurrentPosition(
                              desiredAccuracy:
                                  LocationAccuracy.bestForNavigation);
                      await getVehicleRequestApi(globals.clientId.toString(),
                              _pos.latitude, _pos.longitude)
                          .then((value) {
                        print('Check function inside or not ');

                        if (value.isNotEmpty) {
                          print('Check function inside or not1 ');
                          if (widget.locationState.vehicleRequest.isRejected) {
                            print('Request rejected by another person ');
                            Utilities.showInToast(
                                "Requested Already accepted by other  user",
                                toastType: ToastType.ERROR);
                          } else if (widget
                              .locationState.vehicleRequest.isCanceled) {
                            print('Rejected b yother uadhfh');
                            Utilities.showInToast(
                                "Request already accepted by other user",
                                toastType: ToastType.ERROR);
                          } else {
                            acceptRejectRequest(
                              widget.locationState.vehicleRequest.requestId
                                  .toString(),
                              widget.locationState.vehicleRequest.clientId
                                  .toString(),
                              "accepted",
                              mapProvider,
                              widget.locationState.vehicleRequest.createdAt
                                      .toString() +
                                  '.' +
                                  widget.locationState.vehicleRequest.appUserId
                                      .toString(),
                            );
                            print('Request rejected by another personm last ');
                          }
                        }
                      });
                    },
                    child: Text("Accept"),
                  ),
                  FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      acceptRejectRequest(
                        widget.locationState.vehicleRequest.requestId
                            .toString(),
                        widget.locationState.vehicleRequest.clientId.toString(),
                        "rejected",
                        mapProvider,
                        widget.locationState.vehicleRequest.createdAt
                                .toString() +
                            widget.locationState.vehicleRequest.appUserId
                                .toString(),
                      );
                    },
                    child: Text("Reject"),
                  ),
                ],
              ),
            );
          });
    }
  }

  getSelfLocation() async {
    var isLocationTurnedOn =
        await GeolocatorPlatform.instance.isLocationServiceEnabled();

    if (!isLocationTurnedOn) {
      Utilities.showPlatformSpecificAlert(
          title: "Waring",
          body:
              "Your location services are disabled. \nPlease turn on your location services.");
    }
  }

  @override
  Widget build(BuildContext context) {
    var authState = Provider.of<AuthState>(context, listen: false);
    var mapStateProvider = Provider.of<MapState>(context, listen: false);

    var size = MediaQuery.of(context).size;

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => checkNewVehicleRequest(context, mapStateProvider));

    void choiceAction(String choice) {
      if (choice == 'Settings') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SettingsPage(),
          ),
        );
      } else if (choice == 'About') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AboutPage()),
        );
      } else if (choice == 'Logout') {
        print('SignOut');
        authState.signOut();
      }
    }

    Image buildVehicleIcon() {
      if (authState.driver.vehicleType == VehicleType.bike) {
        return globals.isReadyForTrip
            ? Image.asset("assets/bike/bike.png")
            : Image.asset("assets/bike/bike_closed.png");
      } else {
        return globals.isReadyForTrip
            ? Image.asset("assets/taxi/opened_taxi.png")
            : Image.asset("assets/taxi/closed_taxi.png");
      }
    }

    // widget to change the map type by toggle button
    Widget mapTypesToggleButton(MapState mapState) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: PopupMenuButton<MapTypeItem>(
                icon: Icon(
                  Icons.map,
                  color: Colors.amber,
                ),
                onSelected: (MapTypeItem value) {
                  if (value.name == "Normal") {
                    mapState.changeMapType(MapType.normal);
                  } else if (value.name == "Hybrid") {
                    mapState.changeMapType(MapType.hybrid);
                  } else if (value.name == "Terrain") {
                    mapState.changeMapType(MapType.terrain);
                  } else if (value.name == "Satellite") {
                    mapState.changeMapType(MapType.satellite);
                  }
                },
                itemBuilder: (BuildContext context) {
                  return mapTypeList.map((MapTypeItem mapTypeItem) {
                    return PopupMenuItem<MapTypeItem>(
                      value: mapTypeItem,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          mapTypeItem.icon,
                          Text(
                            mapTypeItem.name,
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }),
          ),
        ),
      );
    }

    Widget viewLoader(MapState mapState, Size size) {
      if (widget.locationState.userPosition != null) {
        return Stack(
          children: [
            GoogleMap(
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapType: mapState.mapType,
              polylines: mapState.polyLines,
              markers: Set<Marker>.of(mapState.markers.values),
              initialCameraPosition: CameraPosition(
                zoom: 16,
                target: LatLng(widget.locationState.userPosition.latitude,
                    widget.locationState.userPosition.longitude),
              ),
              onMapCreated: mapState.onCreated,
            ),
            mapState.activeTrip
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      child: Padding(
                        padding: const EdgeInsets.all(30.0),
                        child: Container(
                          color: Color.fromARGB(255, 243, 239, 239),
                          height: 190,
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: FloatingActionButton(
                                  child: Icon(
                                    Icons.call,
                                  ), //child widget inside this button
                                  onPressed: () {
                                    print("Button is pressed.");
                                    launch(
                                        "tel:${_passengerNum.isEmpty ? Constants.passengerNumber : _passengerNum}");
                                  },
                                  backgroundColor: Color.fromARGB(
                                    255,
                                    97,
                                    12,
                                    90,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text("Distance : " +
                                    widget.locationState.vehicleRequest.distance
                                        .toString() +
                                    ' km'),
                              ),
                              Text("Amount : Rs " +
                                  widget.locationState.vehicleRequest.amount
                                      .toString()),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: MaterialButton(
                                  onPressed: () async {
                                    setState(() {
                                      _earningToday = _earningToday +
                                          widget.locationState.vehicleRequest
                                              .amount;
                                      globals.isReadyForTrip = true;
                                    });
                                    Preference.saveTodaysEarning(_earningToday);

                                    mapState.endTrip();
                                    mapState.setActiveTrip(false);
                                  },
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: 150,
                                        child: Center(
                                          child: Text("END TRIP",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  color: Color.fromARGB(
                                    255,
                                    97,
                                    12,
                                    90,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Card(
                      color: Colors.grey[50],
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                      child: Container(
                        height: size.height * 0.2,
                        width: size.width,
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 5.0),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Icon(
                                Icons.circle,
                                color: widget.locationState.trackCarState
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            Align(
                              alignment: Alignment.topLeft,
                              child: Text("Rs. $_earningToday"),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: InkWell(
                                child: buildVehicleIcon(),
                                onTap: () {
                                  setState(() {
                                    globals.isReadyForTrip =
                                        !globals.isReadyForTrip;
                                  });
                                  if (globals.isReadyForTrip && isEnabled) {
                                    notificationSub();
                                  } else {
                                    notificationUnsub();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            mapTypesToggleButton(mapState),
          ],
        );
      } else {
        return Center(
          child: Container(
            child: CircularProgressIndicator(),
          ),
        );
      }
    }

    return Consumer<MapState>(builder: (context, mapState, child) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
              leading: getVehicleIcon(authState.driver.vehicleType),
              title: Text(Constants.appName),
              backgroundColor: Color.fromARGB(
                255,
                97,
                12,
                90,
              ),
              actions: <Widget>[
                MaterialButton(
                  textColor: Colors.white,
                  child: Text('Status'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Consumer<LocationState>(
                            builder: (context, locationState, child) {
                          return StatusPage(
                            locationState: widget.locationState,
                          );
                        }),
                      ),
                    );
                  },
                ),
                IconButton(
                  // textColor: Colors.white,
                  icon: Icon(Icons.search),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SearchPage(),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: LiteRollingSwitch(
                    value: isEnabled,
                    textOn: 'On',
                    textOff: 'Off',
                    colorOn: Color.fromARGB(255, 14, 92, 27),
                    colorOff: Color.fromARGB(255, 202, 10, 10),
                    iconOn: Icons.notifications_active_rounded,
                    iconOff: Icons.notifications_off_sharp,
                    animationDuration: Duration(seconds: 1),
                    onChanged: (value) {
                      setState(() {
                        isEnabled = value;
                      });
                      if (globals.isReadyForTrip && value) {
                        notificationSub();
                      } else {
                        notificationUnsub();
                      }
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: choiceAction,
                  itemBuilder: (BuildContext context) {
                    return ['Settings', 'About', 'Logout'].map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(choice),
                      );
                    }).toList();
                  },
                )
              ]),
          body: viewLoader(mapState, size),
        ),
      );
    });
  }

  void notificationSub() async {
    try {
      await FirebaseMessaging.instance
          .subscribeToTopic('AlertTaxi2')
          .then((value) => print("Subscribed"));
    } catch (e) {
      print('error is $e');
    }
  }

  void notificationUnsub() async {
    try {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('AlertTaxi2')
          .then((value) => print("Unsuscribed"));
    } catch (e) {
      print('error is $e');
    }
  }
}

class MapTypeItem {
  String name;
  Icon icon;

  MapTypeItem({
    this.name,
    this.icon,
  });
}
