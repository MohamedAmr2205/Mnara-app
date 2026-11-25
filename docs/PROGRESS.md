# PROGRESS — نقطة الاستئناف

لما تقول "continue": اقرأ هذا الملف + `docs/SPEC_DIGEST.md` + `docs/DECISIONS.md` وكمّل من **Next action**. ماتعيدش قراءة الـ prototype ولا البرومبت كله.

## الحالة

- **Milestone الحالي:** تخطيط (قبل M0).
- **Branch:** `docs/m0-plan` — commit واحد للـ docs.

## Checklist

- [x] قراءة كل ملفات `design/prototype/` (15 شاشة + canvas.json)
- [x] `docs/SPEC_DIGEST.md`
- [x] `docs/DECISIONS.md` (D1–D9)
- [x] `docs/PLAN.md`
- [x] `docs/PROGRESS.md`
- [ ] موافقة المستخدم على الـ plan
- [ ] M0 … M6 (انظر `PLAN.md`)

## Next action

انتظار موافقة المستخدم، وبعدين: `git checkout -b feat/m0-scaffold` من `docs/m0-plan` وبدء M0.

## أسئلة مفتوحة

1. هل توافق على قرارات **D2** (نافذة 24 ساعة للدفعات بدل "نفس اليوم") و**D9** (حدّ التعديل: اليوم 10 مقفول، والـ rules بـ `<`)؟
2. تنزيل ملفات الخط IBM Plex Sans Arabic هيبقى عليك (البروكسي بيمنعني).

## أوامر لازم تشغّلها إنت

لسه مفيش (مفيش كود Flutter اتكتب). أول قايمة أوامر هتيجي مع M0.

## حدود البيئة

Flutter/Dart مش متاحين في workspace Claude (D3) — مفيش `analyze/test/build` من هنا.
