# GitHub Actions Workflow

## توليد مشروع Xcode تلقائياً

هذا الـ workflow مسؤول عن توليد ملف مشروع Xcode (`.xcodeproj`) تلقائياً من ملف `project.yml` باستخدام XcodeGen.

### متى يعمل؟

يتم تشغيل الـ workflow في الحالات التالية:
- عند الـ push لتغييرات في `project.yml`
- عند الـ push لتغييرات في ملف الـ workflow نفسه
- عند إنشاء pull request يتضمن تغييرات في الملفات السابقة

### ماذا يفعل؟

1. يستخدم بيئة macOS (لأن XcodeGen لا يعمل على أنظمة أخرى)
2. يثبت XcodeGen باستخدام Homebrew
3. يولد ملف المشروع في مجلد `HarfChallengeKeyboard`
4. يحفظ الملف المولد كـ artifact
5. يضيف الملف المولد للـ repository

### ملاحظات هامة

- لا يقوم الـ workflow ببناء المشروع أو توقيعه
- يتم تجاهل ملفات المستخدم الخاصة بـ Xcode في .gitignore
- يمكن تحميل ملف المشروع المولد من صفحة الـ Actions 