import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ko'),
  ];

  /// No description provided for @mapAuthRegistrationError.
  ///
  /// In en, this message translates to:
  /// **'Map authentication failed (MAP_401). The app administrator needs to check the Kakao Android package and signing key hash registration.'**
  String get mapAuthRegistrationError;

  /// No description provided for @mapPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Map permission denied (MAP_403). The app administrator needs to enable Kakao Maps for this app.'**
  String get mapPermissionError;

  /// No description provided for @googleRegistrationError.
  ///
  /// In en, this message translates to:
  /// **'Google app configuration error (GOOGLE_CONFIG). The app administrator needs to check the Android package, signing SHA-1 and OAuth clients.'**
  String get googleRegistrationError;

  /// No description provided for @googleSignInCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google connection did not complete. If it closed after account selection, the app\'s Android authentication settings may need checking.'**
  String get googleSignInCanceled;

  /// No description provided for @googleAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'The Google account does not match. Sign out and reconnect with the account used for your calendar.'**
  String get googleAccountMismatch;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LifeRadar'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get tabMap;

  /// No description provided for @tabPlans.
  ///
  /// In en, this message translates to:
  /// **'My Plans'**
  String get tabPlans;

  /// No description provided for @tabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get tabDiscover;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Events for you'**
  String get homeGreeting;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What changed around your plans and interests'**
  String get homeSubtitle;

  /// No description provided for @whyItMatters.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get whyItMatters;

  /// No description provided for @aiWritten.
  ///
  /// In en, this message translates to:
  /// **'Written with Gemini'**
  String get aiWritten;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errBusy.
  ///
  /// In en, this message translates to:
  /// **'The service is busy right now. Please try again in a minute.'**
  String get errBusy;

  /// No description provided for @errService.
  ///
  /// In en, this message translates to:
  /// **'This service isn\'t available right now.'**
  String get errService;

  /// No description provided for @errNoRoute.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find a route between these places.'**
  String get errNoRoute;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @eventsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Real public data · {count} events · updated {date}'**
  String eventsUpdated(int count, String date);

  /// No description provided for @notifyDeniedApp.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Turn on notifications for LifeRadar in Settings, then try again.'**
  String get notifyDeniedApp;

  /// No description provided for @planLinkNearby.
  ///
  /// In en, this message translates to:
  /// **'{km} km from your plan · while you\'re there'**
  String planLinkNearby(String km);

  /// No description provided for @planLinkCrowd.
  ///
  /// In en, this message translates to:
  /// **'Same day · {km} km away'**
  String planLinkCrowd(String km);

  /// No description provided for @planLinkTraffic.
  ///
  /// In en, this message translates to:
  /// **'Before your plan starts · official road control'**
  String get planLinkTraffic;

  /// No description provided for @planLinkStrike.
  ///
  /// In en, this message translates to:
  /// **'Same day · news report (for reference)'**
  String get planLinkStrike;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence {percent}%'**
  String confidence(int percent);

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @feedbackThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks! We\'ll tune your signals.'**
  String get feedbackThanks;

  /// No description provided for @layerPlans.
  ///
  /// In en, this message translates to:
  /// **'My Plans'**
  String get layerPlans;

  /// No description provided for @layerRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get layerRecommended;

  /// No description provided for @layerRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get layerRoute;

  /// No description provided for @modeExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get modeExplore;

  /// No description provided for @modeMyMap.
  ///
  /// In en, this message translates to:
  /// **'My Map'**
  String get modeMyMap;

  /// No description provided for @modeRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get modeRoute;

  /// No description provided for @mapKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Kakao Map key is missing.\nRun with --dart-define-from-file=env.json'**
  String get mapKeyMissing;

  /// No description provided for @mapError.
  ///
  /// In en, this message translates to:
  /// **'Map failed to load: {message}'**
  String mapError(String message);

  /// No description provided for @plansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No upcoming plans yet. Connect Google Calendar to import them.'**
  String get plansEmpty;

  /// No description provided for @connectCalendar.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Calendar'**
  String get connectCalendar;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @discoverAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get discoverAll;

  /// No description provided for @whyForYou.
  ///
  /// In en, this message translates to:
  /// **'Why for you'**
  String get whyForYou;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @addToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get addToCalendar;

  /// No description provided for @noRegisterLink.
  ///
  /// In en, this message translates to:
  /// **'No registration link yet'**
  String get noRegisterLink;

  /// No description provided for @sampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample data'**
  String get sampleData;

  /// No description provided for @matchesInterests.
  ///
  /// In en, this message translates to:
  /// **'Matches your interests: {tags}'**
  String matchesInterests(String tags);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @categoryConference.
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get categoryConference;

  /// No description provided for @categoryHackathon.
  ///
  /// In en, this message translates to:
  /// **'Hackathon'**
  String get categoryHackathon;

  /// No description provided for @categoryConcert.
  ///
  /// In en, this message translates to:
  /// **'Concert'**
  String get categoryConcert;

  /// No description provided for @categoryFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get categoryFestival;

  /// No description provided for @categoryMeetup.
  ///
  /// In en, this message translates to:
  /// **'Meetup'**
  String get categoryMeetup;

  /// No description provided for @categoryJob.
  ///
  /// In en, this message translates to:
  /// **'Job'**
  String get categoryJob;

  /// No description provided for @categoryScholarship.
  ///
  /// In en, this message translates to:
  /// **'Scholarship'**
  String get categoryScholarship;

  /// No description provided for @mapSdkNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Kakao Map SDK did not load.\nRegister this address as a Web domain in Kakao Developers:\n{origin}'**
  String mapSdkNotLoaded(String origin);

  /// No description provided for @routeFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get routeFrom;

  /// No description provided for @routeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get routeTo;

  /// No description provided for @routeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get routeDate;

  /// No description provided for @routeFind.
  ///
  /// In en, this message translates to:
  /// **'Find opportunities'**
  String get routeFind;

  /// No description provided for @routeDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo: Seoul St. → Busan St.'**
  String get routeDemo;

  /// No description provided for @routeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a place (e.g. 부산역, BEXCO)'**
  String get routeSearchHint;

  /// No description provided for @routeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get routeNoResults;

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'{distance} km · {duration} by car'**
  String routeSummary(String distance, String duration);

  /// No description provided for @routeAlongTheWay.
  ///
  /// In en, this message translates to:
  /// **'Along the way ({count})'**
  String routeAlongTheWay(int count);

  /// No description provided for @routeNoOpportunities.
  ///
  /// In en, this message translates to:
  /// **'No matching events within 15 km of this route on that day.'**
  String get routeNoOpportunities;

  /// No description provided for @routeDetour.
  ///
  /// In en, this message translates to:
  /// **'+{km} km · +{minutes} min'**
  String routeDetour(String km, int minutes);

  /// No description provided for @routeFromRoute.
  ///
  /// In en, this message translates to:
  /// **'{km} km from route'**
  String routeFromRoute(String km);

  /// No description provided for @routeError.
  ///
  /// In en, this message translates to:
  /// **'Route failed: {message}'**
  String routeError(String message);

  /// No description provided for @onYourWay.
  ///
  /// In en, this message translates to:
  /// **'On your way'**
  String get onYourWay;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String hoursMinutes(int h, int m);

  /// No description provided for @travelCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get travelCar;

  /// No description provided for @travelTransit.
  ///
  /// In en, this message translates to:
  /// **'Transit'**
  String get travelTransit;

  /// No description provided for @routeSummaryTransit.
  ///
  /// In en, this message translates to:
  /// **'{distance} km · {duration} · {lines}'**
  String routeSummaryTransit(String distance, String duration, String lines);

  /// No description provided for @calendarConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Google…'**
  String get calendarConnecting;

  /// No description provided for @calendarSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing calendar…'**
  String get calendarSyncing;

  /// No description provided for @calendarConnectedCount.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar · {count} upcoming plans'**
  String calendarConnectedCount(int count);

  /// No description provided for @calendarSync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get calendarSync;

  /// No description provided for @calendarDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get calendarDisconnect;

  /// No description provided for @calendarExpired.
  ///
  /// In en, this message translates to:
  /// **'Google session expired. Please connect again.'**
  String get calendarExpired;

  /// No description provided for @calendarNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t set up on this platform yet (web only for now).'**
  String get calendarNotConfigured;

  /// No description provided for @calendarError.
  ///
  /// In en, this message translates to:
  /// **'Calendar error: {message}'**
  String calendarError(String message);

  /// No description provided for @calendarPrivacy.
  ///
  /// In en, this message translates to:
  /// **'LifeRadar only reads upcoming events and adds events you choose. Disconnect anytime.'**
  String get calendarPrivacy;

  /// No description provided for @noLocation.
  ///
  /// In en, this message translates to:
  /// **'No location'**
  String get noLocation;

  /// No description provided for @sourceCalendar.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar'**
  String get sourceCalendar;

  /// No description provided for @addedToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Added to Google Calendar'**
  String get addedToCalendar;

  /// No description provided for @addingToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get addingToCalendar;

  /// No description provided for @weatherLater.
  ///
  /// In en, this message translates to:
  /// **'Forecast appears ~10 days before'**
  String get weatherLater;

  /// No description provided for @onboardingTagline.
  ///
  /// In en, this message translates to:
  /// **'Finds the opportunities around your plans — before you search.'**
  String get onboardingTagline;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'What are you into?'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a few. LifeRadar ranks events and route suggestions by these.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingPickOne.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one'**
  String get onboardingPickOne;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue ({count} selected)'**
  String onboardingContinue(int count);

  /// No description provided for @onboardingPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this device. You can change it anytime.'**
  String get onboardingPrivacy;

  /// No description provided for @interestsEdit.
  ///
  /// In en, this message translates to:
  /// **'My interests'**
  String get interestsEdit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No signals yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Connect your calendar or add more interests — LifeRadar will connect your plans with events and weather.'**
  String get homeEmptyBody;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get loginError;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Look around as a guest'**
  String get continueAsGuest;

  /// No description provided for @loginPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your calendar is connected separately, only with your consent.'**
  String get loginPrivacy;

  /// No description provided for @guestName.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guestName;

  /// No description provided for @guestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use your own account'**
  String get guestSubtitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @sectionConnections.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get sectionConnections;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @sectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get sectionSettings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @exitGuest.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get exitGuest;

  /// No description provided for @homeHello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get homeHello;

  /// No description provided for @homeHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String homeHelloName(String name);

  /// No description provided for @statPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get statPlans;

  /// No description provided for @statSignals.
  ///
  /// In en, this message translates to:
  /// **'Signals'**
  String get statSignals;

  /// No description provided for @statDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Deadlines'**
  String get statDeadlines;

  /// No description provided for @kindPlanAlert.
  ///
  /// In en, this message translates to:
  /// **'Plan alert'**
  String get kindPlanAlert;

  /// No description provided for @kindOpportunity.
  ///
  /// In en, this message translates to:
  /// **'Opportunity'**
  String get kindOpportunity;

  /// No description provided for @kindDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get kindDeadline;

  /// No description provided for @kindRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get kindRoute;

  /// No description provided for @helpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get helpful;

  /// No description provided for @notForMe.
  ///
  /// In en, this message translates to:
  /// **'Not for me'**
  String get notForMe;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sorted by how well they match your interests'**
  String get discoverSubtitle;

  /// No description provided for @matchBadge.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get matchBadge;

  /// No description provided for @eventDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get eventDetails;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get openSource;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @rainChance.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get rainChance;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @planNew.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get planNew;

  /// No description provided for @planEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get planEdit;

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get planTitle;

  /// No description provided for @planTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Busan business trip'**
  String get planTitleHint;

  /// No description provided for @planTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get planTitleRequired;

  /// No description provided for @planDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get planDate;

  /// No description provided for @planStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get planStart;

  /// No description provided for @planEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get planEnd;

  /// No description provided for @planAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get planAllDay;

  /// No description provided for @planLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get planLocation;

  /// No description provided for @planLocationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get planLocationAdd;

  /// No description provided for @planLocationRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove place'**
  String get planLocationRemove;

  /// No description provided for @planNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get planNote;

  /// No description provided for @planNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Anything to remember'**
  String get planNoteHint;

  /// No description provided for @planSaveToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Also save to Google Calendar'**
  String get planSaveToCalendar;

  /// No description provided for @planCalendarSynced.
  ///
  /// In en, this message translates to:
  /// **'Changes are saved to your Google Calendar too.'**
  String get planCalendarSynced;

  /// No description provided for @planSampleHint.
  ///
  /// In en, this message translates to:
  /// **'Sample plan — saving makes it your own plan.'**
  String get planSampleHint;

  /// No description provided for @planDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get planDelete;

  /// No description provided for @planDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"?'**
  String planDeleteConfirm(String title);

  /// No description provided for @planSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get planSaved;

  /// No description provided for @planDeleted.
  ///
  /// In en, this message translates to:
  /// **'Plan deleted'**
  String get planDeleted;

  /// No description provided for @planEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'End time must be after the start'**
  String get planEndBeforeStart;

  /// No description provided for @planSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save: {message}'**
  String planSaveError(String message);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @openInCalendar.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Calendar'**
  String get openInCalendar;

  /// No description provided for @plansEmptyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add your first plan, or connect Google Calendar to import them.'**
  String get plansEmptyAdd;

  /// No description provided for @interestsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String interestsSelectedCount(int count);

  /// No description provided for @categoryPerformance.
  ///
  /// In en, this message translates to:
  /// **'Theater & musicals'**
  String get categoryPerformance;

  /// No description provided for @categoryExhibition.
  ///
  /// In en, this message translates to:
  /// **'Exhibition'**
  String get categoryExhibition;

  /// No description provided for @categoryClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get categoryClasses;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @dataSource.
  ///
  /// In en, this message translates to:
  /// **'Data: {name}'**
  String dataSource(String name);

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @realData.
  ///
  /// In en, this message translates to:
  /// **'Live data'**
  String get realData;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @categoryStartupSupport.
  ///
  /// In en, this message translates to:
  /// **'Startup programs'**
  String get categoryStartupSupport;

  /// No description provided for @applicationPeriod.
  ///
  /// In en, this message translates to:
  /// **'Applications {from} – {to}'**
  String applicationPeriod(String from, String to);

  /// No description provided for @nationwide.
  ///
  /// In en, this message translates to:
  /// **'Nationwide'**
  String get nationwide;

  /// No description provided for @applyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyNow;

  /// No description provided for @aiTranslated.
  ///
  /// In en, this message translates to:
  /// **'Translated from Korean with Gemini'**
  String get aiTranslated;

  /// No description provided for @statForPlans.
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get statForPlans;

  /// No description provided for @statAll.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get statAll;

  /// No description provided for @statSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get statSoon;

  /// No description provided for @homeSectionPlans.
  ///
  /// In en, this message translates to:
  /// **'Around your plans'**
  String get homeSectionPlans;

  /// No description provided for @homeSectionDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Deadlines coming up'**
  String get homeSectionDeadlines;

  /// No description provided for @homeFilterEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here right now'**
  String get homeFilterEmpty;

  /// No description provided for @dislikeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Not for you?'**
  String get dislikeConfirmTitle;

  /// No description provided for @dislikeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll show fewer signals like this one.'**
  String get dislikeConfirmBody;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @feedbackLiked.
  ///
  /// In en, this message translates to:
  /// **'Thanks! You\'ll see more like this'**
  String get feedbackLiked;

  /// No description provided for @feedbackDisliked.
  ///
  /// In en, this message translates to:
  /// **'Got it — fewer signals like this'**
  String get feedbackDisliked;

  /// No description provided for @untilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String untilDate(String date);

  /// No description provided for @openEvent.
  ///
  /// In en, this message translates to:
  /// **'Event details'**
  String get openEvent;

  /// No description provided for @signalWhy.
  ///
  /// In en, this message translates to:
  /// **'Why this signal'**
  String get signalWhy;

  /// No description provided for @calendarAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add to calendar'**
  String get calendarAddFailed;

  /// No description provided for @interestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String interestsCount(int count);

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a look'**
  String get themeTitle;

  /// No description provided for @themeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Profile.'**
  String get themeSubtitle;

  /// No description provided for @themeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Follows your device'**
  String get themeSystemDesc;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Bright and clear'**
  String get themeLightDesc;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Easy on the eyes at night'**
  String get themeDarkDesc;

  /// No description provided for @nameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get nameTitle;

  /// No description provided for @nameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll greet you with this on the home screen. You can change it later in Profile.'**
  String get nameSubtitle;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameHint;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get nameRequired;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {n} of {total}'**
  String stepOf(int n, int total);

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Signals from your plans and interests'**
  String get welcomeTagline;

  /// No description provided for @loginF1Title.
  ///
  /// In en, this message translates to:
  /// **'Plans meet the world'**
  String get loginF1Title;

  /// No description provided for @loginF1Body.
  ///
  /// In en, this message translates to:
  /// **'Calendar × events × weather × deadlines'**
  String get loginF1Body;

  /// No description provided for @loginF2Title.
  ///
  /// In en, this message translates to:
  /// **'Opportunities on your way'**
  String get loginF2Title;

  /// No description provided for @loginF2Body.
  ///
  /// In en, this message translates to:
  /// **'KTX or car — see the detour in km and minutes'**
  String get loginF2Body;

  /// No description provided for @loginF3Title.
  ///
  /// In en, this message translates to:
  /// **'Know why it matters'**
  String get loginF3Title;

  /// No description provided for @loginF3Body.
  ///
  /// In en, this message translates to:
  /// **'Every signal comes with reasons and sources'**
  String get loginF3Body;

  /// No description provided for @loginPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get started'**
  String get loginPanelTitle;

  /// No description provided for @loginPanelBody.
  ///
  /// In en, this message translates to:
  /// **'Your Google account is all you need — no extra sign-up.'**
  String get loginPanelBody;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked. Allow it in your browser or device settings.'**
  String get locationDenied;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location right now.'**
  String get locationUnavailable;

  /// No description provided for @planViewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month view'**
  String get planViewMonth;

  /// No description provided for @planViewList.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get planViewList;

  /// No description provided for @noPlansThisDay.
  ///
  /// In en, this message translates to:
  /// **'No plans on this day'**
  String get noPlansThisDay;

  /// No description provided for @planSignalRain.
  ///
  /// In en, this message translates to:
  /// **'Rain likely — bring an umbrella'**
  String get planSignalRain;

  /// No description provided for @planSignalCrowd.
  ///
  /// In en, this message translates to:
  /// **'{event} nearby — expect crowds'**
  String planSignalCrowd(String event);

  /// No description provided for @planSignalNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby: {event}'**
  String planSignalNearby(String event);

  /// No description provided for @planAround.
  ///
  /// In en, this message translates to:
  /// **'Around this plan'**
  String get planAround;

  /// No description provided for @planNothingAround.
  ///
  /// In en, this message translates to:
  /// **'Nothing unusual around this plan right now.'**
  String get planNothingAround;

  /// No description provided for @myPlanBadge.
  ///
  /// In en, this message translates to:
  /// **'My plan'**
  String get myPlanBadge;

  /// No description provided for @calendarOpenGoogle.
  ///
  /// In en, this message translates to:
  /// **'Open Google Calendar'**
  String get calendarOpenGoogle;

  /// No description provided for @planWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get planWhen;

  /// No description provided for @planWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get planWhere;

  /// No description provided for @likeUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove your like?'**
  String get likeUndoTitle;

  /// No description provided for @likeUndoBody.
  ///
  /// In en, this message translates to:
  /// **'This signal will be ranked like any other again.'**
  String get likeUndoBody;

  /// No description provided for @dislikeUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Show signals like this again?'**
  String get dislikeUndoTitle;

  /// No description provided for @dislikeUndoBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll stop pushing this one down.'**
  String get dislikeUndoBody;

  /// No description provided for @removeLike.
  ///
  /// In en, this message translates to:
  /// **'Remove like'**
  String get removeLike;

  /// No description provided for @showAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get showAgain;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @notForMeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Not for me'**
  String get notForMeConfirm;

  /// No description provided for @feedbackCleared.
  ///
  /// In en, this message translates to:
  /// **'Feedback removed'**
  String get feedbackCleared;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notifyDesc.
  ///
  /// In en, this message translates to:
  /// **'Deadlines, plan alerts and rain — as system notifications'**
  String get notifyDesc;

  /// No description provided for @notifyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device yet'**
  String get notifyUnsupported;

  /// No description provided for @notifyDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked. Allow them in your browser settings.'**
  String get notifyDenied;

  /// No description provided for @notifyOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications on'**
  String get notifyOn;

  /// No description provided for @notifyTest.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get notifyTest;

  /// No description provided for @notifyTestBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are working. We\'ll tell you when something affects your plans.'**
  String get notifyTestBody;

  /// No description provided for @accountData.
  ///
  /// In en, this message translates to:
  /// **'Account & data'**
  String get accountData;

  /// No description provided for @accountDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and everything stored on this device'**
  String get accountDataSubtitle;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your name, interests, your own plans, feedback and settings will be erased from this device, Google access will be revoked, and the app will start over from the beginning. This can\'t be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'LifeRadar keeps your data only on this device. Deleting removes it all and disconnects Google Calendar.'**
  String get deleteAccountInfo;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted. Starting fresh.'**
  String get accountDeleted;

  /// No description provided for @eventAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get eventAbout;

  /// No description provided for @eventPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get eventPrice;

  /// No description provided for @applicationLabel.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get applicationLabel;

  /// No description provided for @organizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// No description provided for @matchesYou.
  ///
  /// In en, this message translates to:
  /// **'Matches your interests'**
  String get matchesYou;

  /// No description provided for @routePanelHint.
  ///
  /// In en, this message translates to:
  /// **'Pull down to see more of the map'**
  String get routePanelHint;

  /// No description provided for @routePanelExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand route panel'**
  String get routePanelExpand;

  /// No description provided for @routePanelCollapse.
  ///
  /// In en, this message translates to:
  /// **'Lower route panel'**
  String get routePanelCollapse;

  /// No description provided for @filterMine.
  ///
  /// In en, this message translates to:
  /// **'My interests'**
  String get filterMine;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search events or places'**
  String get discoverSearchHint;

  /// No description provided for @filterPeriod.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get filterPeriod;

  /// No description provided for @filterAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get filterAnyTime;

  /// No description provided for @periodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get periodToday;

  /// No description provided for @periodWeekend.
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get periodWeekend;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get periodMonth;

  /// No description provided for @filterRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get filterRegion;

  /// No description provided for @filterAllRegions.
  ///
  /// In en, this message translates to:
  /// **'All regions'**
  String get filterAllRegions;

  /// No description provided for @sortMatch.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get sortMatch;

  /// No description provided for @sortSoon.
  ///
  /// In en, this message translates to:
  /// **'Soonest'**
  String get sortSoon;

  /// No description provided for @discoverPicks.
  ///
  /// In en, this message translates to:
  /// **'Picked for your interests'**
  String get discoverPicks;

  /// No description provided for @discoverResults.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String discoverResults(int count);

  /// No description provided for @filterReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterReset;

  /// No description provided for @discoverNoResults.
  ///
  /// In en, this message translates to:
  /// **'No events match these filters'**
  String get discoverNoResults;

  /// No description provided for @routeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get routeEdit;

  /// No description provided for @stageTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s your situation right now?'**
  String get stageTitle;

  /// No description provided for @stageOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional · we\'ll show fitting programs and events first'**
  String get stageOptional;

  /// No description provided for @aboutMeCta.
  ///
  /// In en, this message translates to:
  /// **'Tell the AI about yourself'**
  String get aboutMeCta;

  /// No description provided for @aboutMeCtaBody.
  ///
  /// In en, this message translates to:
  /// **'Write a few sentences and we\'ll suggest your situation and interests. You choose.'**
  String get aboutMeCtaBody;

  /// No description provided for @aboutMeTitle.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get aboutMeTitle;

  /// No description provided for @aboutMeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Tell me a bit about yourself — what you do, what you\'re into lately, what you do on weekends. Anything works.'**
  String get aboutMeGreeting;

  /// No description provided for @aboutMeEx1.
  ///
  /// In en, this message translates to:
  /// **'I\'m a 3rd-year CS student. Studying AI and I\'d like to try a hackathon.'**
  String get aboutMeEx1;

  /// No description provided for @aboutMeEx2.
  ///
  /// In en, this message translates to:
  /// **'I work at a marketing company. I run after work and visit exhibitions on weekends.'**
  String get aboutMeEx2;

  /// No description provided for @aboutMeEx3.
  ///
  /// In en, this message translates to:
  /// **'I\'m preparing a startup. I need info on investor sessions and startup support programs.'**
  String get aboutMeEx3;

  /// No description provided for @aboutMeHint.
  ///
  /// In en, this message translates to:
  /// **'Write about yourself'**
  String get aboutMeHint;

  /// No description provided for @aboutMeSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aboutMeSend;

  /// No description provided for @aboutMeThinking.
  ///
  /// In en, this message translates to:
  /// **'Reading…'**
  String get aboutMeThinking;

  /// No description provided for @aboutMeUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what I understood. Keep what fits.'**
  String get aboutMeUnderstood;

  /// No description provided for @aboutMeKeyword.
  ///
  /// In en, this message translates to:
  /// **'Matched by keywords (AI not connected). Keep what fits.'**
  String get aboutMeKeyword;

  /// No description provided for @aboutMeNothing.
  ///
  /// In en, this message translates to:
  /// **'I\'m not sure yet. Tell me a little more about what you do or enjoy.'**
  String get aboutMeNothing;

  /// No description provided for @aboutMeStage.
  ///
  /// In en, this message translates to:
  /// **'Situation: {stage}'**
  String aboutMeStage(String stage);

  /// No description provided for @aboutMeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count})'**
  String aboutMeApply(int count);

  /// No description provided for @aboutMeApplied.
  ///
  /// In en, this message translates to:
  /// **'Added {count} interests'**
  String aboutMeApplied(int count);

  /// No description provided for @aboutMeAiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI suggestion'**
  String get aboutMeAiBadge;

  /// No description provided for @aboutMePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your text is sent to Google Gemini only to make suggestions, and saved on this device only.'**
  String get aboutMePrivacy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareFooter.
  ///
  /// In en, this message translates to:
  /// **'Found on LifeRadar'**
  String get shareFooter;

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to share'**
  String get shareCopied;

  /// No description provided for @planDeleteCalendarNote.
  ///
  /// In en, this message translates to:
  /// **'It will also be removed from Google Calendar.'**
  String get planDeleteCalendarNote;

  /// No description provided for @assistantButton.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get assistantButton;

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'LifeRadar AI'**
  String get assistantTitle;

  /// No description provided for @assistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answers from your plans and real data'**
  String get assistantSubtitle;

  /// No description provided for @assistantNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get assistantNewChat;

  /// No description provided for @assistantHello.
  ///
  /// In en, this message translates to:
  /// **'What can I find for you?'**
  String get assistantHello;

  /// No description provided for @assistantHelloBody.
  ///
  /// In en, this message translates to:
  /// **'I look at your plans, interests and real public data.\nI only add things to your calendar after you confirm.'**
  String get assistantHelloBody;

  /// No description provided for @assistantSuggestWeekend.
  ///
  /// In en, this message translates to:
  /// **'What should I do this weekend?'**
  String get assistantSuggestWeekend;

  /// No description provided for @assistantSuggestPlan.
  ///
  /// In en, this message translates to:
  /// **'Anything worth visiting during {plan}?'**
  String assistantSuggestPlan(String plan);

  /// No description provided for @assistantSuggestDeadline.
  ///
  /// In en, this message translates to:
  /// **'Any deadlines coming up?'**
  String get assistantSuggestDeadline;

  /// No description provided for @assistantSuggestFree.
  ///
  /// In en, this message translates to:
  /// **'Recommend a free exhibition'**
  String get assistantSuggestFree;

  /// No description provided for @assistantTrust.
  ///
  /// In en, this message translates to:
  /// **'Code picks candidates from real data; the AI only answers from them'**
  String get assistantTrust;

  /// No description provided for @assistantThinking.
  ///
  /// In en, this message translates to:
  /// **'Looking through your plans and events…'**
  String get assistantThinking;

  /// No description provided for @assistantAiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI answer'**
  String get assistantAiBadge;

  /// No description provided for @assistantRuleBadge.
  ///
  /// In en, this message translates to:
  /// **'Filter search'**
  String get assistantRuleBadge;

  /// No description provided for @assistantRuleNote.
  ///
  /// In en, this message translates to:
  /// **'AI isn\'t connected, so these are filter results.'**
  String get assistantRuleNote;

  /// No description provided for @assistantHint.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything'**
  String get assistantHint;

  /// No description provided for @assistantFooter.
  ///
  /// In en, this message translates to:
  /// **'The AI only suggests. You confirm every change.'**
  String get assistantFooter;

  /// No description provided for @assistantProposeCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to your calendar?'**
  String get assistantProposeCalendar;

  /// No description provided for @assistantProposeMap.
  ///
  /// In en, this message translates to:
  /// **'See it on the map?'**
  String get assistantProposeMap;

  /// No description provided for @assistantAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get assistantAdd;

  /// No description provided for @assistantOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get assistantOpen;

  /// No description provided for @assistantAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get assistantAdded;

  /// No description provided for @assistantOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened'**
  String get assistantOpened;

  /// No description provided for @assistantCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get assistantCancelled;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @planRouteAdd.
  ///
  /// In en, this message translates to:
  /// **'Add route'**
  String get planRouteAdd;

  /// No description provided for @planRouteArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get planRouteArrival;

  /// No description provided for @planRouteAutoLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations from your adjacent plans. Find and save a transit route.'**
  String get planRouteAutoLocations;

  /// No description provided for @planRouteDelete.
  ///
  /// In en, this message translates to:
  /// **'Remove route'**
  String get planRouteDelete;

  /// No description provided for @planRouteDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get planRouteDeparture;

  /// No description provided for @planRouteLate.
  ///
  /// In en, this message translates to:
  /// **'You will arrive after the next plan starts.'**
  String get planRouteLate;

  /// No description provided for @planRouteMissingLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose the origin and destination to search for a route.'**
  String get planRouteMissingLocation;

  /// No description provided for @planRouteOutsideGap.
  ///
  /// In en, this message translates to:
  /// **'Choose a departure between the end of this plan and the start of the next.'**
  String get planRouteOutsideGap;

  /// No description provided for @planRouteSave.
  ///
  /// In en, this message translates to:
  /// **'Add this route to plans'**
  String get planRouteSave;

  /// No description provided for @planRouteStale.
  ///
  /// In en, this message translates to:
  /// **'These plans have changed. Close this sheet and add the route again.'**
  String get planRouteStale;

  /// No description provided for @planRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'Travel plan'**
  String get planRouteTitle;

  /// No description provided for @planRouteSearch.
  ///
  /// In en, this message translates to:
  /// **'Find transit route'**
  String get planRouteSearch;

  /// No description provided for @categoryContest.
  ///
  /// In en, this message translates to:
  /// **'Contest'**
  String get categoryContest;

  /// No description provided for @applicationDeadline.
  ///
  /// In en, this message translates to:
  /// **'Application deadline'**
  String get applicationDeadline;

  /// No description provided for @eligibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get eligibilityLabel;

  /// No description provided for @eligibilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Check original eligibility'**
  String get eligibilityUnknown;

  /// No description provided for @verificationDelayed.
  ///
  /// In en, this message translates to:
  /// **'Update delayed · check application status at source'**
  String get verificationDelayed;

  /// No description provided for @verifiedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Last verified'**
  String get verifiedAtLabel;

  /// No description provided for @applicationOpen.
  ///
  /// In en, this message translates to:
  /// **'Applications open'**
  String get applicationOpen;

  /// No description provided for @applicationUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Applications upcoming'**
  String get applicationUpcoming;

  /// No description provided for @applicationClosed.
  ///
  /// In en, this message translates to:
  /// **'Applications closed'**
  String get applicationClosed;

  /// No description provided for @applicationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get applicationCancelled;

  /// No description provided for @applicationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Application status unconfirmed'**
  String get applicationUnknown;
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
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
