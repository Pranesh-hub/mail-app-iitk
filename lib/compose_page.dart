import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ComposePage extends StatefulWidget {
  final String username;
  final String password;

  const ComposePage({required this.username, required this.password, Key? key}) : super(key: key);

  @override
  _ComposePageState createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  bool _sending = false;
  String _status = '';

  Future<void> _sendMail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _status = '';
    });

    final smtpServer = SmtpServer(
      'mmtp.iitk.ac.in',
      port: 465,
      ssl: true,
      username: '${widget.username}@iitk.ac.in',
      password: widget.password,
    );

    final message = Message()
      ..from = Address('${widget.username}@iitk.ac.in')
      ..recipients.add(_toController.text.trim())
      ..subject = _subjectController.text.trim()
      ..text = _bodyController.text.trim();

    try {
      final sendReport = await send(message, smtpServer);

      setState(() {
        _status = 'Email sent successfully!';
        _sending = false;
      });
    } on MailerException catch (e) {
      setState(() {
        _status = 'Failed to send email: ${e.message}';
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to send email: $e';
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compose Email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(labelText: 'To'),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter recipient email' : null,
              ),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              Expanded(
                child: TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: 'Body'),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                ),
              ),
              const SizedBox(height: 10),
              _sending
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _sendMail,
                      child: const Text('Send'),
                    ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: TextStyle(color: _status.startsWith('Failed') ? Colors.red : Colors.green),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
