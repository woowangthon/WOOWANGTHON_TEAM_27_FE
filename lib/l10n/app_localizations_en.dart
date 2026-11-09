// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LifeRadar';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMap => 'Map';

  @override
  String get tabPlans => 'My Plans';

  @override
  String get tabDiscover => 'Discover';

  @override
  String get homeGreeting => 'Signals for you';

  @override
  String get homeSubtitle => 'What changed around your plans and interests';

  @override
  String get whyItMatters => 'Why it matters';

  @override
  String get aiWritten => 'Written with Gemini';

  @override
  String get errOffline =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errBusy =>
      'The service is busy right now. Please try again in a minute.';

  @override
  String get errService => 'This service isn\'t available right now.';

  @override
  String get errNoRoute => 'Couldn\'t find a route between these places.';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String eventsUpdated(int count, String date) {
    return 'Real public data · $count events · updated $date';
  }

  @override
  String get notifyDeniedApp =>
      'Notifications are blocked. Turn on notifications for LifeRadar in Settings, then try again.';

  @override
  String planLinkNearby(String km) {
    return '$km km from your plan · while you\'re there';
  }

  @override
  String planLinkCrowd(String km) {
    return 'Same day · $km km away';
  }

  @override
  String get planLinkTraffic =>
      'Before your plan starts · official road control';

  @override
  String get planLinkStrike => 'Same day · news report (for reference)';

  @override
  String get sources => 'Sources';

  @override
  String confidence(int percent) {
    return 'Confidence $percent%';
  }

  @override
  String get showOnMap => 'Show on map';

  @override
  String get feedbackThanks => 'Thanks! We\'ll tune your signals.';

  @override
  String get layerPlans => 'My Plans';

  @override
  String get layerRecommended => 'Recommended';

  @override
  String get layerRoute => 'Route';

  @override
  String get modeExplore => 'Explore';

  @override
  String get modeMyMap => 'My Map';

  @override
  String get modeRoute => 'Route';

  @override
  String get mapKeyMissing =>
      'Kakao Map key is missing.\nRun with --dart-define-from-file=env.json';

  @override
  String mapError(String message) {
    return 'Map failed to load: $message';
  }

  @override
  String get plansEmpty =>
      'No upcoming plans yet. Connect Google Calendar to import them.';

  @override
  String get connectCalendar => 'Connect Google Calendar';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get discoverAll => 'All';

  @override
  String get whyForYou => 'Why for you';

  @override
  String get register => 'Register';

  @override
  String get addToCalendar => 'Add to calendar';

  @override
  String get noRegisterLink => 'No registration link yet';

  @override
  String get sampleData => 'Sample data';

  @override
  String matchesInterests(String tags) {
    return 'Matches your interests: $tags';
  }

  @override
  String get language => 'Language';

  @override
  String get categoryConference => 'Conference';

  @override
  String get categoryHackathon => 'Hackathon';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryMeetup => 'Meetup';

  @override
  String get categoryJob => 'Job';

  @override
  String get categoryScholarship => 'Scholarship';

  @override
  String mapSdkNotLoaded(String origin) {
    return 'Kakao Map SDK did not load.\nRegister this address as a Web domain in Kakao Developers:\n$origin';
  }

  @override
  String get routeFrom => 'From';

  @override
  String get routeTo => 'To';

  @override
  String get routeDate => 'Date';

  @override
  String get routeFind => 'Find opportunities';

  @override
  String get routeDemo => 'Demo: Seoul St. → Busan St.';

  @override
  String get routeSearchHint => 'Search a place (e.g. 부산역, BEXCO)';

  @override
  String get routeNoResults => 'No places found';

  @override
  String routeSummary(String distance, String duration) {
    return '$distance km · $duration by car';
  }

  @override
  String routeAlongTheWay(int count) {
    return 'Along the way ($count)';
  }

  @override
  String get routeNoOpportunities =>
      'No matching events within 15 km of this route on that day.';

  @override
  String routeDetour(String km, int minutes) {
    return '+$km km · +$minutes min';
  }

  @override
  String routeFromRoute(String km) {
    return '$km km from route';
  }

  @override
  String routeError(String message) {
    return 'Route failed: $message';
  }

  @override
  String get onYourWay => 'On your way';

  @override
  String hoursMinutes(int h, int m) {
    return '${h}h ${m}m';
  }

  @override
  String get travelCar => 'Car';

  @override
  String get travelTransit => 'Transit';

  @override
  String routeSummaryTransit(String distance, String duration, String lines) {
    return '$distance km · $duration · $lines';
  }

  @override
  String get calendarConnecting => 'Connecting to Google…';

  @override
  String get calendarSyncing => 'Syncing calendar…';

  @override
  String calendarConnectedCount(int count) {
    return 'Google Calendar · $count upcoming plans';
  }

  @override
  String get calendarSync => 'Sync';

  @override
  String get calendarDisconnect => 'Disconnect';

  @override
  String get calendarExpired => 'Google session expired. Please connect again.';

  @override
  String get calendarNotConfigured =>
      'Google sign-in isn\'t set up on this platform yet (web only for now).';

  @override
  String calendarError(String message) {
    return 'Calendar error: $message';
  }

  @override
  String get calendarPrivacy =>
      'LifeRadar only reads upcoming events and adds events you choose. Disconnect anytime.';

  @override
  String get noLocation => 'No location';

  @override
  String get sourceCalendar => 'Google Calendar';

  @override
  String get addedToCalendar => 'Added to Google Calendar';

  @override
  String get addingToCalendar => 'Adding…';

  @override
  String get weatherLater => 'Forecast appears ~10 days before';

  @override
  String get onboardingTagline =>
      'Finds the opportunities around your plans — before you search.';

  @override
  String get onboardingTitle => 'What are you into?';

  @override
  String get onboardingSubtitle =>
      'Pick a few. LifeRadar ranks events and route suggestions by these.';

  @override
  String get onboardingPickOne => 'Pick at least one';

  @override
  String onboardingContinue(int count) {
    return 'Continue ($count selected)';
  }

  @override
  String get onboardingPrivacy =>
      'Saved only on this device. You can change it anytime.';

  @override
  String get interestsEdit => 'My interests';

  @override
  String get save => 'Save';

  @override
  String get homeEmptyTitle => 'No signals yet';

  @override
  String get homeEmptyBody =>
      'Connect your calendar or add more interests — LifeRadar will connect your plans with events and weather.';

  @override
  String get tabProfile => 'Profile';

  @override
  String get loginError => 'Google sign-in failed. Please try again.';

  @override
  String get or => 'or';

  @override
  String get continueAsGuest => 'Look around as a guest';

  @override
  String get loginPrivacy =>
      'Your calendar is connected separately, only with your consent.';

  @override
  String get guestName => 'Guest';

  @override
  String get guestSubtitle => 'Sign in to use your own account';

  @override
  String get signIn => 'Sign in';

  @override
  String get edit => 'Edit';

  @override
  String get ok => 'OK';

  @override
  String get sectionConnections => 'Connected services';

  @override
  String get connected => 'Connected';

  @override
  String get notConnected => 'Not connected';

  @override
  String get connect => 'Connect';

  @override
  String get sectionSettings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionAbout => 'About';

  @override
  String get privacy => 'Privacy';

  @override
  String get version => 'Version';

  @override
  String get logout => 'Sign out';

  @override
  String get exitGuest => 'Back to start';

  @override
  String get homeHello => 'Hello';

  @override
  String homeHelloName(String name) {
    return 'Hi, $name';
  }

  @override
  String get statPlans => 'Plans';

  @override
  String get statSignals => 'Signals';

  @override
  String get statDeadlines => 'Deadlines';

  @override
  String get kindPlanAlert => 'Plan alert';

  @override
  String get kindOpportunity => 'Opportunity';

  @override
  String get kindDeadline => 'Deadline';

  @override
  String get kindRoute => 'Route';

  @override
  String get helpful => 'Helpful';

  @override
  String get notForMe => 'Not for me';

  @override
  String get hide => 'Hide';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get discoverSubtitle => 'Sorted by how well they match your interests';

  @override
  String get matchBadge => 'Match';

  @override
  String get eventDetails => 'Details';

  @override
  String get openSource => 'Source';

  @override
  String get searching => 'Searching…';

  @override
  String get rainChance => 'Rain';

  @override
  String get showLess => 'Show less';

  @override
  String get planNew => 'New plan';

  @override
  String get planEdit => 'Edit plan';

  @override
  String get planTitle => 'Title';

  @override
  String get planTitleHint => 'e.g. Busan business trip';

  @override
  String get planTitleRequired => 'Enter a title';

  @override
  String get planDate => 'Date';

  @override
  String get planStart => 'Starts';

  @override
  String get planEnd => 'Ends';

  @override
  String get planAllDay => 'All day';

  @override
  String get planLocation => 'Location';

  @override
  String get planLocationAdd => 'Add a place';

  @override
  String get planLocationRemove => 'Remove place';

  @override
  String get planNote => 'Note';

  @override
  String get planNoteHint => 'Anything to remember';

  @override
  String get planSaveToCalendar => 'Also save to Google Calendar';

  @override
  String get planCalendarSynced =>
      'Changes are saved to your Google Calendar too.';

  @override
  String get planSampleHint => 'Sample plan — saving makes it your own plan.';

  @override
  String get planDelete => 'Delete plan';

  @override
  String planDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get planSaved => 'Plan saved';

  @override
  String get planDeleted => 'Plan deleted';

  @override
  String get planEndBeforeStart => 'End time must be after the start';

  @override
  String planSaveError(String message) {
    return 'Couldn\'t save: $message';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get openInCalendar => 'Open in Google Calendar';

  @override
  String get plansEmptyAdd =>
      'Add your first plan, or connect Google Calendar to import them.';

  @override
  String interestsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get categoryPerformance => 'Theater & musicals';

  @override
  String get categoryExhibition => 'Exhibition';

  @override
  String get categoryClasses => 'Classes';

  @override
  String get free => 'Free';

  @override
  String dataSource(String name) {
    return 'Data: $name';
  }

  @override
  String get showMore => 'Show more';

  @override
  String get realData => 'Live data';

  @override
  String get ongoing => 'Ongoing';

  @override
  String get categoryStartupSupport => 'Startup programs';

  @override
  String applicationPeriod(String from, String to) {
    return 'Applications $from – $to';
  }

  @override
  String get nationwide => 'Nationwide';

  @override
  String get applyNow => 'Apply';

  @override
  String get aiTranslated => 'Translated from Korean with Gemini';

  @override
  String get statForPlans => 'My plans';

  @override
  String get statAll => 'All signals';

  @override
  String get statSoon => 'Due soon';

  @override
  String get homeSectionPlans => 'Around your plans';

  @override
  String get homeSectionDeadlines => 'Deadlines coming up';

  @override
  String get homeFilterEmpty => 'Nothing here right now';

  @override
  String get dislikeConfirmTitle => 'Not for you?';

  @override
  String get dislikeConfirmBody => 'We\'ll show fewer signals like this one.';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get feedbackLiked => 'Thanks! You\'ll see more like this';

  @override
  String get feedbackDisliked => 'Got it — fewer signals like this';

  @override
  String untilDate(String date) {
    return 'Until $date';
  }

  @override
  String get openEvent => 'Event details';

  @override
  String get signalWhy => 'Why this signal';

  @override
  String get calendarAddFailed => 'Couldn\'t add to calendar';

  @override
  String interestsCount(int count) {
    return '$count selected';
  }

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get getStarted => 'Get started';

  @override
  String get themeTitle => 'Pick a look';

  @override
  String get themeSubtitle => 'You can change this anytime in Profile.';

  @override
  String get themeSystemDesc => 'Follows your device';

  @override
  String get themeLightDesc => 'Bright and clear';

  @override
  String get themeDarkDesc => 'Easy on the eyes at night';

  @override
  String get nameTitle => 'What should we call you?';

  @override
  String get nameSubtitle =>
      'We\'ll greet you with this on the home screen. You can change it later in Profile.';

  @override
  String get nameHint => 'Your name';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get editName => 'Edit name';

  @override
  String stepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get welcomeTagline => 'Signals from your plans and interests';

  @override
  String get loginF1Title => 'Plans meet the world';

  @override
  String get loginF1Body => 'Calendar × events × weather × deadlines';

  @override
  String get loginF2Title => 'Opportunities on your way';

  @override
  String get loginF2Body => 'KTX or car — see the detour in km and minutes';

  @override
  String get loginF3Title => 'Know why it matters';

  @override
  String get loginF3Body => 'Every signal comes with reasons and sources';

  @override
  String get loginPanelTitle => 'Let\'s get started';

  @override
  String get loginPanelBody =>
      'Your Google account is all you need — no extra sign-up.';

  @override
  String get myLocation => 'My location';

  @override
  String get locationDenied =>
      'Location is blocked. Allow it in your browser or device settings.';

  @override
  String get locationUnavailable => 'Couldn\'t get your location right now.';

  @override
  String get planViewMonth => 'Month view';

  @override
  String get planViewList => 'List view';

  @override
  String get noPlansThisDay => 'No plans on this day';

  @override
  String get planSignalRain => 'Rain likely — bring an umbrella';

  @override
  String planSignalCrowd(String event) {
    return '$event nearby — expect crowds';
  }

  @override
  String planSignalNearby(String event) {
    return 'Nearby: $event';
  }

  @override
  String get planAround => 'Around this plan';

  @override
  String get planNothingAround => 'Nothing unusual around this plan right now.';

  @override
  String get myPlanBadge => 'My plan';

  @override
  String get calendarOpenGoogle => 'Open Google Calendar';

  @override
  String get planWhen => 'When';

  @override
  String get planWhere => 'Where';

  @override
  String get likeUndoTitle => 'Remove your like?';

  @override
  String get likeUndoBody => 'This signal will be ranked like any other again.';

  @override
  String get dislikeUndoTitle => 'Show signals like this again?';

  @override
  String get dislikeUndoBody => 'We\'ll stop pushing this one down.';

  @override
  String get removeLike => 'Remove like';

  @override
  String get showAgain => 'Show again';

  @override
  String get keep => 'Keep';

  @override
  String get notForMeConfirm => 'Not for me';

  @override
  String get feedbackCleared => 'Feedback removed';

  @override
  String get notifications => 'Notifications';

  @override
  String get notifyDesc =>
      'Deadlines, plan alerts and rain — as system notifications';

  @override
  String get notifyUnsupported => 'Not available on this device yet';

  @override
  String get notifyDenied =>
      'Notifications are blocked. Allow them in your browser settings.';

  @override
  String get notifyOn => 'Notifications on';

  @override
  String get notifyTest => 'Send a test notification';

  @override
  String get notifyTestBody =>
      'Notifications are working. We\'ll tell you when something affects your plans.';

  @override
  String get accountData => 'Account & data';

  @override
  String get accountDataSubtitle =>
      'Delete your account and everything stored on this device';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your name, interests, your own plans, feedback and settings will be erased from this device, Google access will be revoked, and the app will start over from the beginning. This can\'t be undone.';

  @override
  String get deleteAccountInfo =>
      'LifeRadar keeps your data only on this device. Deleting removes it all and disconnects Google Calendar.';

  @override
  String get accountDeleted => 'Account deleted. Starting fresh.';

  @override
  String get eventAbout => 'About';

  @override
  String get eventPrice => 'Price';

  @override
  String get applicationLabel => 'Applications';

  @override
  String get organizer => 'Organizer';

  @override
  String get matchesYou => 'Matches your interests';

  @override
  String get routePanelHint => 'Pull down to see more of the map';

  @override
  String get routePanelExpand => 'Expand route panel';

  @override
  String get routePanelCollapse => 'Lower route panel';

  @override
  String get filterMine => 'My interests';

  @override
  String get discoverSearchHint => 'Search events or places';

  @override
  String get filterPeriod => 'When';

  @override
  String get filterAnyTime => 'Any time';

  @override
  String get periodToday => 'Today';

  @override
  String get periodWeekend => 'This weekend';

  @override
  String get periodWeek => 'Next 7 days';

  @override
  String get periodMonth => 'Next month';

  @override
  String get filterRegion => 'Region';

  @override
  String get filterAllRegions => 'All regions';

  @override
  String get sortMatch => 'Best match';

  @override
  String get sortSoon => 'Soonest';

  @override
  String get discoverPicks => 'Picked for your interests';

  @override
  String discoverResults(int count) {
    return '$count events';
  }

  @override
  String get filterReset => 'Reset';

  @override
  String get discoverNoResults => 'No events match these filters';

  @override
  String get routeEdit => 'Edit';

  @override
  String get stageTitle => 'What\'s your situation right now?';

  @override
  String get stageOptional =>
      'Optional · we\'ll show fitting programs and events first';

  @override
  String get aboutMeCta => 'Tell the AI about yourself';

  @override
  String get aboutMeCtaBody =>
      'Write a few sentences and we\'ll suggest your situation and interests. You choose.';

  @override
  String get aboutMeTitle => 'About me';

  @override
  String get aboutMeGreeting =>
      'Tell me a bit about yourself — what you do, what you\'re into lately, what you do on weekends. Anything works.';

  @override
  String get aboutMeEx1 =>
      'I\'m a 3rd-year CS student. Studying AI and I\'d like to try a hackathon.';

  @override
  String get aboutMeEx2 =>
      'I work at a marketing company. I run after work and visit exhibitions on weekends.';

  @override
  String get aboutMeEx3 =>
      'I\'m preparing a startup. I need info on investor sessions and startup support programs.';

  @override
  String get aboutMeHint => 'Write about yourself';

  @override
  String get aboutMeSend => 'Send';

  @override
  String get aboutMeThinking => 'Reading…';

  @override
  String get aboutMeUnderstood => 'Here\'s what I understood. Keep what fits.';

  @override
  String get aboutMeKeyword =>
      'Matched by keywords (AI not connected). Keep what fits.';

  @override
  String get aboutMeNothing =>
      'I\'m not sure yet. Tell me a little more about what you do or enjoy.';

  @override
  String aboutMeStage(String stage) {
    return 'Situation: $stage';
  }

  @override
  String aboutMeApply(int count) {
    return 'Apply ($count)';
  }

  @override
  String aboutMeApplied(int count) {
    return 'Added $count interests';
  }

  @override
  String get aboutMeAiBadge => 'AI suggestion';

  @override
  String get aboutMePrivacy =>
      'Your text is sent to Google Gemini only to make suggestions, and saved on this device only.';

  @override
  String get share => 'Share';

  @override
  String get shareFooter => 'Found on LifeRadar';

  @override
  String get shareCopied => 'Copied to share';

  @override
  String get planDeleteCalendarNote =>
      'It will also be removed from Google Calendar.';

  @override
  String get assistantButton => 'Ask AI';

  @override
  String get assistantTitle => 'LifeRadar AI';

  @override
  String get assistantSubtitle => 'Answers from your plans and real data';

  @override
  String get assistantNewChat => 'New chat';

  @override
  String get assistantHello => 'What can I find for you?';

  @override
  String get assistantHelloBody =>
      'I look at your plans, interests and real public data.\nI only add things to your calendar after you confirm.';

  @override
  String get assistantSuggestWeekend => 'What should I do this weekend?';

  @override
  String assistantSuggestPlan(String plan) {
    return 'Anything worth visiting during $plan?';
  }

  @override
  String get assistantSuggestDeadline => 'Any deadlines coming up?';

  @override
  String get assistantSuggestFree => 'Recommend a free exhibition';

  @override
  String get assistantTrust =>
      'Code picks candidates from real data; the AI only answers from them';

  @override
  String get assistantThinking => 'Looking through your plans and events…';

  @override
  String get assistantAiBadge => 'AI answer';

  @override
  String get assistantRuleBadge => 'Filter search';

  @override
  String get assistantRuleNote =>
      'AI isn\'t connected, so these are filter results.';

  @override
  String get assistantHint => 'Ask me anything';

  @override
  String get assistantFooter =>
      'The AI only suggests. You confirm every change.';

  @override
  String get assistantProposeCalendar => 'Add to your calendar?';

  @override
  String get assistantProposeMap => 'See it on the map?';

  @override
  String get assistantAdd => 'Add';

  @override
  String get assistantOpen => 'Open';

  @override
  String get assistantAdded => 'Added';

  @override
  String get assistantOpened => 'Opened';

  @override
  String get assistantCancelled => 'Cancelled';

  @override
  String get retry => 'Try again';
}
