# PROGRESS — نقطة الاستئناف

لما تقول "continue": اقرأ هذا الملف + `docs/SPEC_DIGEST.md` + `docs/DECISIONS.md` وكمّل من **Next action**. ماتعيدش قراءة الـ prototype ولا البرومبت كله.

## الحالة

- **Milestone الحالي:** M0 (كتابة الكود خلصت، لسه ما اتجرّبش).
- **Branch:** `feat/m0-scaffold` (متفرّع من `docs/m0-plan`).
- **التحقق:** مفيش Flutter في بيئة Claude (D3) → لا `pub get` ولا `analyze` ولا `test` اتشغّلوا. كل الكود غير مجرَّب.

## Checklist M0

- [x] `pubspec.yaml` (deps: riverpod, go_router, intl) و`analysis_options.yaml` صارم و`.gitignore`
- [x] `tools/check.ps1` و`tools/check.sh`، `README.md`، `docs/FONTS.md`
- [x] Design tokens (ألوان/مسافات/radii/نصوص)، theme داكن، motion helper (reduced-motion)
- [x] الشعار (`MnaraLogo` بـ CustomPainter)
- [x] Widgets: StatusChip، PrimaryButton، MnaraIconButton، BottomSheetScaffold، CodeBadge، StatTile، PinPad، PinDots، AppNavBar، OfflineStrip، EmptyState
- [x] Routing skeleton (go_router + shell للـ 4 تابات؛ شاشات الحصة بدون nav) بـ placeholders معلَّمة بالـ milestone
- [x] Widget tests: PinPad/PinDots، الـ widgets المشتركة، الـ router
- [ ] **أنت:** توليد `android/` (README)، `flutter pub get`، `tools\check.ps1`، ولصق أي أخطاء
- [ ] **أنت:** ملفات الخط (`docs/FONTS.md`)
- [ ] مراجعة/merge الـ PR

## Next action

1. المستخدم يشغّل خطوات `README.md` ثم `tools\check.ps1` ويلصق الأخطاء (لو فيه). أصلّحها في M0.
2. بعدها: `feat/m1-auth-rules` — Firebase wiring، sign-in، PIN (PBKDF2 + lockout 10)، idle lock، unlock بالباسورد، `firestore.rules` + rules tests. **أخطر حاجة الأول: الـ rules.**

## أسئلة مفتوحة

1. موافقتك على **D2** (دفعات 24 ساعة) و**D9** (اليوم 10 مقفول، الـ rules بـ `<`)؟ (لو ما اعترضتش أعتبرها موافقة.)

## أوامر لازم تشغّلها إنت

```powershell
git checkout feat/m0-scaffold
flutter create --org com.mnara --project-name assistant --platforms android .
git checkout -- .
Remove-Item test\widget_test.dart
powershell -ExecutionPolicy Bypass -File tools\check.ps1
```

لو `dart format` عدّل ملفات: `git add -A && git commit -m "style: dart format"`.

## حدود معروفة

- Flutter/Dart مش متاحين في workspace Claude (D3).
- أول تشغيل ممكن يطلع أخطاء analyze/compile صغيرة (imports، lints) لأن الكود ما اتبناش.
- ملفات الخط مش في الريبو.
