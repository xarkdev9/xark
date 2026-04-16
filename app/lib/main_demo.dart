import 'package:flutter/material.dart';
import 'package:hello_app/theme.dart';
import 'package:hello_app/demo/triage_prototypes.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: HelloColors.voidBg,
        fontFamily: 'Inter',
      ),
      home: const TriageDemoPage(),
    ),
  );
}
