import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // For barcode scanning
import 'package:http/http.dart' as http; // For API requests
import 'dart:convert'; // For JSON parsing
import 'dart:async'; // For debounce mechanism

void main() => runApp(ScanNutriScoreApp());

class ScanNutriScoreApp extends StatelessWidget {
  const ScanNutriScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scan Nutri Score',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          color: Colors.orange,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.orange.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.orange),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: BarcodeScannerScreen(),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  BarcodeScannerScreenState createState() => BarcodeScannerScreenState();
}

class BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String? scannedBarcode;
  Map<String, dynamic>? productData;
  bool isLoading = false;
  final TextEditingController eanController = TextEditingController();
  bool isScanningAllowed = true;

  final Stopwatch barcodeTimer = Stopwatch();
  final Stopwatch apiTimer = Stopwatch();

  Future<void> fetchProductDetails(String barcode) async {
    setState(() {
      isLoading = true;
      productData = null;
    });

    apiTimer.start();

    final apiUrl =
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json?lc=de';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          productData = data['product'] ?? {};
        });
      } else {
        setState(() {
          productData = {'error': 'Produkt nicht gefunden'};
        });
      }
    } catch (e) {
      setState(() {
        productData = {'error': 'Fehler beim Abrufen der Daten'};
      });
    } finally {
      apiTimer.stop();
      setState(() {
        isLoading = false;
      });
    }
  }

  void resetApp() {
    setState(() {
      scannedBarcode = null;
      productData = null;
      eanController.clear();
      isScanningAllowed = true;
      barcodeTimer.reset();
      apiTimer.reset();
    });
  }

  void handleBarcodeDetection(String barcode) {
    if (isScanningAllowed) {
      barcodeTimer.stop();
      final barcodeTime = barcodeTimer.elapsedMilliseconds;

      setState(() {
        isScanningAllowed = false;
        scannedBarcode = barcode;
      });

      fetchProductDetails(barcode).then((_) {
        final apiTime = apiTimer.elapsedMilliseconds;
        setState(() {
          productData ??= {};
          productData!["barcode_detection_time"] = "$barcodeTime ms";
          productData!["api_fetch_time"] = "$apiTime ms";
        });
        apiTimer.reset();
      });

      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          isScanningAllowed = true;
        });
        barcodeTimer.start();
      });
    }
  }

  String getNutriScoreImage(String? grade) {
    if (grade == null) return 'assets/images/nutriscore_unknown.png';
    switch (grade) {
      case 'a':
        return 'assets/images/nutriscore_a.png';
      case 'b':
        return 'assets/images/nutriscore_b.png';
      case 'c':
        return 'assets/images/nutriscore_c.png';
      case 'd':
        return 'assets/images/nutriscore_d.png';
      case 'e':
        return 'assets/images/nutriscore_e.png';
      default:
        return 'assets/images/nutriscore_unknown.png';
    }
  }

  @override
  void initState() {
    super.initState();
    barcodeTimer.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Nutri Score'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.2,
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (BarcodeCapture capture) {
                      final barcode = capture.barcodes.first;
                      if (barcode.rawValue != null) {
                        handleBarcodeDetection(barcode.rawValue!);
                      }
                    },
                  ),
                  Center(
                    child: Container(
                      height: 2,
                      color: Colors.red,
                      margin: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: eanController,
                decoration: InputDecoration(
                  labelText: 'EAN eingeben',
                  prefixIcon: Icon(Icons.qr_code, color: Colors.orange),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (eanController.text.isNotEmpty) {
                      fetchProductDetails(eanController.text);
                    }
                  },
                  child: Text('Suchen'),
                ),
                ElevatedButton(
                  onPressed: resetApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Zurücksetzen'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (isLoading) Center(child: CircularProgressIndicator()),
            if (productData != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: productData!.containsKey('error')
                      ? Center(child: Text(productData!['error']))
                      : ListView(
                          children: [
                            Text(
                              'Produkt: ${productData!['product_name'] ?? 'Unbekannt'}',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Zutaten: ${productData!['ingredients_text'] ?? 'Keine Daten verfügbar'}',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Barcode-Erkennungszeit: ${productData!['barcode_detection_time'] ?? 'Nicht gemessen'}',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              'API-Abrufzeit: ${productData!['api_fetch_time'] ?? 'Nicht gemessen'}',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 20),
                            if (productData!['nutriscore_grade'] != null)
                              Column(
                                children: [
                                  Text('Nutri-Score:',
                                      style: TextStyle(fontSize: 16)),
                                  SizedBox(height: 10),
                                  Image.asset(
                                    getNutriScoreImage(
                                        productData!['nutriscore_grade']),
                                    height: 50,
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
