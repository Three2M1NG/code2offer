import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/analysis_page.dart';

class Code2OfferApp extends StatelessWidget {
  const Code2OfferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'code2offer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomePage());
          case '/problem':
            final problemId = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => AnalysisPage(problemId: problemId));
          default:
            return MaterialPageRoute(builder: (_) => const HomePage());
        }
      },
    );
  }
}
