import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('pt')
  ];

  /// No description provided for @back.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get back;

  /// No description provided for @help.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda'**
  String get help;

  /// No description provided for @helpCenter.
  ///
  /// In pt, this message translates to:
  /// **'Central de ajuda'**
  String get helpCenter;

  /// No description provided for @helpTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como podemos ajudar?'**
  String get helpTitle;

  /// No description provided for @helpIntro.
  ///
  /// In pt, this message translates to:
  /// **'Confira as perguntas frequentes ou fale com nossa equipe.'**
  String get helpIntro;

  /// No description provided for @faqTitle.
  ///
  /// In pt, this message translates to:
  /// **'Perguntas frequentes'**
  String get faqTitle;

  /// No description provided for @contact.
  ///
  /// In pt, this message translates to:
  /// **'Fale conosco'**
  String get contact;

  /// No description provided for @contactIntro.
  ///
  /// In pt, this message translates to:
  /// **'Não encontrou o que procurava? Entre em contato pelo e-mail:'**
  String get contactIntro;

  /// No description provided for @findPlacesQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Como encontrar estabelecimentos acessíveis?'**
  String get findPlacesQuestion;

  /// No description provided for @findPlacesAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Use a barra de pesquisa na tela principal ou acesse a aba \"Explorar\" para ver todos os estabelecimentos próximos. Você pode usar os filtros de acessibilidade para encontrar locais com rampa, banheiro acessível, entre outros.'**
  String get findPlacesAnswer;

  /// No description provided for @reviewQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Como avaliar um estabelecimento?'**
  String get reviewQuestion;

  /// No description provided for @reviewAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Abra um local em Locais Salvos ou Explorar. Depois de iniciar uma rota, volte aos detalhes para escolher a nota, comentar e responder à pesquisa.'**
  String get reviewAnswer;

  /// No description provided for @routeQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Como traçar uma rota até um local?'**
  String get routeQuestion;

  /// No description provided for @routeAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Busque um destino no mapa ou inicie uma rota pelos detalhes. Os trajetos são calculados para carro e não têm a acessibilidade verificada.'**
  String get routeAnswer;

  /// No description provided for @photoQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Posso alterar minha foto de perfil?'**
  String get photoQuestion;

  /// No description provided for @photoAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Na versão web, abra Menu → Informações Pessoais e toque na câmera para escolher uma imagem.'**
  String get photoAnswer;

  /// No description provided for @privacyQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Onde posso revisar minhas preferências de privacidade?'**
  String get privacyQuestion;

  /// No description provided for @privacyAnswer.
  ///
  /// In pt, this message translates to:
  /// **'Abra Menu → Privacidade para revisar suas preferências salvas. O mapa utiliza serviços externos; a permissão de localização do dispositivo é gerenciada separadamente.'**
  String get privacyAnswer;

  /// No description provided for @suggestionsQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Como funciona o sistema de sugestões?'**
  String get suggestionsQuestion;

  /// No description provided for @suggestionsAnswer.
  ///
  /// In pt, this message translates to:
  /// **'O app analisa os locais que você visitou e suas preferências de acessibilidade para recomendar novos estabelecimentos que atendam critérios semelhantes.'**
  String get suggestionsAnswer;

  /// No description provided for @loadingSettings.
  ///
  /// In pt, this message translates to:
  /// **'Carregando configurações...'**
  String get loadingSettings;

  /// No description provided for @generalSettings.
  ///
  /// In pt, this message translates to:
  /// **'Configurações gerais'**
  String get generalSettings;

  /// No description provided for @personalize.
  ///
  /// In pt, this message translates to:
  /// **'Personalize sua experiência'**
  String get personalize;

  /// No description provided for @personalizeIntro.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste o aplicativo de acordo com suas preferências de acessibilidade.'**
  String get personalizeIntro;

  /// No description provided for @preferences.
  ///
  /// In pt, this message translates to:
  /// **'Preferências'**
  String get preferences;

  /// No description provided for @language.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @distanceUnits.
  ///
  /// In pt, this message translates to:
  /// **'Unidades de distância'**
  String get distanceUnits;

  /// No description provided for @distanceUnitsHint.
  ///
  /// In pt, this message translates to:
  /// **'Escolha como as distâncias serão exibidas'**
  String get distanceUnitsHint;

  /// No description provided for @appearance.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo escuro'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo claro'**
  String get lightMode;

  /// No description provided for @suggestedRoutes.
  ///
  /// In pt, this message translates to:
  /// **'Percursos sugeridos'**
  String get suggestedRoutes;

  /// No description provided for @suggestedRoutesHint.
  ///
  /// In pt, this message translates to:
  /// **'Encontre locais com base nas suas visitas'**
  String get suggestedRoutesHint;

  /// No description provided for @updateMap.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar mapa da minha área'**
  String get updateMap;

  /// No description provided for @updateMapHint.
  ///
  /// In pt, this message translates to:
  /// **'Atualize as informações do mapa local'**
  String get updateMapHint;

  /// No description provided for @mapUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Mapa atualizado com sucesso!'**
  String get mapUpdated;

  /// No description provided for @accessibility.
  ///
  /// In pt, this message translates to:
  /// **'Acessibilidade'**
  String get accessibility;

  /// No description provided for @allowSuggestions.
  ///
  /// In pt, this message translates to:
  /// **'Permitir sugestões do app'**
  String get allowSuggestions;

  /// No description provided for @allowSuggestionsHint.
  ///
  /// In pt, this message translates to:
  /// **'Receba recomendações personalizadas'**
  String get allowSuggestionsHint;

  /// No description provided for @keepAwake.
  ///
  /// In pt, this message translates to:
  /// **'Impedir autobloqueio'**
  String get keepAwake;

  /// No description provided for @keepAwakeHint.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha a tela ativa durante o uso'**
  String get keepAwakeHint;

  /// No description provided for @selectLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Selecione o idioma'**
  String get selectLanguage;

  /// No description provided for @loadingPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Buscando locais acessíveis...'**
  String get loadingPlaces;

  /// No description provided for @noPlaceFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local encontrado'**
  String get noPlaceFound;

  /// No description provided for @noNearbyPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local próximo encontrado.'**
  String get noNearbyPlaces;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In pt, this message translates to:
  /// **'Tente pesquisar por outro nome ou endereço.'**
  String get tryAnotherSearch;

  /// No description provided for @noAvailablePlaces.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há estabelecimentos disponíveis para exibir.'**
  String get noAvailablePlaces;

  /// No description provided for @explore.
  ///
  /// In pt, this message translates to:
  /// **'Explorar'**
  String get explore;

  /// No description provided for @exploreIntro.
  ///
  /// In pt, this message translates to:
  /// **'Encontre locais com informações de acessibilidade'**
  String get exploreIntro;

  /// No description provided for @searchPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar estabelecimentos'**
  String get searchPlaces;

  /// No description provided for @searchPlacesHint.
  ///
  /// In pt, this message translates to:
  /// **'Pesquise por estabelecimentos'**
  String get searchPlacesHint;

  /// No description provided for @nearbyPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Locais por distância disponível'**
  String get nearbyPlaces;

  /// No description provided for @savedSuccessfully.
  ///
  /// In pt, this message translates to:
  /// **'Atualizado com sucesso!'**
  String get savedSuccessfully;

  /// No description provided for @changePassword.
  ///
  /// In pt, this message translates to:
  /// **'Alterar senha'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha atual'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In pt, this message translates to:
  /// **'Nova senha'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar nova senha'**
  String get confirmNewPassword;

  /// No description provided for @cancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @passwordMismatch.
  ///
  /// In pt, this message translates to:
  /// **'As senhas não correspondem!'**
  String get passwordMismatch;

  /// No description provided for @save.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get save;

  /// No description provided for @passwordChanged.
  ///
  /// In pt, this message translates to:
  /// **'Senha alterada com sucesso!'**
  String get passwordChanged;

  /// No description provided for @passwordError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao alterar senha.'**
  String get passwordError;

  /// No description provided for @webPhotoOnly.
  ///
  /// In pt, this message translates to:
  /// **'Seleção de foto de perfil disponível apenas na versão Web!'**
  String get webPhotoOnly;

  /// No description provided for @photoUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Foto atualizada!'**
  String get photoUpdated;

  /// No description provided for @loadingInformation.
  ///
  /// In pt, this message translates to:
  /// **'Carregando informações...'**
  String get loadingInformation;

  /// No description provided for @readOnlyField.
  ///
  /// In pt, this message translates to:
  /// **'Este campo não pode ser alterado'**
  String get readOnlyField;

  /// No description provided for @personalInformation.
  ///
  /// In pt, this message translates to:
  /// **'Informações Pessoais'**
  String get personalInformation;

  /// No description provided for @changePhoto.
  ///
  /// In pt, this message translates to:
  /// **'Alterar foto de perfil'**
  String get changePhoto;

  /// No description provided for @accountData.
  ///
  /// In pt, this message translates to:
  /// **'Dados da conta'**
  String get accountData;

  /// No description provided for @keepDataUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Mantenha suas informações atualizadas.'**
  String get keepDataUpdated;

  /// No description provided for @fullName.
  ///
  /// In pt, this message translates to:
  /// **'Nome completo'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @phoneNumber.
  ///
  /// In pt, this message translates to:
  /// **'Número de Telefone'**
  String get phoneNumber;

  /// No description provided for @notProvided.
  ///
  /// In pt, this message translates to:
  /// **'Não informado'**
  String get notProvided;

  /// No description provided for @username.
  ///
  /// In pt, this message translates to:
  /// **'Nome de usuário'**
  String get username;

  /// No description provided for @accountSecurity.
  ///
  /// In pt, this message translates to:
  /// **'Segurança da conta'**
  String get accountSecurity;

  /// No description provided for @accountSecurityHint.
  ///
  /// In pt, this message translates to:
  /// **'Proteja o acesso ao seu perfil.'**
  String get accountSecurityHint;

  /// No description provided for @password.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get password;

  /// No description provided for @requiredFields.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, preencha todos os campos!'**
  String get requiredFields;

  /// No description provided for @invalidCredentials.
  ///
  /// In pt, this message translates to:
  /// **'Usuário ou senha inválidos.'**
  String get invalidCredentials;

  /// No description provided for @logo.
  ///
  /// In pt, this message translates to:
  /// **'Logotipo do AcessoJá'**
  String get logo;

  /// No description provided for @accessAccount.
  ///
  /// In pt, this message translates to:
  /// **'Acesse sua conta'**
  String get accessAccount;

  /// No description provided for @signIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get signIn;

  /// No description provided for @signInHint.
  ///
  /// In pt, this message translates to:
  /// **'Use seus dados para continuar.'**
  String get signInHint;

  /// No description provided for @user.
  ///
  /// In pt, this message translates to:
  /// **'Usuário'**
  String get user;

  /// No description provided for @usernameHint.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu usuário'**
  String get usernameHint;

  /// No description provided for @passwordHint.
  ///
  /// In pt, this message translates to:
  /// **'Digite sua senha'**
  String get passwordHint;

  /// No description provided for @forgotPassword.
  ///
  /// In pt, this message translates to:
  /// **'Esqueceu sua senha?'**
  String get forgotPassword;

  /// No description provided for @continueWith.
  ///
  /// In pt, this message translates to:
  /// **'ou continue com'**
  String get continueWith;

  /// No description provided for @noAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não tem uma conta? '**
  String get noAccount;

  /// No description provided for @signUpLink.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre-se'**
  String get signUpLink;

  /// No description provided for @tagline.
  ///
  /// In pt, this message translates to:
  /// **'Acessibilidade para todos, em todos os lugares.'**
  String get tagline;

  /// No description provided for @loginSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Login realizado com sucesso!'**
  String get loginSuccess;

  /// No description provided for @destinationError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao buscar o destino. Tente novamente.'**
  String get destinationError;

  /// No description provided for @routeConnectionError.
  ///
  /// In pt, this message translates to:
  /// **'Erro de conexão ao buscar rota.'**
  String get routeConnectionError;

  /// No description provided for @noRoute.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível traçar uma rota para este local.'**
  String get noRoute;

  /// No description provided for @routeServerError.
  ///
  /// In pt, this message translates to:
  /// **'Erro do servidor de rotas.'**
  String get routeServerError;

  /// No description provided for @routeServiceError.
  ///
  /// In pt, this message translates to:
  /// **'Falha ao conectar com o serviço de rotas.'**
  String get routeServiceError;

  /// No description provided for @currentLocation.
  ///
  /// In pt, this message translates to:
  /// **'Localização atual'**
  String get currentLocation;

  /// No description provided for @destinationHint.
  ///
  /// In pt, this message translates to:
  /// **'Qual seu destino?'**
  String get destinationHint;

  /// No description provided for @noResults.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum resultado encontrado'**
  String get noResults;

  /// No description provided for @filters.
  ///
  /// In pt, this message translates to:
  /// **'Filtros'**
  String get filters;

  /// No description provided for @selectDestination.
  ///
  /// In pt, this message translates to:
  /// **'Selecione ou digite um destino.'**
  String get selectDestination;

  /// No description provided for @confirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get confirm;

  /// No description provided for @guideDog.
  ///
  /// In pt, this message translates to:
  /// **'Permissão de Entrada Cão Guia'**
  String get guideDog;

  /// No description provided for @accessibleTable.
  ///
  /// In pt, this message translates to:
  /// **'Mesa acessível'**
  String get accessibleTable;

  /// No description provided for @accessibleRestroom.
  ///
  /// In pt, this message translates to:
  /// **'Banheiros Especiais'**
  String get accessibleRestroom;

  /// No description provided for @accessRamp.
  ///
  /// In pt, this message translates to:
  /// **'Rampas de Acesso'**
  String get accessRamp;

  /// No description provided for @brailleMenu.
  ///
  /// In pt, this message translates to:
  /// **'Cardápio em Braille'**
  String get brailleMenu;

  /// No description provided for @searchFilters.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar por filtros...'**
  String get searchFilters;

  /// No description provided for @applyFilters.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar'**
  String get applyFilters;

  /// No description provided for @yourAccount.
  ///
  /// In pt, this message translates to:
  /// **'Sua conta'**
  String get yourAccount;

  /// No description provided for @savedPlacesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Locais Salvos'**
  String get savedPlacesTitle;

  /// No description provided for @signOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get signOut;

  /// No description provided for @openSettings.
  ///
  /// In pt, this message translates to:
  /// **'Abrir configurações'**
  String get openSettings;

  /// No description provided for @centerLocation.
  ///
  /// In pt, this message translates to:
  /// **'Centralizar minha localização'**
  String get centerLocation;

  /// No description provided for @closeRoute.
  ///
  /// In pt, this message translates to:
  /// **'Fechar rota'**
  String get closeRoute;

  /// No description provided for @searchDestination.
  ///
  /// In pt, this message translates to:
  /// **'Buscar destino ou calcular rota'**
  String get searchDestination;

  /// No description provided for @calculatingRoute.
  ///
  /// In pt, this message translates to:
  /// **'Calculando rota...'**
  String get calculatingRoute;

  /// No description provided for @explorePlaces.
  ///
  /// In pt, this message translates to:
  /// **'Explorar locais'**
  String get explorePlaces;

  /// No description provided for @savedPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Locais salvos'**
  String get savedPlaces;

  /// No description provided for @placeSuggestions.
  ///
  /// In pt, this message translates to:
  /// **'Sugestões de locais'**
  String get placeSuggestions;

  /// No description provided for @suggestions.
  ///
  /// In pt, this message translates to:
  /// **'Sugestões'**
  String get suggestions;

  /// No description provided for @evaluationSent.
  ///
  /// In pt, this message translates to:
  /// **'Avaliação enviada com sucesso! Obrigado por ajudar.'**
  String get evaluationSent;

  /// No description provided for @evaluationError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao enviar avaliação.'**
  String get evaluationError;

  /// No description provided for @connectionError.
  ///
  /// In pt, this message translates to:
  /// **'Erro de conexão com o servidor.'**
  String get connectionError;

  /// No description provided for @open.
  ///
  /// In pt, this message translates to:
  /// **'Aberto'**
  String get open;

  /// No description provided for @closed.
  ///
  /// In pt, this message translates to:
  /// **'Fechado'**
  String get closed;

  /// No description provided for @userRating.
  ///
  /// In pt, this message translates to:
  /// **'Avaliação dos usuários'**
  String get userRating;

  /// No description provided for @startRouteHere.
  ///
  /// In pt, this message translates to:
  /// **'Começar rota para este local'**
  String get startRouteHere;

  /// No description provided for @startRoute.
  ///
  /// In pt, this message translates to:
  /// **'Começar Rota'**
  String get startRoute;

  /// No description provided for @firstReview.
  ///
  /// In pt, this message translates to:
  /// **'Seja o primeiro a avaliar!'**
  String get firstReview;

  /// No description provided for @noComments.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há comentários para este local. Sua opinião sobre a acessibilidade ajudará centenas de pessoas que precisam desse suporte!'**
  String get noComments;

  /// No description provided for @chooseStars.
  ///
  /// In pt, this message translates to:
  /// **'Selecione as estrelas abaixo para começar'**
  String get chooseStars;

  /// No description provided for @anonymousUser.
  ///
  /// In pt, this message translates to:
  /// **'Usuário AcessoJá'**
  String get anonymousUser;

  /// No description provided for @commentsHistory.
  ///
  /// In pt, this message translates to:
  /// **'Comentários e histórico'**
  String get commentsHistory;

  /// No description provided for @visitBeforeReview.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não visitou este local recentemente. Para avaliá-lo, inicie uma rota clicando em \"Começar Rota\" acima.'**
  String get visitBeforeReview;

  /// No description provided for @shareExperience.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhe sua experiência'**
  String get shareExperience;

  /// No description provided for @reviewHint.
  ///
  /// In pt, this message translates to:
  /// **'Sua avaliação ajuda outras pessoas a encontrar locais mais acessíveis.'**
  String get reviewHint;

  /// No description provided for @yourRating.
  ///
  /// In pt, this message translates to:
  /// **'Qual sua nota?'**
  String get yourRating;

  /// No description provided for @reviewComment.
  ///
  /// In pt, this message translates to:
  /// **'Comentário da avaliação'**
  String get reviewComment;

  /// No description provided for @commentHint.
  ///
  /// In pt, this message translates to:
  /// **'Gostaria de adicionar comentários?'**
  String get commentHint;

  /// No description provided for @confirmReview.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar avaliação'**
  String get confirmReview;

  /// No description provided for @starsRequired.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, escolha uma quantidade de estrelas!'**
  String get starsRequired;

  /// No description provided for @loadingDetails.
  ///
  /// In pt, this message translates to:
  /// **'Carregando detalhes do local...'**
  String get loadingDetails;

  /// No description provided for @loadingPrivacy.
  ///
  /// In pt, this message translates to:
  /// **'Carregando privacidade...'**
  String get loadingPrivacy;

  /// No description provided for @privacy.
  ///
  /// In pt, this message translates to:
  /// **'Privacidade'**
  String get privacy;

  /// No description provided for @privacyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Controle sua privacidade'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In pt, this message translates to:
  /// **'Escolha quais informações ficam visíveis e como o AcessoJá utiliza seus dados.'**
  String get privacyIntro;

  /// No description provided for @dataVisibility.
  ///
  /// In pt, this message translates to:
  /// **'Visibilidade dos dados'**
  String get dataVisibility;

  /// No description provided for @publicProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil público'**
  String get publicProfile;

  /// No description provided for @publicProfileHint.
  ///
  /// In pt, this message translates to:
  /// **'Salve sua preferência de visibilidade do perfil e nome.'**
  String get publicProfileHint;

  /// No description provided for @showReviews.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar avaliações'**
  String get showReviews;

  /// No description provided for @showReviewsHint.
  ///
  /// In pt, this message translates to:
  /// **'Salve sua preferência de visibilidade das avaliações.'**
  String get showReviewsHint;

  /// No description provided for @locationHistory.
  ///
  /// In pt, this message translates to:
  /// **'Localização e histórico'**
  String get locationHistory;

  /// No description provided for @shareLocation.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar localização'**
  String get shareLocation;

  /// No description provided for @shareLocationHint.
  ///
  /// In pt, this message translates to:
  /// **'A permissão de localização do dispositivo é gerenciada separadamente.'**
  String get shareLocationHint;

  /// No description provided for @visibleHistory.
  ///
  /// In pt, this message translates to:
  /// **'Histórico visível'**
  String get visibleHistory;

  /// No description provided for @visibleHistoryHint.
  ///
  /// In pt, this message translates to:
  /// **'Salve sua preferência de visibilidade do histórico.'**
  String get visibleHistoryHint;

  /// No description provided for @accountCreated.
  ///
  /// In pt, this message translates to:
  /// **'Conta criada com sucesso!'**
  String get accountCreated;

  /// No description provided for @registerError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao criar conta.'**
  String get registerError;

  /// No description provided for @createAccount.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get createAccount;

  /// No description provided for @createYourAccount.
  ///
  /// In pt, this message translates to:
  /// **'Crie sua conta'**
  String get createYourAccount;

  /// No description provided for @registerIntro.
  ///
  /// In pt, this message translates to:
  /// **'Preencha seus dados para começar a usar o AcessoJá.'**
  String get registerIntro;

  /// No description provided for @registerDetails.
  ///
  /// In pt, this message translates to:
  /// **'Informe seus dados para criar o acesso.'**
  String get registerDetails;

  /// No description provided for @registerName.
  ///
  /// In pt, this message translates to:
  /// **'Nome de usuário'**
  String get registerName;

  /// No description provided for @registerNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Escolha seu nome de usuário'**
  String get registerNameHint;

  /// No description provided for @registerEmail.
  ///
  /// In pt, this message translates to:
  /// **'Email'**
  String get registerEmail;

  /// No description provided for @emailHint.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu email'**
  String get emailHint;

  /// No description provided for @confirmPassword.
  ///
  /// In pt, this message translates to:
  /// **'Confirme sua senha'**
  String get confirmPassword;

  /// No description provided for @repeatPassword.
  ///
  /// In pt, this message translates to:
  /// **'Repita sua senha'**
  String get repeatPassword;

  /// No description provided for @register.
  ///
  /// In pt, this message translates to:
  /// **'Cadastrar'**
  String get register;

  /// No description provided for @registerFooter.
  ///
  /// In pt, this message translates to:
  /// **'Ao continuar, você poderá avaliar e encontrar locais mais acessíveis.'**
  String get registerFooter;

  /// No description provided for @searchSavedPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar locais salvos'**
  String get searchSavedPlaces;

  /// No description provided for @searchAddress.
  ///
  /// In pt, this message translates to:
  /// **'Pesquisar local ou endereço'**
  String get searchAddress;

  /// No description provided for @placesSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo dos locais'**
  String get placesSummary;

  /// No description provided for @averageRating.
  ///
  /// In pt, this message translates to:
  /// **'Média geral'**
  String get averageRating;

  /// No description provided for @startRouteAction.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar rota'**
  String get startRouteAction;

  /// No description provided for @share.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get share;

  /// No description provided for @loadingSavedPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Carregando locais salvos...'**
  String get loadingSavedPlaces;

  /// No description provided for @noPlaceFoundPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local encontrado.'**
  String get noPlaceFoundPeriod;

  /// No description provided for @noSavedPlaces.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local salvo.'**
  String get noSavedPlaces;

  /// No description provided for @savedPlacesEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Os locais disponíveis aparecerão aqui para você consultar depois.'**
  String get savedPlacesEmptyHint;

  /// No description provided for @editProfileHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque para editar seu perfil'**
  String get editProfileHint;

  /// No description provided for @signOutAccount.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta'**
  String get signOutAccount;

  /// No description provided for @loadingProfile.
  ///
  /// In pt, this message translates to:
  /// **'Carregando perfil...'**
  String get loadingProfile;

  /// No description provided for @menu.
  ///
  /// In pt, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @manageAccount.
  ///
  /// In pt, this message translates to:
  /// **'Gerencie sua conta'**
  String get manageAccount;

  /// No description provided for @settingsDescription.
  ///
  /// In pt, this message translates to:
  /// **'Preferências e unidades'**
  String get settingsDescription;

  /// No description provided for @savedDescription.
  ///
  /// In pt, this message translates to:
  /// **'Consulte os locais disponíveis'**
  String get savedDescription;

  /// No description provided for @privacyDescription.
  ///
  /// In pt, this message translates to:
  /// **'Controle a visibilidade dos dados'**
  String get privacyDescription;

  /// No description provided for @personalDescription.
  ///
  /// In pt, this message translates to:
  /// **'Atualize seus dados e foto'**
  String get personalDescription;

  /// No description provided for @helpDescription.
  ///
  /// In pt, this message translates to:
  /// **'Encontre respostas para suas dúvidas'**
  String get helpDescription;

  /// No description provided for @noRouteHistory.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não iniciou nenhuma rota.'**
  String get noRouteHistory;

  /// No description provided for @historyHint.
  ///
  /// In pt, this message translates to:
  /// **'Seus locais visitados aparecerão aqui para gerar recomendações personalizadas!'**
  String get historyHint;

  /// No description provided for @recentlyVisited.
  ///
  /// In pt, this message translates to:
  /// **'Rotas recentes'**
  String get recentlyVisited;

  /// No description provided for @route.
  ///
  /// In pt, this message translates to:
  /// **'Rota'**
  String get route;

  /// No description provided for @details.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes'**
  String get details;

  /// No description provided for @recommended.
  ///
  /// In pt, this message translates to:
  /// **'Recomendados para Você'**
  String get recommended;

  /// No description provided for @noRecommendations.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma recomendação disponível no momento.'**
  String get noRecommendations;

  /// No description provided for @loadingSuggestions.
  ///
  /// In pt, this message translates to:
  /// **'Carregando sugestões...'**
  String get loadingSuggestions;

  /// No description provided for @surveyRequired.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, responda todas as perguntas!'**
  String get surveyRequired;

  /// No description provided for @surveyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Responda uma breve pesquisa e ajude outros usuários'**
  String get surveyTitle;

  /// No description provided for @surveyHint.
  ///
  /// In pt, this message translates to:
  /// **'Suas respostas ajudam a orientar outras pessoas.'**
  String get surveyHint;

  /// No description provided for @questionOne.
  ///
  /// In pt, this message translates to:
  /// **'1. Existem rampas de acesso na entrada do local?'**
  String get questionOne;

  /// No description provided for @questionTwo.
  ///
  /// In pt, this message translates to:
  /// **'2. Esse lugar tem banheiro acessível?'**
  String get questionTwo;

  /// No description provided for @questionThree.
  ///
  /// In pt, this message translates to:
  /// **'3. Há vagas de estacionamento reservadas para pessoas com deficiência?'**
  String get questionThree;

  /// No description provided for @questionFour.
  ///
  /// In pt, this message translates to:
  /// **'4. O ambiente é livre de barreiras e obstáculos que dificultem a locomoção?'**
  String get questionFour;

  /// No description provided for @dismissSurvey.
  ///
  /// In pt, this message translates to:
  /// **'Não, obrigado'**
  String get dismissSurvey;

  /// No description provided for @submitReview.
  ///
  /// In pt, this message translates to:
  /// **'Enviar Avaliação'**
  String get submitReview;

  /// No description provided for @reviews.
  ///
  /// In pt, this message translates to:
  /// **'Avaliações'**
  String get reviews;

  /// No description provided for @retry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retry;

  /// No description provided for @loadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os dados.'**
  String get loadError;

  /// No description provided for @saveError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar. Tente novamente.'**
  String get saveError;

  /// No description provided for @systemTheme.
  ///
  /// In pt, this message translates to:
  /// **'Usar tema do dispositivo'**
  String get systemTheme;

  /// No description provided for @yes.
  ///
  /// In pt, this message translates to:
  /// **'Sim'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In pt, this message translates to:
  /// **'Não'**
  String get no;

  /// No description provided for @unknown.
  ///
  /// In pt, this message translates to:
  /// **'Não sei'**
  String get unknown;

  /// No description provided for @working.
  ///
  /// In pt, this message translates to:
  /// **'Aguarde...'**
  String get working;

  /// No description provided for @unavailable.
  ///
  /// In pt, this message translates to:
  /// **'Esta opção ainda não está disponível.'**
  String get unavailable;

  /// No description provided for @invalidLocation.
  ///
  /// In pt, this message translates to:
  /// **'Este local ainda não tem coordenadas válidas para uma rota.'**
  String get invalidLocation;

  /// No description provided for @locationUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Localização indisponível. O mapa está mostrando Anápolis como referência.'**
  String get locationUnavailable;

  /// No description provided for @drivingRoute.
  ///
  /// In pt, this message translates to:
  /// **'Rota de carro • acessibilidade do trajeto não verificada'**
  String get drivingRoute;

  /// No description provided for @allPlacesNotice.
  ///
  /// In pt, this message translates to:
  /// **'Esta lista mostra os locais disponíveis. Favoritos pessoais ainda não estão disponíveis.'**
  String get allPlacesNotice;

  /// No description provided for @suggestionsDisabled.
  ///
  /// In pt, this message translates to:
  /// **'As sugestões estão desativadas nas preferências.'**
  String get suggestionsDisabled;

  /// No description provided for @photoTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'Escolha uma imagem de até 5 MB.'**
  String get photoTooLarge;

  /// No description provided for @invalidEmail.
  ///
  /// In pt, this message translates to:
  /// **'Informe um e-mail válido.'**
  String get invalidEmail;

  /// No description provided for @passwordHelp.
  ///
  /// In pt, this message translates to:
  /// **'A recuperação de senha ainda não está disponível no aplicativo.'**
  String get passwordHelp;

  /// No description provided for @kilometers.
  ///
  /// In pt, this message translates to:
  /// **'Quilômetros'**
  String get kilometers;

  /// No description provided for @miles.
  ///
  /// In pt, this message translates to:
  /// **'Milhas'**
  String get miles;

  /// No description provided for @clearSearch.
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca'**
  String get clearSearch;

  /// No description provided for @showPassword.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar senha'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In pt, this message translates to:
  /// **'Ocultar senha'**
  String get hidePassword;

  /// No description provided for @welcome.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao AcessoJá, {name}!'**
  String welcome(String name);

  /// No description provided for @placeImage.
  ///
  /// In pt, this message translates to:
  /// **'Imagem de {name}'**
  String placeImage(String name);

  /// No description provided for @routeTo.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar rota para {name}'**
  String routeTo(String name);

  /// No description provided for @detailsOf.
  ///
  /// In pt, this message translates to:
  /// **'Ver detalhes de {name}'**
  String detailsOf(String name);

  /// No description provided for @reviewsOf.
  ///
  /// In pt, this message translates to:
  /// **'Abrir avaliações de {name}'**
  String reviewsOf(String name);

  /// No description provided for @editLabel.
  ///
  /// In pt, this message translates to:
  /// **'Editar {name}'**
  String editLabel(String name);

  /// No description provided for @profileOf.
  ///
  /// In pt, this message translates to:
  /// **'Abrir informações pessoais de {name}'**
  String profileOf(String name);

  /// No description provided for @distanceValue.
  ///
  /// In pt, this message translates to:
  /// **'Distância: {value}'**
  String distanceValue(String value);

  /// No description provided for @ratingValue.
  ///
  /// In pt, this message translates to:
  /// **'Avaliação média {value} de 5'**
  String ratingValue(String value);

  /// No description provided for @giveStars.
  ///
  /// In pt, this message translates to:
  /// **'Dar {count} estrelas'**
  String giveStars(int count);

  /// No description provided for @placeCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum local} =1{1 local} other{{count} locais}}'**
  String placeCount(int count);

  /// No description provided for @reviewCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhuma avaliação} =1{1 avaliação} other{{count} avaliações}}'**
  String reviewCount(int count);

  /// No description provided for @destinationNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum local encontrado para \"{name}\"'**
  String destinationNotFound(String name);

  /// No description provided for @socialUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Login com {name} ainda não configurado.'**
  String socialUnavailable(String name);
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
