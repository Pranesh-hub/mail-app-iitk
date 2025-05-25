# IITK Mail App

## Overview

This is a Flutter-based email client for IIT Kanpur email accounts. It supports:

- Secure IMAP login and inbox viewing  
- Composing and sending emails via SMTP with SSL  
- Lazy loading of emails  
- Simple UI for composing and sending emails

---

## APK Submission

The APK file for this app is uploaded at:

**[OneDrive Link to APK](https://your-onedrive-link-here)**

---

## How to Run the Code

### Prerequisites

- Flutter SDK (>=3.0.0 recommended)  
- Dart SDK  
- Internet connection for mail server communication  
- An IITK email account and password

### Setup

1. Clone or download this repository.
2. Ensure Flutter is installed and added to your system PATH.
3. Open a terminal in the project directory.
4. Run `flutter pub get` to install dependencies.
5. Connect a device or start an emulator.
6. Run the app using:

   ```bash
   flutter run

## Dependencies Used

```yaml
dependencies:
  flutter:
    sdk: flutter
  mailer: ^5.0.0
  flutter_secure_storage: ^9.0.0
  async: ^2.11.0
  mime: ^1.0.6
  cupertino_icons: ^1.0.8
  ```

## Key Files and Their Purpose

- `lib/compose_page.dart`: Email composition screen and SMTP sending logic using `mailer` or raw sockets.
- `lib/inbox_page.dart`: (If implemented) IMAP login and inbox fetching logic.
- `lib/main.dart`: App entry point and navigation.
- `pubspec.yaml`: Flutter configuration and dependencies.

---

## Usage Instructions

- Launch the app on your device/emulator.
- Login using your IITK email credentials.
- Use the **"Compose"** screen to draft and send an email.
- Plain text emails only. Attachments are not supported yet.

---

## Notes

- Provide only your IITK username (e.g., `pranesh24`) in the login field.
- The app uses `mmtp.iitk.ac.in:465` for secure SMTP email sending.
- Ensure network permissions are granted for email communication.
