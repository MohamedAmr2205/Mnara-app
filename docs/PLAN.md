# PLAN — Mnara assistant app (Flutter / Firebase، Android فقط)

مرجع: برومبت المشروع + `SPEC_DIGEST.md` + `DECISIONS.md`.

## 0. وضع البيئة (اقرأه الأول)

- Claude شغّال في workspace **من غير Flutter/Dart**، والبروكسي بيمنع `storage.googleapis.com` و`pub.dev`. الـ workspace فيه Node 22 و Java بس.
- يعني من هنا **أكتب الكود والاختبارات والـ rules والـ docs**، لكن **مش هقدر أشغّل** `flutter pub get / analyze / test / build`. كل ما فيه "verified" في الـ acceptance هتتحقق منه إنت على Windows بأوامر `TESTING.md`، وهكتب في كل status إيه اتجرّب فعلاً وإيه لأ.
- الـ rules tests (`@firebase/rules-unit-testing` + emulator): هحاول أشغّلها هنا لو `npm` وتنزيل الـ emulator اتسمح، وإلا تتشغّل عندك.
- الـ push على `MohamedAmr2205/mnara-app` متاح (الريبو اتضافت للجلسة بصلاحية push).

## 1. Milestones (branch + PR لكل واحد)

| M | المحتوى | أخطر حاجة فيه (تتعمل الأول) |
|---|---|---|
| **M0** | scaffold (`flutter create`-equivalent بإيدي)، lints صارمة، design tokens، الخط، الشعار (CustomPainter)، shared widgets، go_router skeleton، سكريبتات محلية | تحديد `minSdk`/gradle متوافق مع Flutter 3.32 من غير قدرة على بناء |
| **M1** | Firebase wiring، sign-in أول مرة، PIN (PBKDF2 + lockout 10 + secure storage)، lock/idle، unlock بالباسورد، **Firestore rules + rules tests**، settings shell | الـ rules + اختباراتها |
| **M2** | models، repositories، converters، منطق مشتق (حالة الدفع، تغطية التعويض، نافذة التعديل، تطبيع الأرقام/البحث) + unit tests | منطق الدفع والتعويض |
| **M3** | Groups→Group→Start→**Session**→Finish + sheets الإضافة | شاشة الحصة وحفظها الذري/المستمر |
| **M4** | Search، Student profile، Payment | البحث من الكاش offline |
| **M5** | Sync (pending tracking + outbox + retry)، History + edit window، Resume، offline strip/badge، auto-upload toggle، Settings كاملة | تتبع pending writes والـ outbox |
| **M6** | تحويل كود مؤقت→دائم (transaction)، animations، a11y، seed script، docs، تمرير الاختبارات | الـ reconciliation |

داخل كل milestone: الأخطر الأول، التلميع في M6.

## 2. Dependencies (مرشَّحة — **غير متحقَّق منها**)

لازم تشغّل `flutter pub get` و`flutter pub outdated` عندك على 3.32.0 / 3.8.0. لو فيه تعارض بصلّحه في milestone M0 من غير `dependency_overrides` إلا لو لازم.

| الغرض | package | نطاق مرشَّح |
|---|---|---|
| state | `flutter_riverpod` | ^2.6.x |
| navigation | `go_router` | ^15.x |
| firebase | `firebase_core`, `firebase_auth`, `cloud_firestore` | ^3.x / ^5.x / ^5.x |
| قفل محلي | `flutter_secure_storage` | ^9.2.x |
| PBKDF2 (Dart خالص) | `cryptography` | ^2.7.x |
| اتصال | `connectivity_plus` | ^6.x |
| اتصال/نسخة | `package_info_plus` | ^8.x |
| اتصال هاتف | `url_launcher` | ^6.3.x |
| ids | `uuid` | ^4.5.x |
| SVG (اختياري) | `flutter_svg` | ^2.0.x |
| توقيت القاهرة | `timezone` | ^0.10.x |
| تنسيق | `intl` | ^0.20.x |
| animations | بدون package (implicit animations + `AnimationController`) | — |
| اختبار | `flutter_test`, `fake_cloud_firestore`, `mocktail` | ^3.x / ^1.0.x |
| lints | `flutter_lints` | ^5.x |

قرارات: بدون code-gen (`freezed`/`riverpod_generator`)، models يدوية immutable بـ `copyWith`/`==`. الشعار `CustomPainter` (من غير flutter_svg لو أمكن). بدون `google_fonts`، الخط في `assets/fonts/`.

## 3. المخاطر

1. **عدم القدرة على التشغيل هنا** (D3): أي خطأ compile/analyze هيظهر عندك. تخفيف: كود بسيط، امتناع عن APIs مش متأكد منها، وكل milestone ينتهي بقايمة أوامر قصيرة تشغّلها وتلصقلي الأخطاء.
2. **الخط IBM Plex Sans Arabic:** لازم ملفات الـ TTF في `assets/fonts/` — مش هقدر أنزّلها (محجوبة). **لازم تنزّلها إنت** (SIL OFL) من الموقع الرسمي/GitHub وتحطها بالأسماء اللي هحدّدها في M0. لحد كده التطبيق يشتغل بخط fallback.
3. **Firestore offline + outbox:** `waitForPendingWrites` مش بيفرّق بين مرفوض بالـ rules ومنتظر. تخفيف: `WriteBatch.commit()` Future بيفشل على الرفض؛ نلتقط الفشل ونحفظ الـ batch كـ JSON في outbox (D: يتوثّق في ARCHITECTURE).
4. **`disableNetwork()` في وضع "رفع يدوي":** بيأثر على كل القراءات الحيّة. تخفيف: القراءات من الكاش تفضل شغالة، وبيتوثّق.
5. **عدّاد الطلبة (counters.student):** transaction بتشتغل أونلاين بس. تخفيف: reconciliation idempotent وبتتجاهل لو offline.
6. **توقيت القاهرة وDST:** كل حساب تاريخ عبر `timezone` (Africa/Cairo)؛ اختبارات صيفي/شتوي (D9).
7. **حجم الشغل:** 6 milestones كبيرة، ومع حدود الـ usage ممكن ننقطع. تخفيف: `PROGRESS.md` + commits صغيرة + push بعد كل وحدة.
8. **minSdk:** Firebase + secure storage بيحتاجوا ≥ 23؛ هقفلها 23.

## 4. أسئلة تمنع التقدّم (blockers حقيقية)

مفيش حاجة تمنع بدء M0. الحاجات اللي عليك لاحقًا (مش دلوقتي): خطوات `FIREBASE_SETUP.md` (مشروع Firebase، `google-services.json`، الحسابات) وتنزيل ملفات الخط.

## 5. الخطوة التالية بعد موافقتك

`M0`: branch `feat/m0-scaffold`، الهيكل، tokens، شعار، widgets، routing skeleton، سكريبتات محلية، وقايمة أوامرك للتحقق.
