import 'dart:convert';
import 'dart:io';
// import 'package:shelf/shelf.dart';
// import 'package:shelf/shelf_io.dart' as shelf_io;
// import 'package:shelf_router/shelf_router.dart';

class ServerService {
  HttpServer? _server;
  WebSocket? _clientSocket;

  Future<void> startServer(double Function() getSpeed) async {
    try {
      // Bind ke InternetAddress.anyIPv4 (0.0.0.0) biar bisa diakses via IP Lokal
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8000);
      print("WebSocket Server running on port 8000");

      _server!.transform(WebSocketTransformer()).listen((WebSocket socket) {
        print("MCPE Connected via WebSocket!");
        _clientSocket = socket;

        // Kirim data speed tiap 200ms
        _startSpeedStream(getSpeed);
      });
    } catch (e) {
      print("Error starting server: $e");
    }
  }

  void _startSpeedStream(double Function() getSpeed) {
    Stream.periodic(const Duration(milliseconds: 200)).listen((_) {
      if (_clientSocket != null && _clientSocket!.readyState == WebSocket.open) {
        double currentSpeed = getSpeed();

        // Standard MCPE Bedrock JSON Command Protocol
        Map<String, dynamic> commandPayload = {
          "header": {
          "version": 1,
          "requestId": "00000000-0000-0000-0000-000000000000",
          "messagePurpose": "commandRequest"
        },
        "body": {
          "version": 1,
          "commandLine": "scriptevent trainercraft:set_speed ${currentSpeed.toStringAsFixed(1)}"
        }
};

        _clientSocket!.add(jsonEncode(commandPayload));
      }
    });
  }

  Future<void> stopServer() async {
    await _clientSocket?.close();
    await _server?.close();
    _clientSocket = null;
    _server = null;
  }
}