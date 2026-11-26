/// Attendance state of a student in a session.
enum Attendance {
  present('present', 'حضر'),
  late('late', 'متأخر'),
  absent('absent', 'غايب'),
  excused('excused', 'بعذر');

  const Attendance(this.key, this.label);

  /// Stored value.
  final String key;

  /// Arabic label.
  final String label;

  /// Whether the student physically attended.
  bool get attended => this == present || this == late;

  /// Parses a stored value.
  static Attendance? fromKey(Object? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return null;
  }
}

/// Homework grade (prototype keys are translated in D5).
enum Homework {
  excellent('excellent', 'ممتاز'),
  veryGood('very_good', 'جيد جدا'),
  good('good', 'جيد'),
  acceptable('acceptable', 'مقبول'),
  weak('weak', 'ضعيف'),
  notSubmitted('not_submitted', 'لم يسلم');

  const Homework(this.key, this.label);

  /// Stored value.
  final String key;

  /// Arabic label.
  final String label;

  /// Parses a stored value.
  static Homework? fromKey(Object? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return null;
  }
}

/// Payment method.
enum PayMethod {
  cash('cash', 'كاش'),
  instapay('instapay', 'إنستاباي'),
  vodafoneCash('vodafone_cash', 'فودافون كاش');

  const PayMethod(this.key, this.label);

  /// Stored value.
  final String key;

  /// Arabic label.
  final String label;

  /// Parses a stored value (defaults to cash).
  static PayMethod fromKey(Object? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return cash;
  }
}

/// What kind of record a session row is.
enum RecordKind {
  regular('regular'),
  makeup('makeup'),
  newStudent('new');

  const RecordKind(this.key);

  /// Stored value.
  final String key;

  /// Parses a stored value.
  static RecordKind fromKey(Object? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return regular;
  }
}

/// How a brand-new student paid on the day they joined.
enum NewStudentPay {
  session('session'),
  month('month'),
  none('none');

  const NewStudentPay(this.key);

  /// Stored value.
  final String key;

  /// Parses a stored value.
  static NewStudentPay fromKey(Object? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return none;
  }
}
