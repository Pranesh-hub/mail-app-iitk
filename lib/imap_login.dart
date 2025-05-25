import 'dart:io';
import 'dart:convert';
import 'package:async/async.dart';

Future<bool> verifyImapLogin(String username, String password) async {
  try {
    print('Connecting to IMAP server...');
    final socket = await SecureSocket.connect(
      'qasid.iitk.ac.in',
      993,
      timeout: const Duration(seconds: 10),
    );

    final queue = StreamQueue(
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()),
    );

    final greeting = await queue.next;
    print('Server: $greeting');

    socket.write('A001 LOGIN "$username" "$password"\r\n');
    await socket.flush();

    while (true) {
      final line = await queue.next;
      print('Server: $line');
      if (line.trim().startsWith('A001')) {
        await socket.close();
        return line.contains('OK');
      }
    }
  } catch (e) {
    print('IMAP login error: $e');
    return false;
  }
}
