#!/bin/bash

# 🛡️ Tactical Build Script for Vercel

# 1. Acquire Flutter Intelligence
if [ ! -d "$HOME/flutter" ]; then
  echo "📡 Downloading Flutter Sector Assets..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
fi

# 2. Establish Command Environment
export PATH="$PATH:$HOME/flutter/bin"

# 3. Synchronize Dependencies
echo "📡 Synchronizing Battalion Dependencies..."
flutter pub get

# 4. Ensure .env exists for Web build
if [ ! -f ".env" ]; then
  echo "🔑 Generating default .env for Web Build..."
  touch .env
  echo "SUPABASE_URL=${SUPABASE_URL:-https://kuttseqqxdfqbzekgqll.supabase.co}" >> .env
  echo "SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-sb_publishable_2x-gJ3yNhM9yooDcEdeuWA_HQ379KgN}" >> .env
  echo "GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID:-441617106864-usssvc74qg415dg5rdn5qnev5hmfbh3v.apps.googleusercontent.com}" >> .env
fi

# 5. Generate Web Distribution
echo "🚀 Building Web Terminal..."
flutter build web --release --no-wasm-dry-run

