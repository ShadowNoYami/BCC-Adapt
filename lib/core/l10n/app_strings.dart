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
      ? 'Қош келдіңіз!'
      : 'Добро пожаловать!';

  String get welcomeSubtitle => isKk
      ? 'Реттеуді бастау үшін жасыл батырманы басыңыз.'
      : 'Нажмите зелёную кнопку, чтобы начать настройку.';

  String get languageLabel => isKk ? 'Тіл / Язык' : 'Язык / Тіл';
  String get languageRu => 'Русский';
  String get languageKk => 'Қазақша';
  String get langShortRu => 'РУС';
  String get langShortKk => 'ҚАЗ';

  // ---------------------------------------------------------------------------
  // Voice Guide Header & Common Actions
  // ---------------------------------------------------------------------------
  String get repeatVoiceButton => isKk ? 'Кеңесті тыңдау' : 'Послушать подсказку';
  String get backButton => isKk ? 'Артқа' : 'Назад';
  String get nextButton => isKk ? 'Келесі' : 'Далее';
  String stepProgress(int current, int total) =>
      isKk ? '$current-қадам, барлығы $total' : 'Шаг $current из $total';

  // ---------------------------------------------------------------------------
  // Screen 1: Welcome Screen
  // ---------------------------------------------------------------------------
  String get welcomeConfigureTitle => isKk
      ? 'Банкті өзіңізге ыңғайлау'
      : 'Настроить банк для себя';

  String get welcomeConfigureSubtitle => isKk
      ? 'Мәтін мен батырмалардың өлшемін таңдап, дауыстық көмекті қоса аласыз.'
      : 'Выберите размер текста и кнопок. Можно включить голосовые подсказки.';

  String get welcomeStandardModeButton => isKk
      ? 'Реттемей жалғастыру'
      : 'Продолжить без настройки';

  String get welcomeZeroTouchVoicePrompt => isKk
      ? 'Сәлеметсіз бе! Бұл BCC банкі. Мәтін мен батырмаларды үлкейту үшін жасыл батырманы басыңыз.'
      : 'Здравствуйте! Это банк BCC. Чтобы увеличить текст и кнопки, нажмите большую зелёную кнопку.';

  String get welcomeSpeechUnavailable => isKk
      ? 'Кеңес экранда жазылған.'
      : 'Подсказка написана на экране.';

  // ---------------------------------------------------------------------------
  // Screen 2: Calibration (3 micro-tests)
  // ---------------------------------------------------------------------------
  String get calibrationTitle => isKk ? 'Банкті ыңғайлау' : 'Удобный банк';

  String get calibrationVisionTitle => isKk
      ? 'Қайсысын оқу оңай?'
      : 'Что легче прочитать?';

  String get calibrationVisionPrompt => isKk
      ? 'Оқуға ыңғайлы нұсқаны басыңыз.'
      : 'Нажмите на удобный вариант.';

  String get visionCardStandardTitle =>
      isKk ? 'Қалыпты түр' : 'Обычный вид';
  String get visionCardStandardDesc =>
      isKk ? 'Стандартты өлшем және жұмсақ түстер' : 'Стандартный размер и мягкие цвета';

  String get visionCardLargeTitle =>
      isKk ? 'Ірі мәтін' : 'Крупный текст';
  String get visionCardLargeDesc =>
      isKk ? '1.5× үлкейтілген қаріп және анық жиек' : 'Увеличенный шрифт и чёткий контур';

  String get visionCardMaxTitle =>
      isKk ? 'Ең ірі мәтін' : 'Самый крупный текст';
  String get visionCardMaxDesc =>
      isKk ? 'Жоғары контраст' : 'Высокий контраст';

  String get contrastBackgroundLabel =>
      isKk ? 'Фон түсі:' : 'Фон карточки:';
  String get whiteBackgroundOption =>
      isKk ? 'Ақ фон' : 'Белый фон';
  String get blackBackgroundOption =>
      isKk ? 'Қара фон' : 'Чёрный фон';

  String get calibrationSampleBalanceLabel =>
      isKk ? 'Қолжетімді теңгерім' : 'Доступный баланс';

  String get calibrationMotorTitle => isKk
      ? 'Басу ыңғайлы ма?'
      : 'Удобно нажимать?';

  String get calibrationMotorPrompt => isKk
      ? 'Байқап көру үшін батырманы басыңыз.'
      : 'Попробуйте нажать на кнопку.';

  String get motorTargetButton =>
      isKk ? 'Осы жерді басыңыз' : 'Нажмите сюда';

  String get motorChoiceStandard =>
      isKk ? 'Әдеттегі батырмалар' : 'Обычные кнопки';

  String get motorChoiceTremor => isKk
      ? 'Ірі батырмалар және қорғаныс'
      : 'Крупные кнопки с защитой';

  String get motorHitFeedback => isKk
      ? 'Батырманы дәл бастыңыз.'
      : 'Вы попали по кнопке.';

  String get motorMissFeedback => isKk
      ? 'Ештеңе етпейді. Батырмаларды үлкейттік.'
      : 'Ничего страшного. Мы увеличили кнопки.';

  String get calibrationCognitiveTitle => isKk
      ? 'Басты бетте не болсын?'
      : 'Что показать на Главной?';

  String get calibrationCognitivePrompt => isKk
      ? 'Басты бетке ыңғайлы нұсқаны таңдаңыз.'
      : 'Выберите, что вам нужно на Главной.';

  String get cognitiveOptionSimplifiedTitle => isKk
      ? 'Тек ең керегі'
      : 'Только главное';

  String get cognitiveOptionSimplifiedDesc => isKk
      ? 'Қалдық, аударымдар, төлемдер және операциялар тарихы.'
      : 'Баланс, переводы, платежи и история операций.';

  String get cognitiveOptionFullTitle =>
      isKk ? 'Барлық қызметтер' : 'Все услуги банка';

  String get cognitiveOptionFullDesc => isKk
      ? 'Кэшбэк, шығындар мен ұсыныстар да көрінеді.'
      : 'На экране также будут кешбэк, расходы и предложения.';

  String get voiceOptionTitle => isKk
      ? 'Көмекші сөздерді дауыстау және дауыстық енгізуді қосу'
      : 'Включить озвучку подсказок и голосовой ввод';

  String get voiceOptionDesc => isKk
      ? 'Банк кеңестерді дауыстап оқиды. Аударым деректерін дауыспен айта аласыз.'
      : 'Банк читает подсказки вслух. Для перевода можно назвать данные голосом.';

  String get micPermissionDeniedNotice => isKk
      ? 'Микрофонға рұқсат берілмеді. Деректерді қолмен енгізе аласыз.'
      : 'Микрофон недоступен. Данные можно ввести вручную.';

  String get finishCalibrationButton => isKk
      ? 'Банкке кіруге өту'
      : 'Ко входу в банк';

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
      ? 'Телефон нөміріңізді енгізіңіз.'
      : 'Введите номер телефона.';

  String get registrationCodeStepPrompt => isKk
      ? 'SMS-кодты немесе ЖСН енгізіңіз.'
      : 'Введите код из SMS или ИИН.';

  String get phoneFieldLabel =>
      isKk ? 'Телефон нөмірі' : 'Номер телефона';

  String get phoneFieldHint => '+7 (707) 123-45-67';

  String get iinOrSmsFieldLabel =>
      isKk ? 'SMS-код немесе ЖСН' : 'Код из SMS или ИИН';

  String get iinOrSmsFieldHint =>
      isKk ? 'Мысалы: 4829' : 'Например: 4829';

  String get fillDemoDataButton => isKk
      ? 'Мысал деректерін енгізу'
      : 'Заполнить примером';

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
  String get homeGreeting => isKk ? 'Қайырлы күн!' : 'Добрый день!';
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
      isKk ? 'Микрофонды қосу' : 'Включить микрофон';
  String get voiceTransferOptions =>
      isKk ? 'Дауыспен толтыру' : 'Заполнить голосом';
  String get voicePreparing =>
      isKk ? 'Микрофон қосылып жатыр…' : 'Подключаем микрофон…';
  String get voiceDraftOnly => isKk
      ? 'Дауыс деректерді ғана толтырады. Аударымды өзіңіз растайсыз.'
      : 'Голосом можно заполнить поля. Перевод вы подтвердите сами.';
  String get voiceListeningNow => isKk
      ? 'Тыңдап тұрмын. Тоқтату үшін басыңыз.'
      : 'Слушаю. Нажмите, чтобы остановить.';
  String get voiceExamplePrompt => isKk
      ? 'Айтыңыз: «Арманға 5000 теңге аудар»'
      : 'Скажите: «Перевести 5000 тенге Арману»';
  String get voiceDemoSamplesLabel =>
      isKk ? 'Микрофонсыз байқап көру' : 'Попробовать без микрофона';
  String get voiceDemoSampleArman => isKk
      ? '«Арманға 5000 теңге аудар»'
      : '«Перевести 5000 тенге Арману»';
  String get voiceDemoSampleStranger => isKk
      ? '«8 777 999 88 77 нөміріне 60000 теңге жібер»'
      : '«Перевести 60000 тенге на 8 777 999 88 77»';

  String voiceDraftReadyTemplate(String amountWords, String recipient) => isKk
      ? 'Деректер толтырылды. Кімге: $recipient. Сома: $amountWords.'
      : 'Данные заполнены. Кому: $recipient. Сумма: $amountWords.';

  String get trustedContactsLabel =>
      isKk ? 'Кімге аударасыз?' : 'Кому перевести?';
  String get otherPhoneRecipientLabel =>
      isKk ? 'Алушының нөмірі' : 'Телефон получателя';
  String get differentPhoneRecipientLabel =>
      isKk ? 'Басқа нөмір' : 'Другой номер';
  String get amountInWordsPrefix => isKk ? 'Жазбаша:' : 'Прописью:';

  String get antiFraudStrangerTitle => isKk
      ? 'Алушыны тексеріңіз'
      : 'Проверьте получателя';
  String get antiFraudStrangerBody => isKk
      ? 'Бұл нөмір бейтаныс. «Қауіпсіз шотқа» ақша аударуды сұраса, қоңырауды аяқтап, аударымнан бас тартыңыз.'
      : 'Номер незнакомый. Если по телефону просят перевести деньги на «безопасный счёт», завершите звонок и отмените перевод.';

  String antiFraudWaitTemplate(int seconds) => isKk
      ? 'Тексеруге $seconds сек'
      : 'На проверку $seconds сек';

  String get cancelTransferButton =>
      isKk ? 'Аударымнан бас тарту' : 'Отменить перевод';
  String get transferReviewAmountLabel => isKk ? 'Сома' : 'Сумма';

  String get holdToConfirmActiveLabel =>
      isKk ? 'Басып тұра беріңіз' : 'Продолжайте держать';

  String get transferSuccessTitle =>
      isKk ? 'Аударым жіберілді' : 'Перевод отправлен';
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
      ? 'Контактіні таңдаңыз немесе дұрыс телефон нөмірін енгізіңіз'
      : 'Выберите контакт или введите корректный номер телефона';
  String get micUnavailableDemoHint => isKk
      ? 'Микрофон қолжетімсіз. Мысалды таңдаңыз немесе деректерді қолмен енгізіңіз.'
      : 'Микрофон недоступен. Выберите пример или введите данные вручную.';

  // ---------------------------------------------------------------------------
  // Screen 6: Accessibility Settings Screen
  // ---------------------------------------------------------------------------
  String get livePreviewTitle => isKk
      ? 'Экран үлгісі'
      : 'Пример экрана';
  String get recalibrateThreeStepsButton => isKk
      ? 'Банкті қайта ыңғайлау'
      : 'Подобрать удобный вид заново';
  String get resetToStandardBccButton => isKk
      ? 'Әдеттегі көрініске қайту'
      : 'Вернуть обычный вид';

  String get motorShortStandard => isKk ? 'Стандартты' : 'Стандарт';
  String get motorShortEnlarged =>
      isKk ? 'Ірі батырмалар' : 'Крупные кнопки';
  String get motorShortTremor => isKk
      ? 'Ірі батырмалар. Аударымды басып тұрып растау'
      : 'Крупные кнопки. Перевод с удержанием';

  String get cognitiveShortFull => isKk ? 'Барлық қызметтер' : 'Все услуги';
  String get cognitiveShortEssential =>
      isKk ? 'Тек ең керегі' : 'Только главное';
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
  String get transferScreenTitle => isKk ? 'Ақша аудару' : 'Перевод';

  String get recipientFieldLabel => isKk
      ? 'Кімге'
      : 'Кому';

  String get amountFieldLabel => isKk
      ? 'Аударым сомасы'
      : 'Сумма перевода';

  String get amountInWordsLabel => isKk
      ? 'Сома жазбаша:'
      : 'Сумма прописью:';

  String get sendTransferButton => isKk
      ? 'Аударымды растау'
      : 'Подтвердить перевод';

  String get holdToConfirmHint => isKk
      ? 'Батырманы 1,5 секунд басып тұрыңыз.'
      : 'Нажмите и держите 1,5 секунды.';

  String get voicePushToTalkButton => isKk
      ? 'Дауыспен айту (басып сөйлеңіз)'
      : 'Голосовая команда (нажмите и говорите)';

  String get voiceExampleHint => isKk
      ? 'Мысалы: «Арманға 15000 теңге жібер» немесе «8 707 123 45 67 нөміріне бес мың теңге аудар»'
      : 'Например: «Перевести пять тысяч тенге на номер 8 707 123 45 67» или «Отправить 15000 Арману»';

  String get talkBackGuardActiveNotice => isKk
      ? 'Жүйелік экран дикторы (TalkBack / VoiceOver) қосулы. Қосарланған дыбысты болдырмау үшін ішкі синтез авто-бұғатталды.'
      : 'Активен системный диктор (TalkBack / VoiceOver). Встроенная озвучка автоматически заблокирована во избежание наложения речи.';

  String get browserAccessibilityNotice => isKk
      ? 'Бұл режимде кеңестер экранда жазылады.'
      : 'В этом режиме подсказки доступны текстом.';

  String get speechUnavailableNotice => isKk
      ? 'Дыбыстау қолжетімсіз. Сома экранда жазбаша көрсетілген.'
      : 'Озвучка недоступна. Сумма прописью указана на экране.';

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
  String get a11ySettingsTitle => navAccessibility;

  String get textScaleLabel => isKk ? 'Мәтін масштабы' : 'Масштаб текста';
  String get contrastModeLabel => isKk ? 'Түс пен контраст' : 'Цвет и контраст';
  String get motorModeLabel => isKk ? 'Батырмаларды басу' : 'Удобство нажатия';
  String get cognitiveModeLabel =>
      isKk ? 'Басты бетте не көрсетіледі' : 'Что показать на Главной';
  String get voiceAssistantLabel => isKk ? 'Дауыстық көмек' : 'Голосовые подсказки';
  String get resetProfileButton => isKk
      ? 'Стандартты BCC интерфейсіне қайтару'
      : 'Сбросить до стандартного интерфейса BCC';

  String contrastModeName(ContrastMode mode) => switch (mode) {
        ContrastMode.standard => isKk ? 'Стандартты BCC' : 'Стандартный BCC',
        ContrastMode.highContrastLight => isKk
            ? 'Ашық фон, жоғары контраст'
            : 'Светлый фон, высокий контраст',
        ContrastMode.highContrastDark => isKk
            ? 'Қара фон, жоғары контраст'
            : 'Тёмный фон, высокий контраст',
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
