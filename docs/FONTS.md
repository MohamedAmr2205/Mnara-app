# الخط (IBM Plex Sans Arabic)

التطبيق مصمَّم على IBM Plex Sans Arabic (ترخيص SIL OFL)، ولازم يتضمّن جوه الـ APK عشان يشتغل offline (ممنوع `google_fonts` وقت التشغيل).

الـ workspace اللي اتبنى فيه الكود بيمنع التنزيل، فالملفات **مش في الريبو**. لحد ما تضيفها، الـ theme بيرجع لخط النظام ومفيش حاجة بتكسر.

## الخطوات

1. نزّل الخط من المصدر الرسمي (IBM Plex على GitHub: `IBM/plex`، مجلد `packages/plex-sans-arabic`) أو من Google Fonts.
2. حط 4 ملفات TTF في `assets/fonts/` بالأسماء دي بالظبط:
   - `IBMPlexSansArabic-Regular.ttf` (400)
   - `IBMPlexSansArabic-Medium.ttf` (500)
   - `IBMPlexSansArabic-SemiBold.ttf` (600)
   - `IBMPlexSansArabic-Bold.ttf` (700)
3. أضف الـ block ده تحت `flutter:` في `pubspec.yaml` (بعد `uses-material-design: true`):

```yaml
  fonts:
    - family: IBM Plex Sans Arabic
      fonts:
        - asset: assets/fonts/IBMPlexSansArabic-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexSansArabic-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexSansArabic-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexSansArabic-Bold.ttf
          weight: 700
```

4. شغّل `flutter pub get`.

**ماتضيفش الـ block قبل ما الملفات تبقى موجودة**: `flutter test` و`flutter build` بيفشلوا لو الـ asset مش لاقيه.
