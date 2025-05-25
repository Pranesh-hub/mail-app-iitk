import 'dart:convert';
import 'dart:io';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mail_view_page.dart';
import 'compose_page.dart'; // Import the compose page file

class InboxPage extends StatefulWidget {
  const InboxPage({Key? key}) : super(key: key);

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final _storage = const FlutterSecureStorage();
  late SecureSocket _socket;
  late StreamQueue<String> _queue;
  List<Map<String, dynamic>> _emails = [];
  int? _lastFetchedUid;
  bool _hasMore = true;
  bool _loading = false;
  String _status = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInbox();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100 &&
          !_loading &&
          _hasMore) {
        _loadInbox(append: true);
      }
    });
  }

  Future<void> _loadInbox({bool append = false}) async {
    setState(() {
      _loading = true;
      _status = append ? 'Loading more emails...' : 'Loading latest 10 emails...';
    });

    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');

    if (username == null || password == null) {
      setState(() {
        _loading = false;
        _status = 'Error: Missing credentials.';
      });
      return;
    }

    try {
      _socket = await SecureSocket.connect('qasid.iitk.ac.in', 993);
      _queue = StreamQueue(
        _socket.cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );

      await _queue.next; // Read greeting

      // LOGIN
      _socket.write('A001 LOGIN "$username" "$password"\r\n');
      await _socket.flush();
      while (true) {
        final line = await _queue.next;
        if (line.startsWith('A001')) {
          if (!line.contains('OK')) throw Exception('Login failed');
          break;
        }
      }

      // SELECT INBOX
      _socket.write('A002 SELECT INBOX\r\n');
      await _socket.flush();
      while (true) {
        final line = await _queue.next;
        if (line.startsWith('A002')) {
          if (!line.contains('OK')) throw Exception('Failed to select INBOX');
          break;
        }
      }

      // UID SEARCH ALL
      List<int> allUids = [];
      _socket.write('A003 UID SEARCH ALL\r\n');
      await _socket.flush();
      while (true) {
        final line = await _queue.next;
        if (line.startsWith('* SEARCH')) {
          allUids = line
              .substring(8)
              .trim()
              .split(' ')
              .where((s) => s.isNotEmpty)
              .map(int.parse)
              .toList();
        }
        if (line.startsWith('A003')) break;
      }

      allUids.sort((a, b) => b.compareTo(a)); // Newest to oldest
      if (_lastFetchedUid != null) {
        allUids = allUids.where((uid) => uid < _lastFetchedUid!).toList();
      }

      if (allUids.isEmpty) {
        setState(() {
          _hasMore = false;
          _loading = false;
        });
        return;
      }

      final nextBatch = allUids.take(10).toList();
      if (nextBatch.isNotEmpty) {
        _lastFetchedUid = nextBatch.last;
      }

      final fetchCommand =
          'A004 UID FETCH ${nextBatch.join(",")} (UID INTERNALDATE BODY[HEADER.FIELDS (SUBJECT FROM DATE)])\r\n';
      _socket.write(fetchCommand);
      await _socket.flush();

      final List<Map<String, dynamic>> emails = [];
      Map<String, dynamic> current = {};
      String? currentUid;
      DateTime? currentInternalDate;

      while (true) {
        final line = await _queue.next;
        if (line.startsWith('A004')) break;

        if (line.startsWith('*') && line.contains('FETCH')) {
          if (current.isNotEmpty) {
            current['uid'] = currentUid;
            current['internalDate'] = currentInternalDate;
            emails.add(current);
          }
          current = {};
          currentUid = null;
          currentInternalDate = null;

          final uidMatch = RegExp(r'UID (\d+)').firstMatch(line);
          if (uidMatch != null) currentUid = uidMatch.group(1);

          final internalDateMatch = RegExp(r'INTERNALDATE "([^"]+)"').firstMatch(line);
          if (internalDateMatch != null) {
            final dateStr = internalDateMatch.group(1);
            if (dateStr != null) {
              currentInternalDate = _parseImapDate(dateStr);
            }
          }
        } else if (line.toLowerCase().startsWith('subject:')) {
          current['subject'] = line.substring(8).trim();
        } else if (line.toLowerCase().startsWith('from:')) {
          current['from'] = line.substring(5).trim();
        } else if (line.toLowerCase().startsWith('date:')) {
          current['date'] = line.substring(5).trim();
        }
      }

      if (current.isNotEmpty) {
        current['uid'] = currentUid;
        current['internalDate'] = currentInternalDate;
        emails.add(current);
      }

      emails.sort((a, b) {
        final da = a['internalDate'] as DateTime? ?? DateTime(1900);
        final db = b['internalDate'] as DateTime? ?? DateTime(1900);
        return db.compareTo(da);
      });

      setState(() {
        if (append) {
          _emails.addAll(emails);
        } else {
          _emails = emails;
        }
        _loading = false;
        _status = 'Showing ${_emails.length} emails.';
      });

      await _socket.close();
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
    }
  }

  DateTime? _parseImapDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length < 3) return null;
      final dmy = parts[0].split('-');
      final monthMap = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final day = int.parse(dmy[0]);
      final month = monthMap[dmy[1]] ?? 1;
      final year = int.parse(dmy[2]);

      final time = parts[1].split(':');
      final hour = int.parse(time[0]);
      final min = int.parse(time[1]);
      final sec = int.parse(time[2]);
      return DateTime.utc(year, month, day, hour, min, sec);
    } catch (_) {
      return null;
    }
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'password');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final username = await _storage.read(key: 'username');
          final password = await _storage.read(key: 'password');

          if (username == null || password == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please login again to compose mail')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComposePage(
                username: username,
                password: password,
              ),
            ),
          );
        },
        tooltip: 'Compose Mail',
        child: const Icon(Icons.create),
      ),

      body: _loading && _emails.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _lastFetchedUid = null;
                _hasMore = true;
                await _loadInbox();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _emails.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_status, style: const TextStyle(fontSize: 16)),
                    );
                  }
                  final email = _emails[index - 1];
                  return ListTile(
                    title: Text(email['subject'] ?? '(No Subject)'),
                    subtitle: Text('${email['from'] ?? ''}\n${email['date'] ?? ''}'),
                    isThreeLine: true,
                    leading: const Icon(Icons.mail_outline),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MailViewPage(
                            uid: int.parse(email['uid']),
                            subject: email['subject'] ?? '(No Subject)',
                            from: email['from'] ?? '',
                            date: email['date'] ?? '',
                          ),
                        ),
                      );
                    },
                  );

                },
              ),
            ),
    );
  }
}
