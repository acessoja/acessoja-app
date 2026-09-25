import '../l10n/generated/app_localizations.dart';

enum RightsCategory { transport, places, health, education, work, culture }

class RightsLaw {
  const RightsLaw(this.id, this.title, this.summary, this.reference, this.url);
  final String id;
  final String title;
  final String summary;
  final String reference;
  final String url;
}

const _planalto = 'https://www.planalto.gov.br/ccivil_03';
const _lbi = '$_planalto/_ato2015-2018/2015/lei/l13146.htm';

/// Curated national provisions, not an exhaustive list. See RIGHTS_CONTENT.md.
List<RightsLaw> rightsCatalog(AppLocalizations s, RightsCategory category) {
  RightsLaw lbi(String id, String title, String body, String articles) =>
      RightsLaw(id, title, body, '${s.rightsLaw}\nArt. $articles', _lbi);
  final libras = RightsLaw('libras', s.rightsLibrasTitle, s.rightsLibrasBody,
      '${s.rightsLibrasLaw}\nArt. 1–4', '$_planalto/leis/2002/l10436.htm');
  return switch (category) {
    RightsCategory.transport => [
        lbi('transport-lbi', s.rightsTransportTitle, s.rightsTransportBody,
            '46, 48'),
        RightsLaw('transport-seats', s.rightsSeatsTitle, s.rightsSeatsBody,
            '${s.rightsPriorityLaw}\nArt. 3, 5', '$_planalto/leis/l10048.htm'),
        RightsLaw('transport-pass', s.rightsPassTitle, s.rightsPassBody,
            '${s.rightsPassLaw}\nArt. 1', '$_planalto/leis/l8899.htm'),
        RightsLaw(
            'transport-air',
            s.rightsAirTitle,
            s.rightsAirBody,
            s.rightsAirRule,
            'https://www.anac.gov.br/assuntos/legislacao/legislacao-1/resolucoes/resolucoes-2013/resolucao-no-280-de-11-07-2013'),
        lbi('transport-parking', s.rightsParkingTitle, s.rightsParkingBody,
            '47'),
      ],
    RightsCategory.places => [
        lbi('places-lbi', s.rightsPlacesTitle, s.rightsPlacesBody, '56–57'),
        RightsLaw('places-access', s.rightsAccessTitle, s.rightsAccessBody,
            '${s.rightsAccessLaw}\nArt. 1, 11', '$_planalto/leis/l10098.htm'),
        RightsLaw(
            'places-priority',
            s.rightsPriorityTitle,
            s.rightsPriorityBody,
            '${s.rightsPriorityLaw}\nArt. 1–2',
            '$_planalto/leis/l10048.htm'),
      ],
    RightsCategory.health => [
        lbi('health-lbi', s.rightsHealthTitle, s.rightsHealthBody, '18–25'),
        libras,
      ],
    RightsCategory.education => [
        lbi('education-lbi', s.rightsEducationTitle, s.rightsEducationBody,
            '27–28'),
        RightsLaw('education-ldb', s.rightsSchoolTitle, s.rightsSchoolBody,
            '${s.rightsSchoolLaw}\nArt. 58–60', '$_planalto/leis/l9394.htm'),
        libras,
      ],
    RightsCategory.work => [
        lbi('work-lbi', s.rightsWorkTitle, s.rightsWorkBody, '34–37'),
        RightsLaw('work-quota', s.rightsQuotaTitle, s.rightsQuotaBody,
            '${s.rightsQuotaLaw}\nArt. 93', '$_planalto/leis/l8213cons.htm'),
      ],
    RightsCategory.culture => [
        lbi('culture-lbi', s.rightsCultureTitle, s.rightsCultureBody, '42–44'),
        RightsLaw(
            'culture-tickets',
            s.rightsTicketsTitle,
            s.rightsTicketsBody,
            '${s.rightsTicketsLaw}\nArt. 1, § 8º e § 10',
            '$_planalto/_ato2011-2014/2013/lei/l12933.htm'),
      ],
  };
}
