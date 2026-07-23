# Homebrew formula for lidwatch
# To use: set up a Homebrew tap repository (homebrew-lidwatch) containing this file
# as Formula/lidwatch.rb, then: brew tap Maxusmusti/lidwatch && brew install lidwatch
#
# After each release, update the `url` tag version and `sha256` with:
#   shasum -a 256 v<VERSION>.tar.gz

class Lidwatch < Formula
  desc "Keep your Mac awake while AI agents run"
  homepage "https://github.com/Maxusmusti/lidwatch"
  url "https://github.com/Maxusmusti/lidwatch/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  version "0.1.0"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/lidwatch"
  end

  test do
    assert_match "lidwatch", shell_output("#{bin}/lidwatch --help")
  end
end
