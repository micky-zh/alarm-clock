#!/bin/bash
set -e

# Define directories
WORKSPACE_DIR="/Users/zhengfan/work/airplane"
APP_NAME="飞机闹钟"
APP_DIR="${WORKSPACE_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MAC_OS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "⚙️ 1. 编译最新的 Release 生产包..."
swift build -c release

echo "📂 2. 创建 macOS .app 目录结构..."
# Clean old app package if exists
rm -rf "${APP_DIR}"
mkdir -p "${MAC_OS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "🚀 3. 复制可执行文件到 .app 中..."
cp "${WORKSPACE_DIR}/.build/release/airplane" "${MAC_OS_DIR}/${APP_NAME}"

echo "🔧 4. 写入 Info.plist 配置文件..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.airplane.alarm</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "🎨 5. 生成精美的 3D 小飞机软件图标..."
ICONSET_DIR="${WORKSPACE_DIR}/AppIcon.iconset"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

# Create icons of multiple sizes from the original PNG
sips -z 16 16     "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
sips -z 32 32     "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
sips -z 64 64     "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
sips -z 256 256   "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
sips -z 512 512   "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
sips -z 1024 1024 "${WORKSPACE_DIR}/cute_airplane.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null

# Compile iconset directory into a single AppIcon.icns
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
rm -rf "${ICONSET_DIR}"

echo "🚚 6. 将打包好的【飞机闹钟.app】复制到您的桌面上..."
cp -R "${APP_DIR}" ~/Desktop/

echo "✅ 打包完成！桌面上的【飞机闹钟.app】已可以使用。"
