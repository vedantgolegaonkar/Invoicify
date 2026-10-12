#!/bin/bash

echo "🛑 Stopping any stuck Flutter processes..."
pkill -x "flutter" 2>/dev/null || true
pkill -x "dart" 2>/dev/null || true

# echo "🧹 Cleaning Flutter build..."
# flutter clean 

echo " "
echo "📦 Getting dependencies..."
flutter pub get

echo " "
echo "🚀 Running Flutter app..."
echo "Get Ready to Explore the Application..."
flutter run
