/// UI copy for the notebook surface. Transcription language is a separate
/// setting ([SpeechLanguageMode]); this is the screens' own locale.
class NotebookL10n {
  const NotebookL10n._(this.locale, this._s);

  final String locale;
  final Map<String, String> _s;

  static const supported = <String>[
    'en',
    'hi',
    'mr',
    'es',
    'fr',
    'de',
    'pt',
    'ja',
    'zh',
    'ar',
  ];

  static const fallback = NotebookL10n._('en', _en);

  static NotebookL10n of(String? locale) {
    final code = _normalize(locale);
    final table = _tables[code];
    if (table == null) return fallback;
    return NotebookL10n._(code, table);
  }

  static String _normalize(String? locale) {
    if (locale == null || locale.isEmpty) return 'en';
    final lower = locale.toLowerCase().replaceAll('_', '-');
    final primary = lower.split('-').first;
    return supported.contains(primary) ? primary : 'en';
  }

  String t(String key) => _s[key] ?? _en[key] ?? key;

  String get notesTitle => t('notesTitle');
  String get noNotesYet => t('noNotesYet');
  String get noMatchingNotes => t('noMatchingNotes');
  String get newNote => t('newNote');
  String get editNote => t('editNote');
  String get title => t('title');
  String get body => t('body');
  String get tags => t('tags');
  String get labels => t('labels');
  String get tagsHint => t('tagsHint');
  String get labelsHint => t('labelsHint');
  String get save => t('save');
  String get cancel => t('cancel');
  String get search => t('search');
  String get superSummary => t('superSummary');
  String get record => t('record');
  String get importAudio => t('importAudio');
  String get importPodcast => t('importPodcast');
  String get podcastUrl => t('podcastUrl');
  String get export => t('export');
  String get copy => t('copy');
  String get share => t('share');
  String get keyPoints => t('keyPoints');
  String get summary => t('summary');
  String get language => t('language');
  String get selectNotes => t('selectNotes');
  String get combineSelected => t('combineSelected');
  String get copied => t('copied');
  String get shared => t('shared');
  String get saved => t('saved');
  String get delete => t('delete');
  String get uiLanguage => t('uiLanguage');
  String get needsTwoNotes => t('needsTwoNotes');
  String get generatingSuperSummary => t('generatingSuperSummary');

  static const _en = {
    'notesTitle': 'Notes',
    'noNotesYet': 'No notes yet',
    'noMatchingNotes': 'No matching notes',
    'newNote': 'New note',
    'editNote': 'Edit note',
    'title': 'Title',
    'body': 'Body',
    'tags': 'Tags',
    'labels': 'Labels',
    'tagsHint': 'work, standup',
    'labelsHint': 'meeting, lecture',
    'save': 'Save',
    'cancel': 'Cancel',
    'search': 'Search notes',
    'superSummary': 'Super summary',
    'record': 'Record',
    'importAudio': 'Import audio',
    'importPodcast': 'Import podcast',
    'podcastUrl': 'Podcast, audio, or YouTube URL',
    'export': 'Export',
    'copy': 'Copy',
    'share': 'Share',
    'keyPoints': 'Key points',
    'summary': 'Summary',
    'language': 'Language',
    'selectNotes': 'Select notes',
    'combineSelected': 'Combine selected',
    'copied': 'Copied to clipboard',
    'shared': 'Shared',
    'saved': 'Saved',
    'delete': 'Delete',
    'uiLanguage': 'Notes language',
    'needsTwoNotes': 'Select at least two notes to combine',
    'generatingSuperSummary': 'Writing Super Summary…',
  };

  static const _hi = {
    'notesTitle': 'नोट्स',
    'noNotesYet': 'अभी कोई नोट नहीं',
    'noMatchingNotes': 'कोई मेल खाता नोट नहीं',
    'newNote': 'नया नोट',
    'editNote': 'नोट संपादित करें',
    'title': 'शीर्षक',
    'body': 'विषय',
    'tags': 'टैग',
    'labels': 'लेबल',
    'tagsHint': 'काम, स्टैंडअप',
    'labelsHint': 'मीटिंग, व्याख्यान',
    'save': 'सहेजें',
    'cancel': 'रद्द करें',
    'search': 'नोट खोजें',
    'superSummary': 'सुपर सारांश',
    'record': 'रिकॉर्ड',
    'importAudio': 'ऑडियो आयात करें',
    'importPodcast': 'पॉडकास्ट आयात करें',
    'podcastUrl': 'पॉडकास्ट या ऑडियो URL',
    'export': 'निर्यात',
    'copy': 'कॉपी',
    'share': 'साझा करें',
    'keyPoints': 'मुख्य बातें',
    'summary': 'सारांश',
    'language': 'भाषा',
    'selectNotes': 'नोट चुनें',
    'combineSelected': 'चयनित जोड़ें',
    'copied': 'क्लिपबोर्ड पर कॉपी हुआ',
    'shared': 'साझा किया गया',
    'saved': 'सहेजा गया',
    'delete': 'हटाएँ',
    'uiLanguage': 'नोट्स की भाषा',
    'needsTwoNotes': 'जोड़ने के लिए कम से कम दो नोट चुनें',
  };

  static const _es = {
    'notesTitle': 'Notas',
    'noNotesYet': 'Aún no hay notas',
    'noMatchingNotes': 'No hay notas coincidentes',
    'newNote': 'Nota nueva',
    'editNote': 'Editar nota',
    'title': 'Título',
    'body': 'Cuerpo',
    'tags': 'Etiquetas',
    'labels': 'Rótulos',
    'save': 'Guardar',
    'cancel': 'Cancelar',
    'search': 'Buscar notas',
    'superSummary': 'Súper resumen',
    'record': 'Grabar',
    'importAudio': 'Importar audio',
    'importPodcast': 'Importar podcast',
    'export': 'Exportar',
    'copy': 'Copiar',
    'share': 'Compartir',
    'keyPoints': 'Puntos clave',
    'summary': 'Resumen',
    'language': 'Idioma',
    'copied': 'Copiado al portapapeles',
    'delete': 'Eliminar',
    'uiLanguage': 'Idioma de las notas',
    'needsTwoNotes': 'Selecciona al menos dos notas para combinar',
  };

  static const _fr = {
    'notesTitle': 'Notes',
    'noNotesYet': 'Aucune note pour l’instant',
    'noMatchingNotes': 'Aucune note correspondante',
    'newNote': 'Nouvelle note',
    'editNote': 'Modifier la note',
    'title': 'Titre',
    'body': 'Corps',
    'tags': 'Tags',
    'labels': 'Libellés',
    'save': 'Enregistrer',
    'cancel': 'Annuler',
    'search': 'Rechercher des notes',
    'superSummary': 'Super résumé',
    'record': 'Enregistrer',
    'importAudio': 'Importer un audio',
    'importPodcast': 'Importer un podcast',
    'export': 'Exporter',
    'copy': 'Copier',
    'share': 'Partager',
    'keyPoints': 'Points clés',
    'summary': 'Résumé',
    'language': 'Langue',
    'copied': 'Copié dans le presse-papiers',
    'delete': 'Supprimer',
    'uiLanguage': 'Langue des notes',
    'needsTwoNotes': 'Sélectionnez au moins deux notes à fusionner',
  };

  static const _de = {
    'notesTitle': 'Notizen',
    'noNotesYet': 'Noch keine Notizen',
    'noMatchingNotes': 'Keine passenden Notizen',
    'newNote': 'Neue Notiz',
    'editNote': 'Notiz bearbeiten',
    'title': 'Titel',
    'body': 'Text',
    'tags': 'Tags',
    'labels': 'Labels',
    'save': 'Speichern',
    'cancel': 'Abbrechen',
    'search': 'Notizen suchen',
    'superSummary': 'Super-Zusammenfassung',
    'record': 'Aufnehmen',
    'importAudio': 'Audio importieren',
    'importPodcast': 'Podcast importieren',
    'export': 'Exportieren',
    'copy': 'Kopieren',
    'share': 'Teilen',
    'keyPoints': 'Kernpunkte',
    'summary': 'Zusammenfassung',
    'language': 'Sprache',
    'copied': 'In die Zwischenablage kopiert',
    'delete': 'Löschen',
    'uiLanguage': 'Notizsprache',
    'needsTwoNotes': 'Wähle mindestens zwei Notizen zum Kombinieren',
  };

  static const _pt = {
    'notesTitle': 'Notas',
    'noNotesYet': 'Ainda não há notas',
    'noMatchingNotes': 'Nenhuma nota correspondente',
    'newNote': 'Nova nota',
    'editNote': 'Editar nota',
    'title': 'Título',
    'body': 'Corpo',
    'tags': 'Tags',
    'labels': 'Rótulos',
    'save': 'Salvar',
    'cancel': 'Cancelar',
    'search': 'Pesquisar notas',
    'superSummary': 'Super resumo',
    'record': 'Gravar',
    'importAudio': 'Importar áudio',
    'importPodcast': 'Importar podcast',
    'export': 'Exportar',
    'copy': 'Copiar',
    'share': 'Compartilhar',
    'keyPoints': 'Pontos-chave',
    'summary': 'Resumo',
    'language': 'Idioma',
    'copied': 'Copiado para a área de transferência',
    'delete': 'Excluir',
    'uiLanguage': 'Idioma das notas',
    'needsTwoNotes': 'Selecione pelo menos duas notas para combinar',
  };

  static const _ja = {
    'notesTitle': 'メモ',
    'noNotesYet': 'まだメモがありません',
    'noMatchingNotes': '一致するメモがありません',
    'newNote': '新しいメモ',
    'editNote': 'メモを編集',
    'title': 'タイトル',
    'body': '本文',
    'tags': 'タグ',
    'labels': 'ラベル',
    'save': '保存',
    'cancel': 'キャンセル',
    'search': 'メモを検索',
    'superSummary': 'スーパー要約',
    'record': '録音',
    'importAudio': '音声を読み込む',
    'importPodcast': 'ポッドキャストを読み込む',
    'export': '書き出す',
    'copy': 'コピー',
    'share': '共有',
    'keyPoints': '要点',
    'summary': '要約',
    'language': '言語',
    'copied': 'クリップボードにコピーしました',
    'delete': '削除',
    'uiLanguage': 'メモの言語',
    'needsTwoNotes': '結合するにはメモを2件以上選んでください',
  };

  static const _zh = {
    'notesTitle': '笔记',
    'noNotesYet': '还没有笔记',
    'noMatchingNotes': '没有匹配的笔记',
    'newNote': '新建笔记',
    'editNote': '编辑笔记',
    'title': '标题',
    'body': '正文',
    'tags': '标签',
    'labels': '分类',
    'save': '保存',
    'cancel': '取消',
    'search': '搜索笔记',
    'superSummary': '超级摘要',
    'record': '录音',
    'importAudio': '导入音频',
    'importPodcast': '导入播客',
    'export': '导出',
    'copy': '复制',
    'share': '分享',
    'keyPoints': '要点',
    'summary': '摘要',
    'language': '语言',
    'copied': '已复制到剪贴板',
    'delete': '删除',
    'uiLanguage': '笔记语言',
    'needsTwoNotes': '请至少选择两条笔记进行合并',
  };

  static const _ar = {
    'notesTitle': 'الملاحظات',
    'noNotesYet': 'لا توجد ملاحظات بعد',
    'noMatchingNotes': 'لا توجد ملاحظات مطابقة',
    'newNote': 'ملاحظة جديدة',
    'editNote': 'تحرير الملاحظة',
    'title': 'العنوان',
    'body': 'النص',
    'tags': 'الوسوم',
    'labels': 'التصنيفات',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'search': 'بحث في الملاحظات',
    'superSummary': 'الملخص الشامل',
    'record': 'تسجيل',
    'importAudio': 'استيراد صوت',
    'importPodcast': 'استيراد بودكاست',
    'export': 'تصدير',
    'copy': 'نسخ',
    'share': 'مشاركة',
    'keyPoints': 'النقاط الأساسية',
    'summary': 'الملخص',
    'language': 'اللغة',
    'copied': 'تم النسخ إلى الحافظة',
    'delete': 'حذف',
    'uiLanguage': 'لغة الملاحظات',
    'needsTwoNotes': 'اختر ملاحظتين على الأقل للدمج',
  };

  static const _mr = {
    'notesTitle': 'नोट्स',
    'noNotesYet': 'अजून नोट्स नाहीत',
    'noMatchingNotes': 'जुळणारे नोट्स नाहीत',
    'newNote': 'नवीन नोट',
    'editNote': 'नोट संपादित करा',
    'title': 'शीर्षक',
    'body': 'मजकूर',
    'tags': 'टॅग',
    'labels': 'लेबल्स',
    'save': 'जतन करा',
    'cancel': 'रद्द करा',
    'search': 'नोट शोधा',
    'superSummary': 'सुपर सारांश',
    'record': 'रेकॉर्ड',
    'importAudio': 'ऑडिओ आयात करा',
    'importPodcast': 'पॉडकास्ट आयात करा',
    'export': 'निर्यात',
    'copy': 'कॉपी',
    'share': 'शेअर',
    'keyPoints': 'मुख्य मुद्दे',
    'summary': 'सारांश',
    'language': 'भाषा',
    'copied': 'क्लिपबोर्डवर कॉपी झाले',
    'delete': 'हटवा',
    'uiLanguage': 'नोट्सची भाषा',
    'needsTwoNotes': 'एकत्र करण्यासाठी किमान दोन नोट्स निवडा',
  };

  static const _tables = <String, Map<String, String>>{
    'en': _en,
    'hi': _hi,
    'mr': _mr,
    'es': _es,
    'fr': _fr,
    'de': _de,
    'pt': _pt,
    'ja': _ja,
    'zh': _zh,
    'ar': _ar,
  };
}
