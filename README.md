# ChatSys User Profile Feature

## Setup Instructions

### Prerequisites

- Flutter SDK (3.0.0+)
- Firebase Project
- Firebase CLI

### Installation Steps

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure Firebase:
   - Create a Firebase project
   - Add Android/iOS app to Firebase project
   - Download `google-services.json` and `firebase_options.dart`
   - Place configuration files in the appropriate directories

### Firebase Configuration

Ensure you have the following Firebase services enabled:

- Authentication
- Firestore
- Storage

### Running the App

#### Android

```bash
flutter run -d android
```

#### iOS

```bash
flutter run -d ios
```

#### Web

```bash
flutter run -d chrome
```

### Profile Page Features

- Upload and update profile picture
- Edit display name
- Persistent profile data across sessions

### Troubleshooting

- Ensure all Firebase configuration files are correctly set up
- Check internet connectivity
- Verify Firebase project settings

## Dependencies

- Firebase Core
- Firebase Auth
- Cloud Firestore
- Firebase Storage
- Image Picker
- Provider
- Firebase Analytics
- Cupertino Icons
- Google Sign-In
- Flutter Facebook Auth
- Font Awesome Flutter
- Flutter WebRTC
- Cached Network Image

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request
