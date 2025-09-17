import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/home_page.dart';
import 'package:logger/logger.dart';

void main() async {
  final Logger logger = Logger();
  WidgetsFlutterBinding.ensureInitialized();

  // hide status and navigation bars
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // make bars transparent and set icon brightness
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // load api
  try {
    await dotenv.load(fileName: ".env");
    logger.i('Environment variables loaded successfully');
  } catch (e) {
    logger.e('Error loading .env file: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'All Laboratory Activities: Frank',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}
