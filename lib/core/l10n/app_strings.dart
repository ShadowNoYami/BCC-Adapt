import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accessibility/application/accessibility_profile_notifier.dart';
import '../accessibility/domain/accessibility_profile.dart';

/// Clean, zero-codegen RU / KK localisation dictionary for BCC Adapt.
///
/// Covers greetings, calibration micro-tests, accounts & balance, transfers,
/// anti-fraud warnings, voice assistant prompts, and accessibility settings.
class AppStrings {
  const AppStrings(this.localeCode);

  final String localeCode;

  bool get isKk => localeCode == 'kk';

  static AppStrings of(BuildContext context) {
    final code = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ru';
    return AppStrings(AccessibilityProfile.normalizeLocale(code));
  }

  // ---------------------------------------------------------------------------
  // Brand & Greetings
  // ---------------------------------------------------------------------------
  String get appTitle => 'BCC Adapt';

  String get bankName =>
      isKk ? 'Банк ЦентрКредит' : 'Банк ЦентрКредит';

  String get welcomeTitle => isKk
      ? 'BCC Adapt жүйесіне қош келдіңіз!'
      : 'Добро пожаловать в BCC Adapt!';

  String get welcomeSubtitle => isKk
      ? 'Біз қосымшаны сіздің көру, қимыл және қабылдау ерекшеліктеріңізге бейімдейміз.'
      : 'Мы адаптируем банковский интерфейс под ваше зрение, моторику и удобный темп работы.';

  String get languageLabel => isKk ? 'Тіл / Язык' : 'Язык / Тіл';
  String get languageRu => 'Русский';
  String get languageKk => 'Қазақша';
  String get langShortRu => 'РУС';
  String get langShortKk => 'ҚАЗ';

  // ---------------------------------------------------------------------------
  // Voice Guide Header & Common Actions
  // ---------------------------------------------------------------------------
  String get repeatVoiceButton => isKk ? 'Қайта тыңдау' : 'Повторить озвучку';
  String get backButton => isKk ? 'Артқа' : 'Назад';
  String get nextButton => isKk ? 'Келесі' : 'Далее';
  String stepProgress(int current, int total) =>
      isKk ? '$total ішінен $current-қадам' : 'Шаг $current из $total';

  // ---------------------------------------------------------------------------
  // Screen 1: Welcome Screen
  // ---------------------------------------------------------------------------
  String get welcomeConfigureTitle => isKk
      ? 'Ыңғайлы интерфейс пен дауысты баптау'
      : 'Настроить удобный интерфейс и голос';

  String get welcomeConfigureSubtitle => isKk
      ? '30 секунд ішінде ірі қаріпті, айқын контрастты және дауыстық көмекшіні таңдаймыз'
      : 'Подберём крупный шрифт, контраст и голосового помощника за 30 секунд';

  String get welcomeStandardModeButton => isKk
      ? 'Қалыпты режимде жалғастыру'
      : 'Продолжить в обычном режиме';

  String get welcomeZeroTouchVoicePrompt => isKk
      ? 'Сәлеметсіз бе! Бұл БЦК мобильді банкі. Егер сізге ірі қаріп, айқын контраст немесе дауыстық көмек қажет болса, экранның ортасындағы үлкен жасыл батырманы басыңыз.'
      : 'Здравствуйте! Это мобильный банк БЦК. Нажмите на большую зелёную кнопку в центре экрана, если вам нужен крупный шрифт, яркий контраст или голосовая помощь.';

  // ---------------------------------------------------------------------------
  // Screen 2: Calibration (3 micro-tests)
  // ---------------------------------------------------------------------------
  String get calibrationTitle => isKk
      ? 'Интерфейсті жылдам баптау'
      : 'Быстрая калибровка интерфейса';

  String get calibrationVisionTitle => isKk
      ? 'Қай карточка сізге жақсырақ көрінеді?'
      : 'Какую карточку вам видно лучше всего?';

  String get calibrationVisionPrompt => isKk
      ? 'Қай карточка сізге жақсырақ көрінеді? Соны басыңыз.'
      : 'Какую карточку вам видно лучше всего? Нажмите на неё.';

  String get visionCardStandardTitle =>
      isKk ? 'Қалыпты түр' : 'Обычный вид';
  String get visionCardStandardDesc =>
      isKk ? 'Стандартты өлшем және жұмсақ түстер' : 'Стандартный размер и мягкие цвета';

  String get visionCardLargeTitle =>
      isKk ? 'Ірі мәтін' : 'Крупный текст';
  String get visionCardLargeDesc =>
      isKk ? '1.5× үлкейтілген қаріп және анық жиек' : 'Увеличенный шрифт и чёткий контур';

  String get visionCardMaxTitle =>
      isKk ? 'Ең ірі және контрастты' : 'Максимально крупный и контрастный';
  String get visionCardMaxDesc =>
      isKk ? 'Ең айқын көріну үшін жоғары контраст' : 'Максимальная чёткость и контраст';

  String get contrastBackgroundLabel =>
      isKk ? 'Фон түсі:' : 'Фон карточки:';
  String get whiteBackgroundOption =>
      isKk ? 'Ақ фон' : 'Белый фон';
  String get blackBackgroundOption =>
      isKk ? 'Қара фон' : 'Чёрный фон';

  String get calibrationSampleBalanceLabel =>
      isKk ? 'Қолжетімді теңгерім' : 'Доступный баланс';

  String get calibrationMotorTitle => isKk
      ? 'Батырманы басу ыңғайлылығын тексеру'
      : 'Проверка удобства нажатия';

  String get calibrationMotorPrompt => isKk
      ? 'Тексеру үшін ортадағы үлкен батырманы басыңыз. Немесе төмендегі нұсқаны таңдаңыз.'
      : 'Нажмите на большую кнопку в центре для проверки. Или выберите удобный вариант ниже.';

  String get motorTargetButton =>
      isKk ? 'Тексеру үшін осында басыңыз' : 'Нажмите сюда для проверки';

  String get motorChoiceStandard =>
      isKk ? 'Маған қалыпты батырмаларды басу ыңғайлы' : 'Мне удобно нажимать обычные кнопки';

  String get motorChoiceTremor => isKk
      ? 'Маған үлкен батырмалар және кездейсоқ басудан қорғаныс қажет (қол дірілдегенде)'
      : 'Мне нужны большие кнопки и защита от случайных нажатий (при дрожании рук)';

  String get motorHitFeedback => isKk
      ? 'Тамаша! Нақты басылды.'
      : 'Отлично! Точное нажатие зафиксировано.';

  String get motorMissFeedback => isKk
      ? 'Сәл мүлт кету байқалды — ірі батырмалар (72 dp) және қорғаныс қосылды.'
      : 'Мы заметили касание мимо кнопки — включены большие кнопки (72 dp) и защита от случайных нажатий.';

  String get calibrationCognitiveTitle => isKk
      ? 'Банк режимі мен дауыстық көмекші'
      : 'Режим банка и голосовой помощник';

  String get calibrationCognitivePrompt => isKk
      ? 'Ыңғайлы экран режимін таңдап, қажет болса дауыстық көмекшіні қосыңыз.'
      : 'Выберите удобный режим экрана и при желании включите голосового помощника.';

  String get cognitiveOptionSimplifiedTitle => isKk
      ? 'Тек негізгі (Баланс, Аударымдар, Төлемдер)'
      : 'Только главное (Баланс, Переводы, Платежи)';

  String get cognitiveOptionSimplifiedDesc => isKk
      ? 'Артық жарнама мен күрделі графиктерсіз, ірі әрі түсінікті.'
      : 'Крупно и просто, без баннеров и сложной аналитики.';

  String get cognitiveOptionFullTitle =>
      isKk ? 'Банктің барлық функциялары' : 'Все функции банка';

  String get cognitiveOptionFullDesc => isKk
      ? 'Толық БЦК интерфейсі: кешбэк, аналитика және ұсыныстар.'
      : 'Полный интерфейс BCC: аналитика, кешбэк и предложения.';

  String get voiceOptionTitle => isKk
      ? 'Көмекші сөздерді дауыстау және дауыстық енгізуді қосу'
      : 'Включить озвучку подсказок и голосовой ввод';

  String get voiceOptionDesc => isKk
      ? 'Экрандағы маңызды хабарламалар оқылады және соманы дауыспен айтуға болады.'
      : 'Приложение будет озвучивать подсказки и понимать голосовые команды.';

  String get micPermissionDeniedNotice => isKk
      ? 'Микрофонға рұқсат берілмеді. Дауыстық көмекші сөздерді оқуды жалғастырады, микрофонды кейінірек баптаулардан қосуға болады.'
      : 'Доступ к микрофону не предоставлен. Озвучка подсказок продолжит работать, а голосовой ввод можно включить позже в настройках.';

  String get finishCalibrationButton => isKk
      ? 'Дайын — банкке өту'
      : 'Готово — перейти к банку';

  String get startCalibrationButton => isKk
      ? 'Калибрлеуді бастау'
      : 'Пройти калибровку';

  String get skipCalibrationButton => isKk
      ? 'Стандартты интерфейсті қалдыру'
      : 'Оставить стандартный интерфейс';

  // ---------------------------------------------------------------------------
  // Screen 3: Adaptive Registration
  // ---------------------------------------------------------------------------
  String get registrationTitle =>
      isKk ? 'BCC банкіне кіру' : 'Вход в BCC';

  String get registrationFullPrompt => isKk
      ? 'Жалғастыру үшін телефон нөміріңізді және ЖСН немесе SMS-кодты енгізіңіз.'
      : 'Введите номер телефона и ИИН или код из SMS для входа в банк.';

  String get registrationPhoneStepPrompt => isKk
      ? '1-қадам: Мобильді телефон нөміріңізді енгізіңіз'
      : 'Шаг 1: Введите ваш номер телефона';

  String get registrationCodeStepPrompt => isKk
      ? '2-қадам: ЖСН немесе SMS-тен келген кодты енгізіңіз'
      : 'Шаг 2: Введите ИИН или код из SMS';

  String get phoneFieldLabel =>
      isKk ? 'Телефон нөмірі' : 'Номер телефона';

  String get phoneFieldHint => '+7 (707) 123-45-67';

  String get iinOrSmsFieldLabel =>
      isKk ? 'ЖСН / SMS-код' : 'ИИН / Код из SMS';

  String get iinOrSmsFieldHint =>
      isKk ? 'Мысалы: 4829' : 'Например: 4829';

  String get fillDemoDataButton => isKk
      ? 'Тест деректерін толтыру'
      : 'Заполнить тестовыми данными';

  String get enterBankButton =>
      isKk ? 'BCC-ге кіру' : 'Войти в BCC';

  String get phoneValidationError => isKk
      ? 'Телефон нөмірін енгізіңіз'
      : 'Пожалуйста, введите номер телефона';

  String get codeValidationError => isKk
      ? 'ЖСН немесе SMS-кодты енгізіңіз'
      : 'Пожалуйста, введите ИИН или код из SMS';

  String get resetOnboardingDemoButton => isKk
      ? 'Онбордингті қалпына келтіру (демо)'
      : 'Сбросить онбординг (демо)';

  // ---------------------------------------------------------------------------
  // Screen 4: Home Screen & Adaptive Reflow
  // ---------------------------------------------------------------------------
  String get homeGreeting => isKk ? 'Қайырлы күн!' : 'Здравствуйте!';
  String get speakBalanceButton =>
      isKk ? 'Балансты тыңдау' : 'Озвучить баланс';

  String get actionTransfers => isKk ? 'Аударымдар' : 'Переводы';
  String get actionPayments => isKk ? 'Төлемдер' : 'Платежи';
  String get actionMyBank => isKk ? 'Менің банкім' : 'Мой банк';
  String get actionCashback => isKk ? 'Кэшбэк' : 'Кэшбэк';
  String get actionDeposits => isKk ? 'Депозиттер' : 'Депозиты';
  String get actionHistory =>
      isKk ? 'Операциялар тарихы' : 'История операций';

  String get promoBannerTitle => isKk
      ? '#bcc картасымен 10% дейін кэшбэк'
      : 'Кэшбэк до 10% по #bcc карте';
  String get promoBannerSubtitle => isKk
      ? 'Шығындар аналитикасы және жеке ұсыныстар'
      : 'Аналитика расходов и персональные предложения';
  String get analyticsMonthlySpentLabel =>
      isKk ? 'Қарашадағы шығындар' : 'Расходы за ноябрь';
  String get cashbackBalanceLabel =>
      isKk ? 'Жинақталған кэшбэк' : 'Накопленный кэшбэк';
  String get depositPromoText => isKk
      ? 'BCC Рахмет депозиті — жылдық 14.5% дейін'
      : 'Депозит BCC Рахмет — до 14.5% годовых';
  String get closeButton => isKk ? 'Жабу' : 'Закрыть';

  // ---------------------------------------------------------------------------
  // Screen 5: Transfer Screen, Voice Filler & Anti-Fraud
  // ---------------------------------------------------------------------------
  String get voiceFillTransferButton =>
      isKk ? 'Аударымды дауыспен толтыру' : 'Заполнить перевод голосом';
  String get voiceListeningNow => isKk
      ? 'Тыңдап тұрмын... сөйлеңіз (тоқтату үшін басыңыз)'
      : 'Слушаю... говорите (нажмите, чтобы остановить)';
  String get voiceExamplePrompt => isKk
      ? 'Айтыңыз: «Арманға 5000 теңге аудар»'
      : 'Скажите: «Перевести 5000 тенге Арману»';
  String get voiceDemoSamplesLabel => isKk
      ? 'Жылдам демо-дауыс (микрофонсыз тексеру):'
      : 'Быстрый демо-голос (проверка без микрофона):';
  String get voiceDemoSampleArman => isKk
      ? '«Арманға 5000 теңге аудар»'
      : '«Перевести 5000 тенге Арману»';
  String get voiceDemoSampleStranger => isKk
      ? '«8 777 999 88 77 нөміріне 60000 теңге жібер»'
      : '«Перевести 60000 тенге на 8 777 999 88 77»';

  String voiceDraftReadyTemplate(String amountWords, String recipient) => isKk
      ? '$recipient алушысына $amountWords аударым дайындалды. Экрандағы деректерді тексеріңіз.'
      : 'Подготовлен перевод $amountWords получателю $recipient. Проверьте данные на экране.';

  String get trustedContactsLabel =>
      isKk ? 'Сенімді контактілер' : 'Быстрые доверенные контакты';
  String get otherPhoneRecipientLabel => isKk
      ? 'Немесе жаңа телефон нөмірін енгізіңіз'
      : 'Или введите номер телефона получателя';
  String get amountInWordsPrefix => isKk ? 'Жазбаша:' : 'Прописью:';

  String get antiFraudStrangerTitle => isKk
      ? 'Назар аударыңыз! Бейтаныс алушы'
      : 'Внимание! Перевод незнакомому получателю';
  String get antiFraudStrangerBody => isKk
      ? 'Назар аударыңыз! Сіз бейтаныс адамға ақша аударып жатырсыз. Егер сізге «банктің қауіпсіздік қызметінен» қоңырау шалып, ақшаны «қауіпсіз шотқа» аударуды сұраса — бұл алаяқтар!'
      : 'Внимание! Вы переводите деньги незнакомому человеку. Если вам звонят из «службы безопасности банка» или просят перевести деньги на «безопасный счёт» — это мошенники!';

  String antiFraudWaitTemplate(int seconds) => isKk
      ? '$seconds сек күтіңіз...'
      : 'Подождите $seconds сек...';

  String get holdToConfirmProgressLabel => isKk
      ? 'Растау үшін 1.5 сек басып тұрыңыз'
      : 'Удерживайте 1.5 сек для перевода';
  String get holdToConfirmActiveLabel =>
      isKk ? 'Ұстап тұрыңыз...' : 'Удерживайте...';

  String get transferSuccessTitle =>
      isKk ? 'Аударым сәтті орындалды' : 'Перевод выполнен успешно';
  String get backToHomeButton =>
      isKk ? 'Басты бетке оралу' : 'Вернуться на Главную';
  String get newBalanceLabel =>
      isKk ? 'Картадағы жаңа қалдық:' : 'Новый баланс карты:';

  String get insufficientFundsError => isKk
      ? '#bcc картасында қаражат жеткіліксіз'
      : 'Недостаточно средств на #bcc карте';
  String get invalidAmountError => isKk
      ? 'Дұрыс аударым сомасын енгізіңіз'
      : 'Введите корректную сумму перевода';
  String get invalidRecipientError => isKk
      ? 'Контактіні таңдаңыз немесе телефон нөмірін енгізіңіз'
      : 'Выберите контакт или введите номер телефона';
  String get micUnavailableDemoHint => isKk
      ? 'Микрофон қолжетімсіз — төмендегі демо-дауыс батырмаларын пайдаланыңыз.'
      : 'Микрофон недоступен или отклонён — воспользуйтесь кнопками демо-голоса ниже.';

  // ---------------------------------------------------------------------------
  // Screen 6: Accessibility Settings Screen
  // ---------------------------------------------------------------------------
  String get livePreviewTitle => isKk
      ? 'Интерфейстің тірі көрінісі'
      : 'Живое превью интерфейса';
  String get recalibrateThreeStepsButton => isKk
      ? 'Калибрлеуді қайта өту (3 қадам)'
      : 'Пройти калибровку заново (3 шага)';
  String get resetToStandardBccButton => isKk
      ? 'Стандартты BCC күйіне қайтару'
      : 'Сбросить до стандартного BCC';

  String get motorShortStandard => isKk ? 'Стандартты' : 'Стандарт';
  String get motorShortEnlarged =>
      isKk ? 'Ірі батырмалар (64 dp)' : 'Крупные кнопки (64 dp)';
  String get motorShortTremor => isKk
      ? 'Дірілден қорғау (72 dp + ұстау)'
      : 'Защита от тремора (72 dp + удержание)';

  String get cognitiveShortFull => isKk ? 'Толық банк' : 'Полный банк';
  String get cognitiveShortEssential =>
      isKk ? 'Тек негізгі' : 'Только главное';
  String get cognitiveShortGuided =>
      isKk ? 'Қадамдық көмекшімен' : 'Пошаговый с подсказками';

  // ---------------------------------------------------------------------------
  // Banking: Balance, Accounts, Navigation
  // ---------------------------------------------------------------------------
  String get balanceSectionTitle => isKk ? 'Менің шотым' : 'Мой счёт';
  String get availableBalanceLabel => isKk ? 'Қолжетімді қалдық' : 'Доступный баланс';
  String get primaryCardTitle => isKk ? '#bcc карта' : '#bcc карта';

  String get navBalance => isKk ? 'Баланс' : 'Баланс';
  String get navTransfers => isKk ? 'Аударымдар' : 'Переводы';
  String get navPayments => isKk ? 'Төлемдер' : 'Платежи';
  String get navHistory => isKk ? 'Тарих' : 'История';
  String get navAnalytics => isKk ? 'Аналитика' : 'Аналитика';
  String get navAccessibility => isKk ? 'Қолжетімділік' : 'Доступность';

  String get quickContactsTitle => isKk
      ? 'Жылдам аударымдар мен төлемдер'
      : 'Быстрые переводы и платежи';

  String get recentTransactionsTitle => isKk
      ? 'Соңғы операциялар'
      : 'История операций';

  // ---------------------------------------------------------------------------
  // Transfers & Voice Assistant
  // ---------------------------------------------------------------------------
  String get transferScreenTitle => isKk
      ? 'Ақша аудару'
      : 'Перевод средств';

  String get recipientFieldLabel => isKk
      ? 'Алушы (аты немесе телефон нөмірі)'
      : 'Получатель (имя или номер телефона)';

  String get amountFieldLabel => isKk
      ? 'Аударым сомасы (₸)'
      : 'Сумма перевода (₸)';

  String get amountInWordsLabel => isKk
      ? 'Сома жазбаша:'
      : 'Сумма прописью:';

  String get sendTransferButton => isKk
      ? 'Аударымды растау'
      : 'Подтвердить перевод';

  String get holdToConfirmHint => isKk
      ? 'Растау үшін батырманы 1,5 секунд басып тұрыңыз (дірілден қорғау)'
      : 'Удерживайте кнопку 1,5 сек для подтверждения (защита от тремора)';

  String get voicePushToTalkButton => isKk
      ? 'Дауыспен айту (басып сөйлеңіз)'
      : 'Голосовая команда (нажмите и говорите)';

  String get voiceExampleHint => isKk
      ? 'Мысалы: «Арманға 15000 теңге жібер» немесе «8 707 123 45 67 нөміріне бес мың теңге аудар»'
      : 'Например: «Перевести пять тысяч тенге на номер 8 707 123 45 67» или «Отправить 15000 Арману»';

  String get talkBackGuardActiveNotice => isKk
      ? 'Жүйелік экран дикторы (TalkBack / VoiceOver) қосулы. Қосарланған дыбысты болдырмау үшін ішкі синтез авто-бұғатталды.'
      : 'Активен системный диктор (TalkBack / VoiceOver). Встроенная озвучка автоматически заблокирована во избежание наложения речи.';

  String speakBalanceTemplate(String formattedBalance, String inWords) => isKk
      ? 'Сіздің #bcc картаңыздағы қалдық: $formattedBalance. $inWords.'
      : 'Баланс вашей #bcc карты: $formattedBalance. $inWords.';

  String speakTransferCheckTemplate({
    required String recipient,
    required String amountInWords,
  }) =>
      isKk
          ? 'Тексеріңіз: алушы — $recipient, сомасы — $amountInWords.'
          : 'Проверьте перевод: получатель — $recipient, сумма — $amountInWords.';

  // ---------------------------------------------------------------------------
  // Anti-Fraud Warnings (Guided Step-by-Step mode)
  // ---------------------------------------------------------------------------
  String get antiFraudBannerTitle => isKk
      ? 'Қауіпсіздік ескертуі (Антифрод-қорғаныс)'
      : 'Предупреждение безопасности (Антифрод-защита)';

  String get antiFraudWarningText => isKk
      ? 'Банк қызметкерлері, полиция немесе «қауіпсіздік қызметі» ЕШҚАШАН ақшаны «қауіпсіз шотқа» аударуды сұрамайды. Егер сізге бөтен адам қоңырау шалып тұрса — аударымды тоқтатыңыз!'
      : 'Сотрудники банка, полиции или «службы безопасности» НИКОГДА не просят перевести деньги на «безопасный счёт». Если вам диктуют реквизиты по телефону — немедленно прервите операцию!';

  String get antiFraudPauseNotice => isKk
      ? 'Қадамдық қорғаныс режимі: аударым алдында алушы мен соманы мұқият тексеріңіз.'
      : 'Пошаговый защищённый режим: перед отправкой внимательно проверьте получателя и сумму прописью.';

  // ---------------------------------------------------------------------------
  // Accessibility Settings
  // ---------------------------------------------------------------------------
  String get a11ySettingsTitle => isKk
      ? 'Қолжетімділік профилі'
      : 'Профиль доступности';

  String get textScaleLabel => isKk ? 'Мәтін масштабы' : 'Масштаб текста';
  String get contrastModeLabel => isKk ? 'Контраст режимі' : 'Режим контрастности';
  String get motorModeLabel => isKk ? 'Моторика көмегі' : 'Помощь моторике';
  String get cognitiveModeLabel => isKk ? 'Интерфейс күрделілігі' : 'Режим интерфейса';
  String get voiceAssistantLabel => isKk ? 'Ішкі дауыс көмекшісі' : 'Встроенная озвучка';
  String get resetProfileButton => isKk
      ? 'Стандартты BCC интерфейсіне қайтару'
      : 'Сбросить до стандартного интерфейса BCC';

  String contrastModeName(ContrastMode mode) => switch (mode) {
        ContrastMode.standard => isKk ? 'Стандартты BCC' : 'Стандартный BCC',
        ContrastMode.highContrastLight => isKk
            ? 'Жоғары контраст (Ашық AAA)'
            : 'Высокий контраст (Светлый AAA)',
        ContrastMode.highContrastDark => isKk
            ? 'Жоғары контраст (Қараңғы AAA)'
            : 'Высокий контраст (Тёмный AAA)',
      };

  String motorLevelName(MotorAssistanceLevel level) => switch (level) {
        MotorAssistanceLevel.standard => isKk ? 'Стандартты (48 dp)' : 'Стандартный (48 dp)',
        MotorAssistanceLevel.enlargedTargets => isKk
            ? 'Ірі батырмалар (64+ dp)'
            : 'Крупные кнопки (64+ dp)',
        MotorAssistanceLevel.tremorProtection => isKk
            ? 'Дірілден қорғау (72 dp + 1.5с ұстау)'
            : 'Защита от тремора (72 dp + удержание 1.5с)',
      };

  String cognitiveModeName(CognitiveMode mode) => switch (mode) {
        CognitiveMode.fullBanking => isKk ? 'Толық банкинг' : 'Полный банкинг',
        CognitiveMode.simplifiedEssential => isKk
            ? 'Тек негізгі функциялар'
            : 'Упрощённый (основное)',
        CognitiveMode.guidedStepByStep => isKk
            ? 'Қадамдық + Антифрод'
            : 'Пошаговый + Антифрод-пауза',
      };
}

final appStringsProvider = Provider<AppStrings>((ref) {
  final profile = ref.watch(currentAccessibilityProfileProvider);
  return AppStrings(profile.localeCode);
});
