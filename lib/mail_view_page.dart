import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MailViewPage extends StatefulWidget {
  final int uid;
  final String subject;
  final String from;
  final String date;

  const MailViewPage({
    Key? key,
    required this.uid,
    required this.subject,
    required this.from,
    required this.date,
  }) : super(key: key);

  @override
  State<MailViewPage> createState() => _MailViewPageState();
}

class _MailViewPageState extends State<MailViewPage> {
  final _storage = const FlutterSecureStorage();
  String _body = '';
  bool _loading = true;
  String _status = 'Fetching email...';
  String _extractPlainText(String fullMessage) {
    final lines = fullMessage.split('\n');
    final buffer = StringBuffer();
    bool inTextPart = false;

    for (var line in lines) {
      line = line.trimRight();

      if (line.toLowerCase().contains('content-type: text/plain')) {
        inTextPart = true;
        continue;
      }

      if (inTextPart && line.startsWith('--')) {
        break;
      }

      if (inTextPart) {
        buffer.writeln(line);
      }
    }

    final result = buffer.toString().trim();
    return result.isEmpty ? '(No plain text content)' : result;
  }

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');

    if (username == null || password == null) {
      setState(() {
        _loading = false;
        _status = 'Missing login credentials.';
      });
      return;
    }

    try {
      final socket = await SecureSocket.connect('qasid.iitk.ac.in', 993);
      final reader = StreamQueue(
        socket.cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

      await reader.next; // server greeting

      socket.write('A001 LOGIN "$username" "$password"\r\n');
      await socket.flush();
      while (true) {
        final line = await reader.next;
        if (line.startsWith('A001')) break;
      }

      socket.write('A002 SELECT INBOX\r\n');
      await socket.flush();
      while (true) {
        final line = await reader.next;
        if (line.startsWith('A002')) break;
      }

      socket.write('A003 UID FETCH ${widget.uid} (BODY[])\r\n');
      await socket.flush();

      StringBuffer emailBuffer = StringBuffer();
      bool inBody = false;

      while (await reader.hasNext) {
        final line = await reader.next;
        if (line.startsWith('A003')) break;
        if (line.contains('FETCH') && line.contains('BODY[]')) {
          inBody = true;
          continue;
        }
        if (inBody && line.trim() == ')') break;
        if (inBody) emailBuffer.writeln(line);
      }

      await socket.close();

      final fullEmail = emailBuffer.toString();
      final body = _extractPlainText(fullEmail);

      setState(() {
        _body = body;
        _loading = false;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    widget.subject,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('From: ${widget.from}'),
                  Text('Date: ${widget.date}'),
                  const Divider(height: 32),
                  SelectableText(
                    _body,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
