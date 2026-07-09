import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class ServerService {
  HttpServer? _server;
  Future<void> startServer(double Function() getSpeedCallback) async {
    final router = Router();
    router.get('/speed', (Request request) {
      final speed = getSpeedCallback(); 
      
      final responseBody = jsonEncode({
        'speed': double.parse(speed.toStringAsFixed(2)),
        'status': 'active'
      });

      return Response.ok(
        responseBody,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*', 
        },
      );
    });

    _server = await shelf_io.serve(router, InternetAddress.loopbackIPv4, 8080);
    print('Server Trainercraft jalan di: ${_server!.address.address}:${_server!.port}');
  }
  
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      print('Server Trainercraft dimatikan.');
    }
  }
}