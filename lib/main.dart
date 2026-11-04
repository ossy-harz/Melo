import 'package:flutter/material.dart';
import 'package:tone_player/app/tone_services.dart';
import 'package:tone_player/app/tone_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ToneApp(servicesFuture: ToneServices.initialize()));
}
