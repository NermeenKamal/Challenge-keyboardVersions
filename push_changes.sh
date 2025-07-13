#!/bin/bash
echo "🚀 بدء رفع التعديلات..."

echo "📦 إضافة الملفات..."
git add .

echo "💾 إنشاء commit..."
git commit -m "fix: تبسيط التطبيق الكامل لحل خطأ 500

- تقليل iOS target إلى 14.0
- تحديث Swift إلى 5.9  
- إزالة keyboard extension مؤقتاً
- تبسيط التطبيق إلى الحد الأدنى
- تبسيط LaunchScreen
- تبسيط Info.plist"

echo "📤 رفع إلى GitHub..."
git push origin cursor/fix-duplicate-preview-issue-80b3

echo "✅ تم بنجاح!"