import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:fyp_musicapp_aws/pages/home_page.dart';
import 'package:fyp_musicapp_aws/theme/app_color.dart';
import 'amplifyconfiguration.dart';
import 'models/ModelProvider.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
    Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
      if (event.type == AuthHubEventType.signedIn) {
        _handlePostSignUp(null);
      }
    });
  }

  Future<void> _configureAmplify() async {
    try {
      final auth = AmplifyAuthCognito();
      final storage = AmplifyStorageS3();
      final api = AmplifyAPI(
        options: APIPluginOptions(modelProvider: ModelProvider.instance),
      );
      await Amplify.addPlugins([auth, storage, api]);
      await Amplify.configure(amplifyconfig);
      safePrint('Successfully configured');

      // Check initial auth state
      await _updateAuthState();

      // Listen for auth events
      Amplify.Hub.listen(HubChannel.Auth, _onAuthEvent);
    } on Exception catch (e) {
      safePrint('Error configuring Amplify: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateAuthState() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      setState(() {
        _isSignedIn = session.isSignedIn;
        _isLoading = false;
      });
    } on Exception catch (e) {
      safePrint('Error configuring Amplify: $e');
    }
  }

  void _onAuthEvent(AuthHubEvent event) {
    switch (event.type) {
      case AuthHubEventType.signedIn:
        safePrint('User is signed in.');
        _updateAuthState();
        break;
      case AuthHubEventType.signedOut:
        safePrint('User is signed out.');
        _updateAuthState();
        break;
      case AuthHubEventType.sessionExpired:
        safePrint('Session expired.');
        _updateAuthState();
        break;
      case AuthHubEventType.userDeleted:
        safePrint('User is deleted.');
        _updateAuthState();
        break;
    }
  }

  Future<void> _handlePostSignUp(Map<String, dynamic>? payload) async {
    try {
      // Get current auth user
      final user = await Amplify.Auth.getCurrentUser();

      // Query by username
      final request = ModelQueries.list(
        Users.classType,
        where: Users.NAME.eq(user.username),
      );
      final response = await Amplify.API.query(request: request).response;
      final existingUsers = response.data?.items;

      // Only proceed if user doesn't exist
      if (existingUsers == null || existingUsers.isEmpty) {
        final attributes = await Amplify.Auth.fetchUserAttributes();

        final email = attributes
            .firstWhere((element) =>
                element.userAttributeKey == AuthUserAttributeKey.email)
            .value;
        final preferFileType = attributes
            .firstWhere((element) =>
                element.userAttributeKey ==
                const CognitoUserAttributeKey.custom('preferFileType'))
            .value;

        // Create user in DynamoDB
        await createUsers(
          user.username,
          email,
          preferFileType,
        );
        safePrint('User data stored in DynamoDB successfully');
      } else {
        safePrint('User already exists in DynamoDB');
      }
    } catch (e) {
      safePrint('Error handling post sign up: $e');
    }
  }

  Future<void> createUsers(
      String name, String email, String preferFileType) async {
    try {
      final model =
          Users(name: name, email: email, preferFileType: preferFileType);
      final request = ModelMutations.create(model);
      final response = await Amplify.API.mutate(request: request).response;

      final createdUsers = response.data;
      if (createdUsers == null) {
        safePrint('errors: ${response.errors}');
        return;
      }
      safePrint('Mutation result: ${createdUsers.id}');
    } on ApiException catch (e) {
      safePrint('Mutation failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        theme: _buildAppTheme(),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Authenticator(
      // `authenticatorBuilder` is used to customize the UI for one or more steps
      authenticatorBuilder: (BuildContext context, AuthenticatorState state) {
        switch (state.currentStep) {
          case AuthenticatorStep.signIn:
            return CustomScaffold(
              state: state,
              // A prebuilt Sign In form from amplify_authenticator
              body: Column(
                children: [
                  SignInForm(),
                ],
              ),

              // A custom footer with a button to take the user to sign up
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account?'),
                  TextButton(
                    onPressed: () => state.changeStep(
                      AuthenticatorStep.signUp,
                    ),
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            );
          case AuthenticatorStep.signUp:
            return CustomScaffold(
              state: state,
              // A prebuilt Sign Up form from amplify_authenticator
              body: SignUpForm.custom(
                fields: [
                  SignUpFormField.username(),
                  SignUpFormField.email(required: true),
                  SignUpFormField.custom(
                    title: 'Prefer File Types',
                    attributeKey:
                        const CognitoUserAttributeKey.custom('preferFileType'),
                    required: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Prefer File Type is required';
                      } else if (value != 'mp3' && value != 'flac') {
                        return 'Prefer File Type must be mp3 or flac';
                      }
                      return null;
                    },
                    hintText: 'only mp3 / flac',
                  ),
                  SignUpFormField.password(),
                  SignUpFormField.passwordConfirmation(),
                ],
              ),
              // A custom footer with a button to take the user to sign in
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () => state.changeStep(
                      AuthenticatorStep.signIn,
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            );
          case AuthenticatorStep.confirmSignUp:
            return CustomScaffold(
              state: state,
              // A prebuilt Confirm Sign Up form from amplify_authenticator
              body: ConfirmSignUpForm(),
            );
          case AuthenticatorStep.resetPassword:
            return CustomScaffold(
              state: state,
              // A prebuilt Reset Password form from amplify_authenticator
              body: ResetPasswordForm(),
            );
          case AuthenticatorStep.confirmResetPassword:
            return CustomScaffold(
              state: state,
              // A prebuilt Confirm Reset Password form from amplify_authenticator
              body: const ConfirmResetPasswordForm(),
            );
          default:
            // Returning null defaults to the prebuilt authenticator for all other steps
            return null;
        }
      },
      child: MaterialApp(
        builder: Authenticator.builder(),
        theme: _buildAppTheme(),
        home: _isSignedIn ? const HomePage() : const SizedBox.shrink(),
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      scaffoldBackgroundColor: const Color(0xFF151515),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(
          fontSize: 16.0,
          color: Color(0xFFFDFDFD),
        ),
        labelStyle: TextStyle(
          fontSize: 16.0,
          color: Color(0xFFFDFDFD),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFFDFDFD)),
        ),
      ),
      useMaterial3: true,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: AppColor.primaryColor,
        backgroundColor: const Color(0xFF151515),
        brightness: Brightness.dark,
      ),
    );
  }
}

/// A widget that displays a logo, a body, and an optional footer.
class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    required this.state,
    required this.body,
    this.footer,
  });

  final AuthenticatorState state;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(78),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // App logo
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 96),
                  child:
                      Center(child: Image.asset('images/logo.png', width: 84)),
                ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: body,
                ),
              ],
            ),
          ),
        ),
        persistentFooterButtons: footer != null ? [footer!] : null,
      ),
    );
  }
}
