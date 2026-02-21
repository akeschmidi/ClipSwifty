cask "clipswifty" do
  version "1.4.1"
  sha256 "cc78a1d3165dd586e1d872304fbd5e8f96dc91dbdab29562c95f8dd5f26dbe9e"

  url "https://github.com/akeschmidi/ClipSwifty/releases/download/v#{version}/ClipSwifty.zip"
  name "ClipSwifty"
  desc "Lightweight video and audio downloader for macOS"
  homepage "https://github.com/akeschmidi/ClipSwifty"

  depends_on macos: ">= :sonoma"

  app "ClipSwifty.app"

  zap trash: [
    "~/Library/Preferences/at.stefanschwinghammer.ClipSwifty.plist",
    "~/Library/Application Support/ClipSwifty",
  ]
end
