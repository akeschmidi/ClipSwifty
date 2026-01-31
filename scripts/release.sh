#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/ClipSwifty.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
APP_NAME="ClipSwifty"
TEAM_ID="34DTFQCK2V"
NOTARYTOOL_PROFILE="notarytool-profile"

# Get version from argument or prompt
VERSION=${1:-""}
if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}Enter version number (e.g., 1.2.0):${NC}"
    read VERSION
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: Version number required${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 Building ClipSwifty v$VERSION${NC}"
echo "=================================="

# Clean build directory
echo -e "${YELLOW}📁 Cleaning build directory...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Archive
echo -e "${YELLOW}📦 Creating archive...${NC}"
xcodebuild -project "$PROJECT_DIR/ClipSwifty.xcodeproj" \
    -scheme ClipSwifty \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    | grep -E "(error:|warning:|ARCHIVE)" || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Archive created${NC}"

# Create export options plist
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

# Export
echo -e "${YELLOW}📤 Exporting app...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    | grep -E "(error:|warning:|EXPORT)" || true

if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    echo -e "${RED}❌ Export failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ App exported${NC}"

# Create ZIP for notarization
echo -e "${YELLOW}🗜️  Creating ZIP...${NC}"
cd "$EXPORT_PATH"
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"
echo -e "${GREEN}✅ ZIP created${NC}"

# Notarize
echo -e "${YELLOW}📝 Notarizing (this may take a few minutes)...${NC}"
if xcrun notarytool submit "$EXPORT_PATH/$APP_NAME.zip" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait; then
    echo -e "${GREEN}✅ Notarization successful${NC}"

    # Staple the notarization ticket
    echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
    xcrun stapler staple "$EXPORT_PATH/$APP_NAME.app"

    # Recreate ZIP with stapled app
    rm "$EXPORT_PATH/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"
    echo -e "${GREEN}✅ Stapled ZIP created${NC}"
else
    echo -e "${YELLOW}⚠️  Notarization failed or profile not found${NC}"
    echo -e "${YELLOW}   App is signed but not notarized${NC}"
fi

# Create GitHub release
echo -e "${YELLOW}🏷️  Creating GitHub release v$VERSION...${NC}"
cd "$PROJECT_DIR"

# Check if tag already exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Tag v$VERSION already exists, deleting...${NC}"
    git tag -d "v$VERSION" || true
    git push origin --delete "v$VERSION" 2>/dev/null || true
fi

gh release create "v$VERSION" "$EXPORT_PATH/$APP_NAME.zip" \
    --title "ClipSwifty v$VERSION" \
    --generate-notes

echo ""
echo -e "${GREEN}=================================="
echo -e "🎉 Release v$VERSION complete!"
echo -e "==================================${NC}"
echo ""
echo "Release URL: https://github.com/akeschmidi/ClipSwifty/releases/tag/v$VERSION"
