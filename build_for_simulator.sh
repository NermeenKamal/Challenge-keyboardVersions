#!/bin/bash

# سكريبت بناء تطبيق لعبة تحدي الحروف للـ Simulator
# Build script for Harf Challenge Keyboard App for iOS Simulator

echo "🎮 بدء بناء تطبيق لعبة تحدي الحروف..."
echo "=================================="

# تنظيف المشروع
echo "🧹 تنظيف المشروع..."
xcodebuild clean -project HarfChallengeKeyboard.xcodeproj -scheme HarfChallengeKeyboardApp -configuration Debug

# بناء التطبيق للـ Simulator
echo "🔨 بناء التطبيق للـ Simulator..."
xcodebuild build -project HarfChallengeKeyboard.xcodeproj -scheme HarfChallengeKeyboardApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'

# البحث عن ملف .app
echo "🔍 البحث عن ملف التطبيق..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "HarfChallengeKeyboardApp.app" -type d | head -1)

if [ -n "$APP_PATH" ]; then
    echo "✅ تم العثور على التطبيق في: $APP_PATH"
    
    # إنشاء مجلد للتوزيع
    DIST_FOLDER="HarfChallengeKeyboardApp_Simulator"
    mkdir -p "$DIST_FOLDER"
    
    # نسخ التطبيق
    cp -R "$APP_PATH" "$DIST_FOLDER/"
    
    # نسخ README
    cp README.md "$DIST_FOLDER/"
    
    echo "📦 تم إنشاء حزمة التطبيق في مجلد: $DIST_FOLDER"
    echo "🚀 يمكنك الآن فتح المجلد واختبار التطبيق على Simulator"
    echo ""
    echo "📋 للاختبار:"
    echo "1. افتح Xcode"
    echo "2. اختر iOS Simulator"
    echo "3. اسحب ملف HarfChallengeKeyboardApp.app إلى Simulator"
    echo "4. استمتع باللعبة! 🎉"
    
else
    echo "❌ لم يتم العثور على ملف التطبيق"
    echo "🔧 تأكد من:"
    echo "   - وجود Xcode محدث"
    echo "   - صحة إعدادات المشروع"
    echo "   - عدم وجود أخطاء في البناء"
fi

echo ""
echo "🏁 انتهى البناء!" 