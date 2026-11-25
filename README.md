# Mnara (منارة) — تطبيق الأسيستنت

تطبيق Android بيشتغل **أوفلاين** للأسيستنت بتاع المدرس الخصوصي: حضور، واجب، امتحان، طلبة تعويض/جدد، ودفعات. بيتزامن مع Firebase لما النت يرجع.

- Flutter **3.32.0** / Dart **3.8.0** (ماتغيّرش الـ SDK).
- Android فقط، dark فقط، عربي RTL.
- الـ prototype المعتمد: `design/prototype/` (للقراءة بس). الخلاصة: `docs/SPEC_DIGEST.md`.
- القرارات: `docs/DECISIONS.md`. الخطة: `docs/PLAN.md`. نقطة الاستئناف: `docs/PROGRESS.md`.

## أول مرة (Windows PowerShell)

الريبو لسه مفيهاش فولدر `android/` (الكود اتكتب في بيئة من غير Flutter). ولّده مرة واحدة:

```powershell
git clone https://github.com/MohamedAmr2205/Mnara-app.git
cd Mnara-app
git checkout feat/m0-scaffold

flutter create --org com.mnara --project-name assistant --platforms android .
git checkout -- .
Remove-Item test\widget_test.dart
```

- `--org com.mnara --project-name assistant` بيطلّع الـ application id `com.mnara.assistant`.
- `git checkout -- .` بيرجّع ملفات الريبو اللي `flutter create` ممكن يكون كتب فوقها (`pubspec.yaml`، `main.dart`، `README.md`...)، وبيسيب فولدر `android/` الجديد.
- بعدها: `flutter pub get`.

## الخط

شوف `docs/FONTS.md`. من غير ملفات الخط التطبيق بيشتغل بخط النظام.

## الفحص المحلي

```powershell
powershell -ExecutionPolicy Bypass -File tools\check.ps1
```

بيشغّل: `flutter pub get` ثم `dart format .` ثم `flutter analyze` ثم `flutter test`. (Linux/macOS/Git Bash: `bash tools/check.sh`).

## التشغيل

```powershell
flutter run
```

الإعداد الكامل لـ Firebase هييجي في `docs/FIREBASE_SETUP.md` (M1 وما بعده).
