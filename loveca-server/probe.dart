import 'dart:io';
Future<void> main() async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((r) {
    print('uri.path = ${r.uri.path}');
    print('pathSegments = ${r.uri.pathSegments}');
    r.response.statusCode = 200;
    r.response.close();
  });
  final sock = await Socket.connect('localhost', s.port);
  sock.write('GET /dist/%2e%2e/version.json HTTP/1.1${String.fromCharCode(13)}${String.fromCharCode(10)}Host: x${String.fromCharCode(13)}${String.fromCharCode(10)}Connection: close${String.fromCharCode(13)}${String.fromCharCode(10)}${String.fromCharCode(13)}${String.fromCharCode(10)}');
  await sock.drain<void>();
  await sock.close();
  await s.close(force: true);
}
