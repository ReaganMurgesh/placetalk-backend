import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PlaceTalk'**
  String get appTitle;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @diary.
  ///
  /// In en, this message translates to:
  /// **'Diary'**
  String get diary;

  /// No description provided for @createPin.
  ///
  /// In en, this message translates to:
  /// **'Create Pin'**
  String get createPin;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @communityMember.
  ///
  /// In en, this message translates to:
  /// **'Community Member'**
  String get communityMember;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @enterCredentials.
  ///
  /// In en, this message translates to:
  /// **'Please enter your credentials'**
  String get enterCredentials;

  /// No description provided for @joinPlaceTalk.
  ///
  /// In en, this message translates to:
  /// **'Join PlaceTalk'**
  String get joinPlaceTalk;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account to start discovering'**
  String get createAccount;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerButton;

  /// No description provided for @mySerendipityDiary.
  ///
  /// In en, this message translates to:
  /// **'My Serendipity Diary'**
  String get mySerendipityDiary;

  /// No description provided for @passedPins.
  ///
  /// In en, this message translates to:
  /// **'Passed Pins'**
  String get passedPins;

  /// No description provided for @myPins.
  ///
  /// In en, this message translates to:
  /// **'My Pins'**
  String get myPins;

  /// No description provided for @noAdventuresYet.
  ///
  /// In en, this message translates to:
  /// **'No adventures yet.'**
  String get noAdventuresYet;

  /// No description provided for @privateMemories.
  ///
  /// In en, this message translates to:
  /// **'Private memories & discoveries'**
  String get privateMemories;

  /// No description provided for @yourSerendipityJournal.
  ///
  /// In en, this message translates to:
  /// **'Your Serendipity Journal'**
  String get yourSerendipityJournal;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details (Optional)'**
  String get details;

  /// No description provided for @rulesGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Rules & Guidelines for this Area'**
  String get rulesGuidelines;

  /// No description provided for @rulesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"Quiet zone - please speak softly\", \"Clean up after yourself\"...'**
  String get rulesHint;

  /// No description provided for @privacySafetyChecklist.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Safety Checklist'**
  String get privacySafetyChecklist;

  /// No description provided for @confirmBeforeCreating.
  ///
  /// In en, this message translates to:
  /// **'Please confirm before creating your pin:'**
  String get confirmBeforeCreating;

  /// No description provided for @publicSpace.
  ///
  /// In en, this message translates to:
  /// **'This is a PUBLIC space (not private property)'**
  String get publicSpace;

  /// No description provided for @publicSpaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Parks, cafes, streets, etc. - NOT someone\'s home'**
  String get publicSpaceSubtitle;

  /// No description provided for @respectPrivacy.
  ///
  /// In en, this message translates to:
  /// **'I respect privacy and local customs'**
  String get respectPrivacy;

  /// No description provided for @respectPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Won\'t disturb residents or private businesses'**
  String get respectPrivacySubtitle;

  /// No description provided for @followGuidelines.
  ///
  /// In en, this message translates to:
  /// **'I follow community guidelines'**
  String get followGuidelines;

  /// No description provided for @followGuidelinesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This pin follows PlaceTalk\'s community standards'**
  String get followGuidelinesSubtitle;

  /// No description provided for @noPrivateProperty.
  ///
  /// In en, this message translates to:
  /// **'No private homes or restricted areas'**
  String get noPrivateProperty;

  /// No description provided for @noPrivatePropertySubtitle.
  ///
  /// In en, this message translates to:
  /// **'I will not pin private residences or secure facilities'**
  String get noPrivatePropertySubtitle;

  /// No description provided for @dropPinHere.
  ///
  /// In en, this message translates to:
  /// **'Drop Pin Here 📍'**
  String get dropPinHere;

  /// No description provided for @pinCreatedSafely.
  ///
  /// In en, this message translates to:
  /// **'Pin created safely! Thank you for respecting privacy.'**
  String get pinCreatedSafely;

  /// No description provided for @gpsReady.
  ///
  /// In en, this message translates to:
  /// **'GPS Ready'**
  String get gpsReady;

  /// No description provided for @gpsCoordinates.
  ///
  /// In en, this message translates to:
  /// **'GPS Coordinates'**
  String get gpsCoordinates;

  /// No description provided for @createPinAtLocation.
  ///
  /// In en, this message translates to:
  /// **'Create pin at this location?'**
  String get createPinAtLocation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
