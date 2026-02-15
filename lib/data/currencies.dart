// Organised currency data for the smart currency picker.
// Full ISO 4217 coverage with country-name search support.

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final List<String> countries;

  const CurrencyInfo(
    this.code,
    this.name, [
    this.symbol = '',
    this.countries = const [],
  ]);

  /// Returns true if this currency matches [query] by code, name, or country.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toUpperCase();
    if (code.contains(q)) return true;
    if (name.toUpperCase().contains(q)) return true;
    for (final c in countries) {
      if (c.toUpperCase().contains(q)) return true;
    }
    return false;
  }
}

/// Top 10 world currencies by trading volume.
const kTopCurrencyCodes = [
  'USD', 'EUR', 'GBP', 'JPY', 'CNY',
  'AUD', 'CAD', 'CHF', 'HKD', 'SGD',
];

/// Gulf & Middle-East currencies.
const kGulfCurrencyCodes = [
  'OMR', 'AED', 'SAR', 'BHD', 'KWD', 'QAR', 'EGP', 'JOD', 'MAD',
];

/// Full currency catalogue with country search keywords.
const List<CurrencyInfo> kAllCurrencies = [
  // ═══════════════════════════════════════════════
  //  Top 10
  // ═══════════════════════════════════════════════
  CurrencyInfo('USD', 'US Dollar', '\$', ['United States', 'America', 'USA']),
  CurrencyInfo('EUR', 'Euro', '€', ['Europe', 'Germany', 'France', 'Italy', 'Spain', 'Netherlands', 'Belgium', 'Austria', 'Portugal', 'Ireland', 'Finland', 'Greece', 'Slovakia', 'Slovenia', 'Estonia', 'Latvia', 'Lithuania', 'Luxembourg', 'Malta', 'Cyprus', 'Croatia']),
  CurrencyInfo('GBP', 'British Pound', '£', ['United Kingdom', 'Britain', 'England', 'Scotland', 'Wales']),
  CurrencyInfo('JPY', 'Japanese Yen', '¥', ['Japan']),
  CurrencyInfo('CNY', 'Chinese Yuan', '¥', ['China']),
  CurrencyInfo('AUD', 'Australian Dollar', 'A\$', ['Australia']),
  CurrencyInfo('CAD', 'Canadian Dollar', 'C\$', ['Canada']),
  CurrencyInfo('CHF', 'Swiss Franc', 'Fr', ['Switzerland', 'Liechtenstein']),
  CurrencyInfo('HKD', 'Hong Kong Dollar', 'HK\$', ['Hong Kong']),
  CurrencyInfo('SGD', 'Singapore Dollar', 'S\$', ['Singapore']),

  // ═══════════════════════════════════════════════
  //  Gulf & MENA
  // ═══════════════════════════════════════════════
  CurrencyInfo('OMR', 'Omani Rial', 'ر.ع.', ['Oman']),
  CurrencyInfo('AED', 'UAE Dirham', 'د.إ', ['United Arab Emirates', 'UAE', 'Dubai', 'Abu Dhabi']),
  CurrencyInfo('SAR', 'Saudi Riyal', 'ر.س', ['Saudi Arabia']),
  CurrencyInfo('BHD', 'Bahraini Dinar', 'BD', ['Bahrain']),
  CurrencyInfo('KWD', 'Kuwaiti Dinar', 'KD', ['Kuwait']),
  CurrencyInfo('QAR', 'Qatari Riyal', 'ر.ق', ['Qatar']),
  CurrencyInfo('EGP', 'Egyptian Pound', 'E£', ['Egypt']),
  CurrencyInfo('JOD', 'Jordanian Dinar', 'JD', ['Jordan']),
  CurrencyInfo('MAD', 'Moroccan Dirham', 'MAD', ['Morocco']),
  CurrencyInfo('TND', 'Tunisian Dinar', 'DT', ['Tunisia']),
  CurrencyInfo('LBP', 'Lebanese Pound', 'LL', ['Lebanon']),
  CurrencyInfo('IQD', 'Iraqi Dinar', 'IQD', ['Iraq']),
  CurrencyInfo('LYD', 'Libyan Dinar', 'LYD', ['Libya']),
  CurrencyInfo('DZD', 'Algerian Dinar', 'د.ج', ['Algeria']),
  CurrencyInfo('SDG', 'Sudanese Pound', 'SDG', ['Sudan']),
  CurrencyInfo('SYP', 'Syrian Pound', 'S£', ['Syria']),
  CurrencyInfo('YER', 'Yemeni Rial', 'YER', ['Yemen']),
  CurrencyInfo('IRR', 'Iranian Rial', 'IRR', ['Iran']),

  // ═══════════════════════════════════════════════
  //  Asia
  // ═══════════════════════════════════════════════
  CurrencyInfo('INR', 'Indian Rupee', '₹', ['India']),
  CurrencyInfo('PKR', 'Pakistani Rupee', '₨', ['Pakistan']),
  CurrencyInfo('BDT', 'Bangladeshi Taka', '৳', ['Bangladesh']),
  CurrencyInfo('LKR', 'Sri Lankan Rupee', 'Rs', ['Sri Lanka']),
  CurrencyInfo('THB', 'Thai Baht', '฿', ['Thailand']),
  CurrencyInfo('MYR', 'Malaysian Ringgit', 'RM', ['Malaysia']),
  CurrencyInfo('IDR', 'Indonesian Rupiah', 'Rp', ['Indonesia']),
  CurrencyInfo('PHP', 'Philippine Peso', '₱', ['Philippines']),
  CurrencyInfo('VND', 'Vietnamese Dong', '₫', ['Vietnam']),
  CurrencyInfo('KRW', 'South Korean Won', '₩', ['South Korea', 'Korea']),
  CurrencyInfo('TWD', 'Taiwan Dollar', 'NT\$', ['Taiwan']),
  CurrencyInfo('MMK', 'Myanmar Kyat', 'K', ['Myanmar', 'Burma']),
  CurrencyInfo('KHR', 'Cambodian Riel', '៛', ['Cambodia']),
  CurrencyInfo('NPR', 'Nepalese Rupee', 'Rs', ['Nepal']),
  CurrencyInfo('AFN', 'Afghan Afghani', '؋', ['Afghanistan']),
  CurrencyInfo('UZS', 'Uzbekistani Som', 'UZS', ['Uzbekistan']),
  CurrencyInfo('KZT', 'Kazakhstani Tenge', '₸', ['Kazakhstan']),
  CurrencyInfo('KGS', 'Kyrgyzstani Som', 'KGS', ['Kyrgyzstan']),
  CurrencyInfo('TJS', 'Tajikistani Somoni', 'TJS', ['Tajikistan']),
  CurrencyInfo('TMT', 'Turkmenistani Manat', 'TMT', ['Turkmenistan']),
  CurrencyInfo('MNT', 'Mongolian Tugrik', '₮', ['Mongolia']),
  CurrencyInfo('LAK', 'Lao Kip', '₭', ['Laos']),
  CurrencyInfo('BND', 'Brunei Dollar', 'B\$', ['Brunei']),
  CurrencyInfo('MVR', 'Maldivian Rufiyaa', 'Rf', ['Maldives']),
  CurrencyInfo('BTN', 'Bhutanese Ngultrum', 'Nu', ['Bhutan']),

  // ═══════════════════════════════════════════════
  //  Europe
  // ═══════════════════════════════════════════════
  CurrencyInfo('SEK', 'Swedish Krona', 'kr', ['Sweden']),
  CurrencyInfo('NOK', 'Norwegian Krone', 'kr', ['Norway']),
  CurrencyInfo('DKK', 'Danish Krone', 'kr', ['Denmark']),
  CurrencyInfo('PLN', 'Polish Zloty', 'zł', ['Poland']),
  CurrencyInfo('CZK', 'Czech Koruna', 'Kč', ['Czech Republic', 'Czechia']),
  CurrencyInfo('HUF', 'Hungarian Forint', 'Ft', ['Hungary']),
  CurrencyInfo('RON', 'Romanian Leu', 'lei', ['Romania']),
  CurrencyInfo('BGN', 'Bulgarian Lev', 'лв', ['Bulgaria']),
  CurrencyInfo('HRK', 'Croatian Kuna', 'kn', ['Croatia']),
  CurrencyInfo('ISK', 'Icelandic Króna', 'kr', ['Iceland']),
  CurrencyInfo('RUB', 'Russian Ruble', '₽', ['Russia']),
  CurrencyInfo('UAH', 'Ukrainian Hryvnia', '₴', ['Ukraine']),
  CurrencyInfo('TRY', 'Turkish Lira', '₺', ['Turkey', 'Türkiye']),
  CurrencyInfo('GEL', 'Georgian Lari', '₾', ['Georgia']),
  CurrencyInfo('AZN', 'Azerbaijani Manat', '₼', ['Azerbaijan']),
  CurrencyInfo('RSD', 'Serbian Dinar', 'din', ['Serbia']),
  CurrencyInfo('ALL', 'Albanian Lek', 'L', ['Albania']),
  CurrencyInfo('MKD', 'Macedonian Denar', 'ден', ['North Macedonia', 'Macedonia']),
  CurrencyInfo('BAM', 'Bosnian Mark', 'KM', ['Bosnia', 'Herzegovina']),
  CurrencyInfo('MDL', 'Moldovan Leu', 'MDL', ['Moldova']),
  CurrencyInfo('AMD', 'Armenian Dram', '֏', ['Armenia']),
  CurrencyInfo('BYN', 'Belarusian Ruble', 'Br', ['Belarus']),

  // ═══════════════════════════════════════════════
  //  Africa
  // ═══════════════════════════════════════════════
  CurrencyInfo('ZAR', 'South African Rand', 'R', ['South Africa']),
  CurrencyInfo('NGN', 'Nigerian Naira', '₦', ['Nigeria']),
  CurrencyInfo('KES', 'Kenyan Shilling', 'KSh', ['Kenya']),
  CurrencyInfo('GHS', 'Ghanaian Cedi', 'GH₵', ['Ghana']),
  CurrencyInfo('TZS', 'Tanzanian Shilling', 'TSh', ['Tanzania']),
  CurrencyInfo('UGX', 'Ugandan Shilling', 'USh', ['Uganda']),
  CurrencyInfo('ETB', 'Ethiopian Birr', 'Br', ['Ethiopia']),
  CurrencyInfo('XOF', 'West African CFA', 'CFA', ['Senegal', 'Mali', 'Burkina Faso', 'Ivory Coast', 'Niger', 'Togo', 'Benin', 'Guinea-Bissau']),
  CurrencyInfo('XAF', 'Central African CFA', 'FCFA', ['Cameroon', 'Chad', 'Congo', 'Gabon', 'Equatorial Guinea', 'Central African Republic']),
  CurrencyInfo('MUR', 'Mauritian Rupee', '₨', ['Mauritius']),
  CurrencyInfo('RWF', 'Rwandan Franc', 'RF', ['Rwanda']),
  CurrencyInfo('AOA', 'Angolan Kwanza', 'Kz', ['Angola']),
  CurrencyInfo('MZN', 'Mozambican Metical', 'MT', ['Mozambique']),
  CurrencyInfo('ZMW', 'Zambian Kwacha', 'ZK', ['Zambia']),
  CurrencyInfo('MWK', 'Malawian Kwacha', 'MK', ['Malawi']),
  CurrencyInfo('BWP', 'Botswana Pula', 'P', ['Botswana']),
  CurrencyInfo('NAD', 'Namibian Dollar', 'N\$', ['Namibia']),
  CurrencyInfo('SZL', 'Swazi Lilangeni', 'E', ['Eswatini', 'Swaziland']),
  CurrencyInfo('LSL', 'Lesotho Loti', 'L', ['Lesotho']),
  CurrencyInfo('GMD', 'Gambian Dalasi', 'D', ['Gambia']),
  CurrencyInfo('SLL', 'Sierra Leonean Leone', 'Le', ['Sierra Leone']),
  CurrencyInfo('GNF', 'Guinean Franc', 'FG', ['Guinea']),
  CurrencyInfo('CDF', 'Congolese Franc', 'FC', ['DR Congo', 'Democratic Republic of Congo']),
  CurrencyInfo('BIF', 'Burundian Franc', 'FBu', ['Burundi']),
  CurrencyInfo('DJF', 'Djiboutian Franc', 'Fdj', ['Djibouti']),
  CurrencyInfo('ERN', 'Eritrean Nakfa', 'Nfk', ['Eritrea']),
  CurrencyInfo('SOS', 'Somali Shilling', 'Sh', ['Somalia']),
  CurrencyInfo('MGA', 'Malagasy Ariary', 'Ar', ['Madagascar']),
  CurrencyInfo('SCR', 'Seychellois Rupee', '₨', ['Seychelles']),
  CurrencyInfo('CVE', 'Cape Verdean Escudo', 'Esc', ['Cape Verde', 'Cabo Verde']),
  CurrencyInfo('STN', 'São Tomé Dobra', 'Db', ['São Tomé', 'Sao Tome']),
  CurrencyInfo('KMF', 'Comorian Franc', 'CF', ['Comoros']),
  CurrencyInfo('MRU', 'Mauritanian Ouguiya', 'UM', ['Mauritania']),
  CurrencyInfo('LRD', 'Liberian Dollar', 'L\$', ['Liberia']),

  // ═══════════════════════════════════════════════
  //  Americas
  // ═══════════════════════════════════════════════
  CurrencyInfo('BRL', 'Brazilian Real', 'R\$', ['Brazil']),
  CurrencyInfo('MXN', 'Mexican Peso', 'Mex\$', ['Mexico']),
  CurrencyInfo('ARS', 'Argentine Peso', 'AR\$', ['Argentina']),
  CurrencyInfo('CLP', 'Chilean Peso', 'CL\$', ['Chile']),
  CurrencyInfo('COP', 'Colombian Peso', 'CO\$', ['Colombia']),
  CurrencyInfo('PEN', 'Peruvian Sol', 'S/.', ['Peru']),
  CurrencyInfo('UYU', 'Uruguayan Peso', '\$U', ['Uruguay']),
  CurrencyInfo('DOP', 'Dominican Peso', 'RD\$', ['Dominican Republic']),
  CurrencyInfo('JMD', 'Jamaican Dollar', 'J\$', ['Jamaica']),
  CurrencyInfo('CRC', 'Costa Rican Colón', '₡', ['Costa Rica']),
  CurrencyInfo('HTG', 'Haitian Gourde', 'G', ['Haiti']),
  CurrencyInfo('PAB', 'Panamanian Balboa', 'B/.', ['Panama']),
  CurrencyInfo('BMD', 'Bermudian Dollar', 'BD\$', ['Bermuda']),
  CurrencyInfo('KYD', 'Cayman Islands Dollar', 'CI\$', ['Cayman Islands']),
  CurrencyInfo('TTD', 'Trinidad Dollar', 'TT\$', ['Trinidad', 'Tobago']),
  CurrencyInfo('BBD', 'Barbadian Dollar', 'Bds\$', ['Barbados']),
  CurrencyInfo('BZD', 'Belize Dollar', 'BZ\$', ['Belize']),
  CurrencyInfo('GTQ', 'Guatemalan Quetzal', 'Q', ['Guatemala']),
  CurrencyInfo('HNL', 'Honduran Lempira', 'L', ['Honduras']),
  CurrencyInfo('NIO', 'Nicaraguan Córdoba', 'C\$', ['Nicaragua']),
  CurrencyInfo('PYG', 'Paraguayan Guaraní', '₲', ['Paraguay']),
  CurrencyInfo('BOB', 'Bolivian Boliviano', 'Bs.', ['Bolivia']),
  CurrencyInfo('VES', 'Venezuelan Bolívar', 'Bs.S', ['Venezuela']),
  CurrencyInfo('GYD', 'Guyanese Dollar', 'GY\$', ['Guyana']),
  CurrencyInfo('SRD', 'Surinamese Dollar', 'SR\$', ['Suriname']),
  CurrencyInfo('AWG', 'Aruban Florin', 'ƒ', ['Aruba']),
  CurrencyInfo('ANG', 'Antillean Guilder', 'ƒ', ['Curaçao', 'Sint Maarten']),
  CurrencyInfo('BSD', 'Bahamian Dollar', 'B\$', ['Bahamas']),
  CurrencyInfo('CUP', 'Cuban Peso', '₱', ['Cuba']),
  CurrencyInfo('XCD', 'East Caribbean Dollar', 'EC\$', ['Antigua', 'Dominica', 'Grenada', 'Saint Lucia', 'Saint Vincent']),

  // ═══════════════════════════════════════════════
  //  Oceania
  // ═══════════════════════════════════════════════
  CurrencyInfo('NZD', 'New Zealand Dollar', 'NZ\$', ['New Zealand']),
  CurrencyInfo('FJD', 'Fijian Dollar', 'FJ\$', ['Fiji']),
  CurrencyInfo('PGK', 'Papua New Guinean Kina', 'K', ['Papua New Guinea']),
  CurrencyInfo('WST', 'Samoan Tala', 'WS\$', ['Samoa']),
  CurrencyInfo('TOP', 'Tongan Paʻanga', 'T\$', ['Tonga']),
  CurrencyInfo('VUV', 'Vanuatu Vatu', 'VT', ['Vanuatu']),
  CurrencyInfo('SBD', 'Solomon Islands Dollar', 'SI\$', ['Solomon Islands']),
  CurrencyInfo('XPF', 'CFP Franc', '₣', ['French Polynesia', 'New Caledonia', 'Wallis']),
];

/// Quick lookup: code → CurrencyInfo.
final Map<String, CurrencyInfo> kCurrencyMap = {
  for (final c in kAllCurrencies) c.code: c,
};

/// Get a display label like "USD — US Dollar ($)".
String currencyLabel(String code) {
  final info = kCurrencyMap[code];
  if (info == null) return code;
  return '$code — ${info.name}';
}

/// Filter currencies by a search query (matches code, name, or country).
/// When [query] is empty, returns all currencies.
List<CurrencyInfo> searchCurrencies(String query) {
  if (query.isEmpty) return kAllCurrencies;
  return kAllCurrencies.where((c) => c.matches(query)).toList();
}

/// Returns prioritised suggestions: Top 10 + Gulf first, then the rest.
/// Useful as the default list when the user hasn't typed anything.
List<CurrencyInfo> defaultSuggestions() {
  final priority = <String>{...kTopCurrencyCodes, ...kGulfCurrencyCodes};
  final top = kAllCurrencies.where((c) => priority.contains(c.code)).toList();
  final rest = kAllCurrencies.where((c) => !priority.contains(c.code)).toList();
  return [...top, ...rest];
}
