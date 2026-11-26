# PROGRESS (حالة الشغل)

**كل الكود ده مكتوب من غير ما يتشغّل ولا مرة** (مفيش Flutter ولا Emulator في بيئتي). متوقع أخطاء compile/analyze/test أول ما تشغّله.

## اتكتب
- Firestore rules + indexes + rules tests (`firebase/`) — ماتجرّبتش.
- Models + منطق الدفع/التعويض/الترقيم/الأكواد/تطبيع النص/توقيت القاهرة (`lib/domain`, `lib/core/utils`).
- Repository (Firestore) + تتبع المزامنة + connectivity + auto-upload + تحويل الكود المؤقت لدائم (transaction).
- PIN (PBKDF2) + lockout + AuthController + شاشات: دخول بإيميل، PIN، إعداد PIN، فتح بالباسورد، تغيير PIN.
- شاشات: Groups(+Resume/NoGroups)، Group، Start، Session، Finish، Search، Student، Payment، Sync، History، Settings.
- Router بحراس الدخول والقفل + قفل تلقائي بعد الخمول.
- Tests: unit + widget (كلها ماتشغّلتش).
- `tools/android_setup.ps1` و `tools/seed`.

## ناقص / مش متأكد منه
- docs: FIREBASE_SETUP / ARCHITECTURE / DATA_MODEL / TESTING لسه ما اتكتبوش، وREADME محتاج تصحيح (PowerShell vs cmd + تثبيت Flutter 3.32.0).
- outbox مستمر للكتابات الفاشلة بعد قفل التطبيق: **ما اتعملش**. الفشل بيتتبّع في الذاكرة بس.
- تسجيل الخروج بيقفل التطبيق بعد مسح الكاش (D14).
- إصدارات الـ packages غير متحقَّق منها.
- ملفات الخط لسه لازم تتنزّل (docs/FONTS.md).
