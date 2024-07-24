import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String _inputValue = "";
  final TextEditingController _controller = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    // formats: [BarcodeFormat.code128],
    // //specifies Curtin ID barcode type only
    // autoStart: true,
  );
  StreamSubscription<Object?>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _subscription = _scannerController.barcodes.listen((barcodeCapture) {
      _handleBarcode(barcodeCapture);
    });

    unawaited(_scannerController.start());
  }

  void _handleBarcode(BarcodeCapture barcodeCapture) {
    final String code = barcodeCapture.barcodes.first.rawValue ?? 'Unknown';
    setState(() {
      _inputValue = code;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _subscription = _scannerController.barcodes.listen(_handleBarcode);
        unawaited(_scannerController.start());
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_scannerController.stop());
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _subscription?.cancel();
    _subscription = null;
    await _scannerController.dispose();
    super.dispose();
  }

   void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          controller: _scannerController,
          onScan: (barcode) {
            setState(() {
              _inputValue = barcode;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      // Handle permission denied scenario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Camera permission is required."),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _setInput() {
    setState(() {
      if (_controller.text.length == 8) {
        _inputValue = _controller.text;
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid student ID."),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Scanner Updated 24/07/24 17:02 You have entered:',
            ),
            Text(
              _inputValue,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Student Number',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8)
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _setInput,
        tooltip: 'Submit',
        child: const Icon(Icons.send),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class ScannerScreen extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(String) onScan;

  const ScannerScreen({super.key, required this.controller, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: controller,
        onDetect: (barcodeCapture) {
          final String code = barcodeCapture.barcodes.first.rawValue ?? 'Unknown';
          onScan(code);
        },
      ),
    );
  }
}
