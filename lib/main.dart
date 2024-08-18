import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Insulin Dose Calculator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: InsulinDoseCalculator(),
    );
  }
}

class InsulinDoseCalculator extends StatefulWidget {
  @override
  _InsulinDoseCalculatorState createState() => _InsulinDoseCalculatorState();
}

class _InsulinDoseCalculatorState extends State<InsulinDoseCalculator> {
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _bloodGlucoseController = TextEditingController();
  final TextEditingController _targetGlucoseController = TextEditingController();
  final TextEditingController _isfController = TextEditingController();
  final TextEditingController _cirController = TextEditingController();
  final TextEditingController _iobController = TextEditingController();

  String _carbohydrates = "";
  String _productName = "";
  String _servingSize = "100"; // Default to 100g if not provided
  double _insulinDose = 0.0;
  String _calories = "";
  String _protein = "";
  String _fat = "";
  String _fiber = "";
  bool _isLoading = false; // For showing the loading indicator
  String _region = "world"; // Default region to worldwide

  // Dropdown options for region selection
  final List<String> _regions = ["world", "us"];

  // Saving/loading preferences
  Future<void> savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetGlucose', _targetGlucoseController.text);
    await prefs.setString('isf', _isfController.text);
    await prefs.setString('cir', _cirController.text);
    await prefs.setString('iob', _iobController.text);
  }

  Future<void> loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _targetGlucoseController.text = prefs.getString('targetGlucose') ?? "";
      _isfController.text = prefs.getString('isf') ?? "";
      _cirController.text = prefs.getString('cir') ?? "";
      _iobController.text = prefs.getString('iob') ?? "";
    });
  }

  @override
  void initState() {
    super.initState();
    loadPreferences();
  }

  Future<void> fetchCarbohydrateInfo(String searchTerm) async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
        'https://$_region.openfoodfacts.org/cgi/search.pl?search_terms=$searchTerm&search_simple=1&action=process&json=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['products'].isNotEmpty) {
        final product = data['products'][0];
        setState(() {
          _productName = product['product_name'] ?? 'Unknown';
          _carbohydrates = product['nutriments']['carbohydrates_serving']?.toString() ?? 'N/A';
          _calories = product['nutriments']['energy-kcal_serving']?.toString() ?? 'N/A';
          _protein = product['nutriments']['proteins_serving']?.toString() ?? 'N/A';
          _fat = product['nutriments']['fat_serving']?.toString() ?? 'N/A';
          _fiber = product['nutriments']['fiber_serving']?.toString() ?? 'N/A';
          _servingSize = product['serving_size'] ?? "100g"; // Default to 100g if not provided
        });
      } else {
        setState(() {
          _productName = "No product found";
          _carbohydrates = "N/A";
          _calories = "N/A";
          _protein = "N/A";
          _fat = "N/A";
          _fiber = "N/A";
          _servingSize = "N/A";
        });
      }
    } else {
      setState(() {
        _productName = "Error";
        _carbohydrates = "N/A";
        _calories = "N/A";
        _protein = "N/A";
        _fat = "N/A";
        _fiber = "N/A";
        _servingSize = "N/A";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> scanBarcode() async {
    String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666", "Cancel", true, ScanMode.BARCODE);

    if (barcodeScanRes != '-1') {
      fetchCarbohydrateInfo(barcodeScanRes);
    }
  }

  void calculateInsulinDose() {
    double bloodGlucose = double.parse(_bloodGlucoseController.text);
    double targetGlucose = double.parse(_targetGlucoseController.text);
    double isf = double.parse(_isfController.text);
    double cir = double.parse(_cirController.text);
    double iob = double.parse(_iobController.text);
    double carbohydrates = double.parse(_carbohydrates);

    double correctionDose = (bloodGlucose - targetGlucose) / isf;
    double carbDose = carbohydrates / cir;
    double totalDose = correctionDose + carbDose - iob;

    setState(() {
      _insulinDose = totalDose > 0 ? totalDose : 0.0; // Prevent negative dose
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Insulin Dose Calculator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Carb Counting Life',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _foodController,
                      decoration: InputDecoration(labelText: 'Enter food name or scan barcode'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner),
                    onPressed: scanBarcode,
                    tooltip: 'Scan Barcode',
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text('Select Region:'),
                  SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _region,
                    onChanged: (String? newValue) {
                      setState(() {
                        _region = newValue!;
                      });
                    },
                    items: _regions.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value == "us" ? "United States" : "Worldwide",
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  fetchCarbohydrateInfo(_foodController.text);
                },
                child: Text('Fetch Nutrition Facts'),
              ),
              SizedBox(height: 20),
              if (_isLoading)
                CircularProgressIndicator()
              else if (_productName.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product: $_productName',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text('Serving Size: $_servingSize'),
                    Text('Carbohydrates per Serving: $_carbohydrates g'),
                    Text('Calories per Serving: $_calories kcal'),
                    Text('Protein per Serving: $_protein g'),
                    Text('Fat per Serving: $_fat g'),
                    Text('Fiber per Serving: $_fiber g'),
                  ],
                ),
              SizedBox(height: 20),
              TextField(
                controller: _bloodGlucoseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Current Blood Glucose (mg/dL)'),
              ),
              TextField(
                controller: _targetGlucoseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Target Blood Glucose (mg/dL)'),
              ),
              TextField(
                controller: _isfController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Insulin Sensitivity Factor (mg/dL/unit)'),
              ),
              TextField(
                controller: _cirController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Carbohydrate-to-Insulin Ratio (g/unit)'),
              ),
              TextField(
                controller: _iobController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Insulin on Board (units)'),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: calculateInsulinDose,
                      child: Text('Calculate Insulin Dose'),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: savePreferences,
                    child: Text('Save'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: loadPreferences,
                    child: Text('Load'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Recommended Insulin Dose: ${_insulinDose.toStringAsFixed(2)} units',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

               

