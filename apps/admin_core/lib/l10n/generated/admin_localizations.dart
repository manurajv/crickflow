import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'admin_localizations_ar.dart';
import 'admin_localizations_en.dart';
import 'admin_localizations_hi.dart';
import 'admin_localizations_si.dart';
import 'admin_localizations_ta.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AdminLocalizations
/// returned by `AdminLocalizations.of(context)`.
///
/// Applications need to include `AdminLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/admin_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AdminLocalizations.localizationsDelegates,
///   supportedLocales: AdminLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AdminLocalizations.supportedLocales
/// property.
abstract class AdminLocalizations {
  AdminLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AdminLocalizations of(BuildContext context) {
    return Localizations.of<AdminLocalizations>(context, AdminLocalizations)!;
  }

  static const LocalizationsDelegate<AdminLocalizations> delegate =
      _AdminLocalizationsDelegate();

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
    Locale('ar'),
    Locale('hi'),
    Locale('si'),
    Locale('ta'),
  ];

  /// No description provided for @appTitleAdmin.
  ///
  /// In en, this message translates to:
  /// **'CrickFlow Admin'**
  String get appTitleAdmin;

  /// No description provided for @appTitleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'CrickFlow Super Admin'**
  String get appTitleSuperAdmin;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'CrickFlow'**
  String get brandName;

  /// No description provided for @navSectionDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navSectionDashboard;

  /// No description provided for @navSectionManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get navSectionManagement;

  /// No description provided for @navSectionCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navSectionCommunity;

  /// No description provided for @navSectionPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get navSectionPlatform;

  /// No description provided for @navSectionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get navSectionSystem;

  /// No description provided for @navSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSectionSettings;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get navUsers;

  /// No description provided for @navOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get navOrganizations;

  /// No description provided for @navTeams.
  ///
  /// In en, this message translates to:
  /// **'Teams'**
  String get navTeams;

  /// No description provided for @navPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get navPlayers;

  /// No description provided for @navGrounds.
  ///
  /// In en, this message translates to:
  /// **'Grounds'**
  String get navGrounds;

  /// No description provided for @navMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get navMatches;

  /// No description provided for @navTournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get navTournaments;

  /// No description provided for @navBroadcasts.
  ///
  /// In en, this message translates to:
  /// **'Broadcasts'**
  String get navBroadcasts;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navAds.
  ///
  /// In en, this message translates to:
  /// **'Advertisements'**
  String get navAds;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get navSupport;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navCms.
  ///
  /// In en, this message translates to:
  /// **'CMS'**
  String get navCms;

  /// No description provided for @navAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get navAudit;

  /// No description provided for @navSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get navSecurity;

  /// No description provided for @navAiOps.
  ///
  /// In en, this message translates to:
  /// **'AI Center'**
  String get navAiOps;

  /// No description provided for @navMonitoring.
  ///
  /// In en, this message translates to:
  /// **'System Monitoring'**
  String get navMonitoring;

  /// No description provided for @navDevOps.
  ///
  /// In en, this message translates to:
  /// **'DevOps'**
  String get navDevOps;

  /// No description provided for @navContinuity.
  ///
  /// In en, this message translates to:
  /// **'Continuity & DR'**
  String get navContinuity;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get navRevenue;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get actionPrevious;

  /// No description provided for @actionLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get actionLogout;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionLogin;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionExpandNav.
  ///
  /// In en, this message translates to:
  /// **'Expand navigation'**
  String get actionExpandNav;

  /// No description provided for @actionCollapseNav.
  ///
  /// In en, this message translates to:
  /// **'Collapse navigation'**
  String get actionCollapseNav;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get commonSuccess;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get commonAccessDenied;

  /// No description provided for @commonForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this page'**
  String get commonForbidden;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get commonNoResults;

  /// No description provided for @commonNotificationsNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get commonNotificationsNone;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authRememberMe;

  /// No description provided for @authSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authSignInGoogle;

  /// No description provided for @authSignInEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email'**
  String get authSignInEmail;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get authResetSent;

  /// No description provided for @accountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account menu'**
  String get accountMenu;

  /// No description provided for @accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfile;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @accountLightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get accountLightMode;

  /// No description provided for @accountDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get accountDarkMode;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @accountRegional.
  ///
  /// In en, this message translates to:
  /// **'Regional settings'**
  String get accountRegional;

  /// No description provided for @accountTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get accountTimezone;

  /// No description provided for @accountDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get accountDateFormat;

  /// No description provided for @accountTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Time format'**
  String get accountTimeFormat;

  /// No description provided for @accountNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get accountNumberFormat;

  /// No description provided for @accountLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System / Browser'**
  String get accountLanguageSystem;

  /// No description provided for @accountLanguageSaved.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get accountLanguageSaved;

  /// No description provided for @breadcrumbDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get breadcrumbDashboard;

  /// No description provided for @a11ySkipToContent.
  ///
  /// In en, this message translates to:
  /// **'Skip to main content'**
  String get a11ySkipToContent;

  /// No description provided for @a11yMainNavigation.
  ///
  /// In en, this message translates to:
  /// **'Main navigation'**
  String get a11yMainNavigation;

  /// No description provided for @a11ySearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get a11ySearch;

  /// No description provided for @a11yCloseDialog.
  ///
  /// In en, this message translates to:
  /// **'Close dialog'**
  String get a11yCloseDialog;

  /// No description provided for @a11yOpenFilters.
  ///
  /// In en, this message translates to:
  /// **'Open filters'**
  String get a11yOpenFilters;

  /// No description provided for @a11yTable.
  ///
  /// In en, this message translates to:
  /// **'Data table'**
  String get a11yTable;

  /// No description provided for @a11yChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get a11yChart;

  /// No description provided for @a11yLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading content'**
  String get a11yLoading;

  /// No description provided for @a11ySelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get a11ySelected;

  /// No description provided for @a11yRowActions.
  ///
  /// In en, this message translates to:
  /// **'Row actions'**
  String get a11yRowActions;

  /// No description provided for @errorsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection and try again.'**
  String get errorsNetwork;

  /// No description provided for @errorsTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get errorsTimeout;

  /// No description provided for @errorsPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get errorsPermission;

  /// No description provided for @errorsUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorsUnexpected;

  /// No description provided for @errorsAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please sign in again.'**
  String get errorsAuth;

  /// No description provided for @timezoneUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get timezoneUtc;

  /// No description provided for @timezoneBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser time'**
  String get timezoneBrowser;

  /// No description provided for @timezonePreferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred time zone'**
  String get timezonePreferred;

  /// No description provided for @timezoneOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization time zone'**
  String get timezoneOrganization;

  /// No description provided for @timeFormat12h.
  ///
  /// In en, this message translates to:
  /// **'12-hour'**
  String get timeFormat12h;

  /// No description provided for @timeFormat24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour'**
  String get timeFormat24h;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filterTitle;

  /// No description provided for @paginationPage.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String paginationPage(int page);

  /// No description provided for @paginationOf.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String paginationOf(int total);
}

class _AdminLocalizationsDelegate
    extends LocalizationsDelegate<AdminLocalizations> {
  const _AdminLocalizationsDelegate();

  @override
  Future<AdminLocalizations> load(Locale locale) {
    return SynchronousFuture<AdminLocalizations>(
      lookupAdminLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'hi', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AdminLocalizationsDelegate old) => false;
}

AdminLocalizations lookupAdminLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AdminLocalizationsAr();
    case 'en':
      return AdminLocalizationsEn();
    case 'hi':
      return AdminLocalizationsHi();
    case 'si':
      return AdminLocalizationsSi();
    case 'ta':
      return AdminLocalizationsTa();
  }

  throw FlutterError(
    'AdminLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
