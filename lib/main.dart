import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sbcb_driver_flutter/core/services/auth_service.dart';
import 'package:sbcb_driver_flutter/core/services/firebase_services.dart';
import 'package:sbcb_driver_flutter/utils/constants.dart';

import 'core/notifiers/app_providers.dart';
import 'core/services/global_config.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService().setupInteractedMessage();

  runApp(SBCBDriverApp());
  RemoteMessage initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {}
  // App received a notification when it was killed
}

class SBCBDriverApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: getproviders(),
      child: MaterialApp(
        navigatorKey: navigatorKey, // Setting a global key for navigator

        title: Constants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Colors.indigo[900],
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: AuthService(),
      ),
    );
  }
}
