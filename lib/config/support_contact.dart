/// Public CrickFlow Help contact details (shown in the app and on the website).
class SupportContact {
  SupportContact._();

  static const List<String> emails = [
    'mavixas.ceo@gmail.com',
    'crickflow.app@gmail.com',
  ];

  /// E.164 as provided for tel: / WhatsApp links.
  static const String phoneE164 = '+94701036188';

  /// Display form of [phoneE164].
  static const String phoneDisplay = '+94 70 103 6188';

  static const String whatsappUrl = 'https://wa.me/94701036188';

  static String mailto(String email) => 'mailto:$email';

  static const String tel = 'tel:+94701036188';
}
