# PROGRESS — نقطة الاستئناف

لما تقول "continue": اقرأ هذا الملف + `docs/SPEC_DIGEST.md` + `docs/DECISIONS.md` وكمّل من **Next action**.

## الحالة

- **Branch:** `feat/local-app` (متفرّع من `feat/m0-scaffold`).
- **اللي اتكتب:** كل شاشات الـ prototype بـ Dart، شغّالة على **بيانات محلية** (`shared_preferences`) من غير Firebase.
- **التحقق:** مفيش Flutter في بيئة Claude (D3، وتحميل الـ SDK محظور من الـ proxy) → لا `pub get` ولا `analyze` ولا `test` اتشغّلوا. كل الكود اتراجع يدويًا بس.

## الشاشات (كلها مبنية)

قفل/اختيار PIN · المجاميع (+ كارت استكمال الحصة المفتوحة + حالة "مفيش مجاميع") · تفاصيل المجموعة · بدء الحصة · الحصة (حضور/واجب/امتحان/ملاحظة، الكل حضر + تراجع، بحث) · إضافة طالب (تعويض بربط بحصة غايبها / طالب جديد بدفع) · ملاحظات وإنهاء (+ نجاح) · بحث · بروفايل الطالب · تسجيل دفعة · السجل (نافذة تعديل 10 أيام) · الإعدادات · تغيير PIN · المزامنة (محاكاة).

## بنية الكود

- `lib/domain/`: models + `AppState` + `logic.dart` (حالة الدفع، تغطية التعويض، نافذة التعديل، البحث، ملخصات).
- `lib/data/`: `AppController` (Riverpod Notifier + persistence) و`seed.dart`.
- `lib/features/<screen>/`: الشاشات.
- `test/`: logic، controller، router، flow.

## Next action

1. المستخدم يشغّل `flutter create` ثم `tools\check.ps1` (خطوات `README.md`) ويلصق أي أخطاء → أصلّحها.
2. بعد ما يمشي: توصيل Firebase (auth، Firestore، rules + rules tests، sync حقيقي بدل المحاكاة، PBKDF2 للـ PIN، idle lock) حسب `docs/PLAN.md`.

## أسئلة مفتوحة

1. **D2** (دفعات 24 ساعة) و**D9** (اليوم 10 مقفول): لسه مش مطبّقين في rules لأن مفيش Firestore. في الوضع المحلي: التعديل متاح لحد 10 أيام للحصص بس، والدفعات بتتسجّل مباشرة من غير نافذة تعديل.
2. ملفات الخط عليك (`docs/FONTS.md`).

## قيود الوضع المحلي (متعمّدة)

- لا idle-lock ولا ربط بحساب (Firebase Auth).
- الـ PIN مخزّن مملّح ومتكرر الـ hash (SHA-256 × 5000) في `shared_preferences`، ده مؤقت لحد PBKDF2 + secure storage.
- الوقت بتوقيت الجهاز (مفيش تحويل منطقة زمنية).
- ما فيش تعديل/حذف دفعة ولا تعديل بيانات طالب.
