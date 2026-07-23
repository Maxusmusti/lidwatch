# Homebrew formula for lidwatch
# To use: set up a Homebrew tap repository (homebrew-lidwatch) containing this file
# as Formula/lidwatch.rb, then: brew tap meyceoz/lidwatch && brew install lidwatch
#
# After each release, update the `url` tag version and `sha256` with:
#   shasum -a 256 lidwatch-<VERSION>-arm64-macos.tar.gz

class Lidwatch < Formula
  desc "Prevent macOS idle sleep while AI coding agents are running"
  homepage "https://github.com/meyceoz/way-safely-close-mac"
  url "https://github.com/meyceoz/way-safely-close-mac/releases/download/v0.1.0/lidwatch-0.1.0-arm64-macos.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on arch: :arm64

  def install
    bin.install "lidwatch"
  end

  test do
    assert_match "lidwatch", shell_output("#{bin}/lidwatch --help")
  end
end
