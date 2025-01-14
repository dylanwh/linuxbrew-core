class Go < Formula
  desc "Open source programming language to build simple/reliable/efficient software"
  homepage "https://golang.org"

  stable do
    url "https://dl.google.com/go/go1.12.6.src.tar.gz"
    mirror "https://fossies.org/linux/misc/go1.12.6.src.tar.gz"
    sha256 "c96c5ccc7455638ae1a8b7498a030fe653731c8391c5f8e79590bce72f92b4ca"

    go_version = version.to_s.split(".")[0..1].join(".")
    resource "gotools" do
      url "https://go.googlesource.com/tools.git",
          :branch => "release-branch.go#{go_version}"
    end
  end

  bottle do
    rebuild 2
    sha256 "5f1d8b917ac235ddd2c26526047a945e1cc103b531ebd5657c13e2681c027288" => :mojave
    sha256 "97c3b9448b5f597593b0405166e127da3ac25b62b60ac3458d459577b527b478" => :high_sierra
    sha256 "e56f6d6285412561bcd26920dd3097a81eb148f2fffb108e168112320bf1cfd2" => :sierra
    sha256 "00bb96dbd7908adc3d11452ea62604992855534ac0d7c631d01b561a585f7f45" => :x86_64_linux
  end

  head do
    url "https://go.googlesource.com/go.git"

    resource "gotools" do
      url "https://go.googlesource.com/tools.git"
    end
  end

  depends_on :macos => :yosemite

  # Don't update this unless this version cannot bootstrap the new version.
  resource "gobootstrap" do
    if OS.mac?
      url "https://storage.googleapis.com/golang/go1.7.darwin-amd64.tar.gz"
      sha256 "51d905e0b43b3d0ed41aaf23e19001ab4bc3f96c3ca134b48f7892485fc52961"
      version "1.7"
    elsif OS.linux?
      if Hardware::CPU.intel?
        url "https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz"
        sha256 "702ad90f705365227e902b42d91dd1a40e48ca7f67a2f4b2fd052aaa4295cd95"
        version "1.7"
      elsif Hardware::CPU.arm?
        url "https://raw.githubusercontent.com/tgogos/rpi_golang/master/go1.4.3.linux-armv7.tar.gz"
        sha256 "dc1f98ca1b5476f4cf4d5e41df265a69b6fc8ede5664fb5c227d9ca5ed1720ce"
        version "1.4"
      end
    end
  end

  # Prevents Go from building malformed binaries. Fixed upstream, should
  # be in a future release.
  # https://github.com/golang/go/issues/32673
  patch do
    url "https://github.com/golang/go/commit/26954bde4443c4bfbfe7608f35584b6b810f3f2c.patch?full_index=1"
    sha256 "25a361bd4aa1155be06e2239c1974aa9c59f971210f19e16a3b7b576b9d4f677"
  end

  patch do
    url "https://github.com/golang/go/commit/0fe1986a72ea578390d4909988a1d7cb3a687544.patch?full_index=1"
    sha256 "320c11208313fc74e0bba7f323791416e5316451b109c440f56be361df8306ea"
  end

  patch do
    url "https://github.com/golang/go/commit/3f1422c799edb143303c86c0e875d44c3612df64.patch?full_index=1"
    sha256 "d071f0415cd2712cbed373682c4a84661147df1aabf38bbc0f3179532a988a4f"
  end

  def install
    # Fixes: Error: Failure while executing: ../bin/ldd ../line-clang.elf: Permission denied
    unless OS.mac?
      chmod "+x", Dir.glob("src/debug/dwarf/testdata/*.elf")
      chmod "+x", Dir.glob("src/debug/elf/testdata/*-exec")
    end

    (buildpath/"gobootstrap").install resource("gobootstrap")
    ENV["GOROOT_BOOTSTRAP"] = buildpath/"gobootstrap"

    cd "src" do
      ENV["GOROOT_FINAL"] = libexec
      ENV["GOOS"]         = OS.mac? ? "darwin" : "linux"
      system "./make.bash", "--no-clean"
    end

    (buildpath/"pkg/obj").rmtree
    rm_rf "gobootstrap" # Bootstrap not required beyond compile.
    libexec.install Dir["*"]
    bin.install_symlink Dir[libexec/"bin/go*"]

    # technically -race is ok on arm64
    if Hardware::CPU.arm?
      system bin/"go", "install", "std"
    else
      system bin/"go", "install", "-race", "std"
    end

    # Build and install godoc
    ENV.prepend_path "PATH", bin
    ENV["GO111MODULE"] = "on"
    ENV["GOPATH"] = buildpath
    (buildpath/"src/golang.org/x/tools").install resource("gotools")
    cd "src/golang.org/x/tools/cmd/godoc/" do
      system "go", "build"
      (libexec/"bin").install "godoc"
    end
    bin.install_symlink libexec/"bin/godoc"
  end

  test do
    (testpath/"hello.go").write <<~EOS
      package main

      import "fmt"

      func main() {
          fmt.Println("Hello World")
      }
    EOS
    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system bin/"go", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")

    # godoc was installed
    assert_predicate libexec/"bin/godoc", :exist?
    assert_predicate libexec/"bin/godoc", :executable?

    ENV["GOOS"] = "freebsd"
    system bin/"go", "build", "hello.go"
  end
end
