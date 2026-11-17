Cloud-Based Quiz Application
A Flutter and Dart quiz application that uses Firebase Authentication
for user sign-in, Cloud Firestore for storing quiz attempts, and the
Open Trivia Database (OpenTDB) for quiz questions.
Table of Contents
- Overview
- Technology Stack
- Prerequisites
- Firebase Project Setup
- Create the Two Test Users
- Deploy Firestore Security Rules
- Development Flags and Test IDs
- Run the Application
- Build the Release APK
- Firestore Data Structure
- Final Commit
- Security Notes
Overview
The application provides a ten-question multiple-choice quiz. Users sign
in, answer questions, review their answers, and submit their quiz
attempt to Cloud Firestore.

The application is designed to handle invalid API responses, repeated
submission attempts, network interruptions, uncertain save
acknowledgements, and unauthorized access to another user's records.
Technology Stack
- Framework: Flutter
- Language: Dart
- Authentication: Firebase Authentication (Email/Password)
- Database: Cloud Firestore
- Question API: Open Trivia Database (OpenTDB)
- Platform tested: Android Emulator
- Build type: Android release APK
Prerequisites
Install the following tools before setting up the project:
- Flutter SDK
- Dart SDK (included with Flutter)
- Android Studio and an Android emulator, or a physical Android device
- Visual Studio Code or another Flutter-compatible IDE
- Node.js and npm, for the Firebase CLI
- A Google account with access to Firebase
Check the Flutter installation:
flutter doctor
Install and sign in to the Firebase CLI:
npm install -g firebase-tools
firebase login
Install the FlutterFire CLI:
dart pub global activate flutterfire_cli
Make sure the Dart pub-cache bin directory is available in your system
PATH.
Firebase Project Setup
1. Open the Firebase Console.
2. Create a Firebase project for this assignment. Use a project ID that
   matches the project you configured for the application.
3. In Build → Authentication → Sign-in method, enable
   Email/Password.
4. In Build → Firestore Database, create a Cloud Firestore
   database.
5. Select Production mode when creating the database. Deploy the
   project's security rules before testing cloud writes.
6. From the project directory, configure Firebase for the Flutter
   platforms used by the project:
   flutterfire configure
7. Select the Firebase project you created and the Android application
   when prompted.
8. Confirm that the generated lib/firebase_options.dart file is
   present and that the application initializes Firebase using
   DefaultFirebaseOptions.currentPlatform.
9. Install the project dependencies:
   flutter pub get
The Firebase client configuration identifies the Firebase project; it is
not a substitute for security rules. Do not put administrative
credentials in the Flutter application.
Create the Two Test Users
Create two separate Email/Password accounts for the access-control
tests.
1. Open the Firebase Console and select your project.
2. Go to Build → Authentication → Users.
3. Select Add user.
4. Create the first test account. Use this account as User A.
5. Repeat the process to create a second, separate account. Use this
   account as User B.
6. Keep the test credentials private. Do not add passwords to this
   README, source code, screenshots, or Git history.
Use the accounts as follows:
- User A: Creates a quiz attempt. This attempt is used to verify
  that the owner can access their own record.
- User B: Attempts to read or write User A's record. These
  operations should be denied by the Firestore security rules.
Use the actual test accounts configured in your Firebase project. Do not
publish their passwords in the repository.
Deploy Firestore Security Rules
The repository should contain the Firestore rules file:
firestore.rules
The Firebase configuration file should point to that rules file:
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
If the project has not yet been initialized for Firestore, run:
firebase init firestore
When prompted, select the Firebase project used by the application and
specify firestore.rules as the rules file. Preserve the existing rules
if they already contain the assignment's validation logic.

Select the correct Firebase project:
firebase use YOUR_FIREBASE_PROJECT_ID
Deploy the rules:
firebase deploy --only firestore:rules
After deployment:
1. Open the Firebase Console.
2. Select Firestore Database → Rules.
3. Confirm that the deployed rules match the repository's
   firestore.rules file.
4. Confirm that the rules restrict access to the authenticated owner.
5. Confirm that users cannot update or delete an existing attempt if
   the assignment's create-once design is implemented.
The intended attempt path is user-specific:
users/{uid}/attempts/{roundId}
The application must use the authenticated user's UID when constructing
this path. User B must not be able to access User A's attempt.
Development Flags and Test IDs
Development flags are used to simulate failure conditions so that error
handling can be tested. Before creating the final release APK, restore
the flags to their normal, non-injected settings.

The following flags are referenced by the project:
  Development flag       Available values      Related test      Purpose
  kInjectTriviaFault   none, badJson,    T03               Simulates
nonZeroCode,                          malformed JSON, a
nineResults                           nonzero API
response code, or
an incorrect
number of quiz
results.

  kInjectLostAck       true, false       T09               Simulates a lost
acknowledgement
after a cloud
write may have
committed.
kInjectCloudFault    none,               T12               Simulates
unavailable,                          different
resourceExhausted                     Firestore/cloud
failures.
Test mapping
  Test ID                             Test
  T01                                 Valid and invalid authentication

  T02                                 Load the required OpenTDB quiz URL
and validate ten questions

  T03                                 Test badJson, nonZeroCode, and
nineResults separately

  T04                                 Test correct answers, incorrect
answers, and repeated taps

  T05                                 Finish the quiz and replay with a
new round ID

  T06                                 Submit online and verify that
repeated Submit taps create only
one cloud document

  T07                                 Restart the app, sign in as the
same user, and retrieve the
original attempt

  T08                                 Disconnect before submission,
reconnect, and reconcile using the
same round ID

  T09                                 Enable kInjectLostAck, submit,
and reconcile the uncertain result

  T10                                 Verify that User B cannot read or
write User A's attempt

  T11                                 Verify rejection of an out-of-range
score, an extra field, and an
update
T12                                 Test unavailable and
resourceExhausted cloud failures
Important testing notes
- Change only the flag needed for the test being performed.
- Run each injected API fault in T03 separately.
- Record the actual observed result for every test.
- Do not report a save as successful until the application has
  verified the matching document from the server.
- For T09, the expected recovery path is saveUnknown followed by
  server reconciliation and, if the stored data matches,
  cloudVerified.
- Keep the same roundId when retrying or reconciling one attempt. A
  new quiz round should receive a new ID.
- Restore all development flags to their normal values before
  producing the final release build.
- Cloud security tests must be performed against the deployed Firebase
  project, not only against an emulator or local mock.
Run the Application
From the root of the repository, install dependencies:
flutter pub get
Check connected devices and available emulators:
flutter devices
Start an Android emulator, then run:
flutter run
If more than one device is connected, specify the target device:
flutter run -d DEVICE_ID
Replace DEVICE_ID with the identifier shown by flutter devices.

Sign in using one of the test accounts created in Firebase
Authentication. Confirm that the quiz loads and that the application can
retrieve the ten expected questions.
Build the Release APK
From the project root, run:
flutter clean
flutter pub get
flutter build apk --release
The generated APK is normally located at:
build/app/outputs/flutter-apk/app-release.apk
Copy or rename the APK for submission:
ICA16_A_Marc_Chishibanji.apk
Install and test the release APK on the Android emulator or a compatible
Android device before submitting it.
Firestore Data Structure
Quiz attempts are stored under the authenticated user's document:
users/{uid}/attempts/{roundId}
The attempt document uses the following fields:

  Field             Description
  schemaVersion   Attempt document schema version
variant         Assignment variant
categoryId      OpenTDB category ID
questionCount   Number of questions in the quiz
correctCount    Number of correct answers
submittedAt     Firestore server timestamp

The application should verify the saved document using a server read and
compare its values with the submitted attempt before displaying a
confirmed cloud-save status.
Final Commit
Repository: https://github.com/mchishibanji1/csc4360BuildaQuiz

Final commit hash: REPLACE_WITH_FINAL_COMMIT_HASH

To retrieve the full commit hash from the project directory, run:
git rev-parse HEAD
To retrieve the short commit hash, run:
git rev-parse --short HEAD
Copy the resulting hash into this section after the final code and
README changes have been committed.

To commit the completed README:
git add README.md
git commit -m "Add ICA16 project README"
git push
After pushing, run git rev-parse HEAD again and record that final hash
here.
Security Notes
- Never commit Firebase service-account private keys or other
  administrative credentials.
- Never put passwords, access tokens, or private keys in Dart source
  files.
- Do not publish the test users' passwords.
- Review screenshots and logs before committing or submitting them.
- Keep Firestore security rules in the repository and deploy them to
  the intended Firebase project.
- Do not rely on client-side checks alone to protect cloud data.
- Do not display a confirmed-save message until the server has
  confirmed the expected attempt document.
Student: Marc Chishibanji
Course: CSC 4360
Project: Cloud-Based Quiz Application
