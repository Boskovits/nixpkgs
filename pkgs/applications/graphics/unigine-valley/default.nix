{ stdenv, fetchurl

# Build-time dependencies
, makeWrapper
, file

# Runtime dependencies
, fontconfig
, freetype
, libX11
, libXext
, libXinerama
, libXrandr
, libXrender
, openal}:

let
  version = "1.0";
  pkgversion = "1";

  arch = if stdenv.system == "x86_64-linux" then
    "x64"
  else if stdenv.system == "i686-linux" then
    "x86"
  else
    abort "Unsupported platform";

in
  stdenv.mkDerivation {
    name = "unigine-valley-${version}-${pkgversion}";

    src = fetchurl {
      url = "http://assets.unigine.com/d/Unigine_Valley-${version}.run";
      sha256 = "5f0c8bd2431118551182babbf5f1c20fb14e7a40789697240dcaf546443660f4";
    };

    sourceRoot = "Unigine_Valley-${version}";

    buildInputs = [file makeWrapper];

    libPath = stdenv.lib.makeLibraryPath [
      stdenv.cc.cc  # libstdc++.so.6
      fontconfig
      freetype
      libX11
      libXext
      libXinerama
      libXrandr
      libXrender
      openal
    ];

    unpackPhase = ''
      cp $src extractor.run
      chmod +x extractor.run
      ./extractor.run --target $sourceRoot
    '';

    # The executable loads libGPUMonitor_${arch}.so "manually" (i.e. not through the ELF interpreter).
    # However, it still uses the RPATH to look for it.
    patchPhase = ''
      # Patch ELF files.
      elfs=$(find bin -type f | xargs file | grep ELF | cut -d ':' -f 1)
      for elf in $elfs; do
        echo "Patching $elf"
        patchelf --set-interpreter ${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2 $elf || true
      done
    '';

    configurePhase = "";
    buildPhase = "";

    installPhase = ''
      instdir=$out/opt/unigine/valley

      # Install executables and libraries
      mkdir -p $instdir/bin
      install -m 0755 bin/browser_${arch} $instdir/bin
      install -m 0755 bin/libApp{Stereo,Surround,Wall}_${arch}.so $instdir/bin
      install -m 0755 bin/libGPUMonitor_${arch}.so $instdir/bin
      install -m 0755 bin/libQt{Core,Gui,Network,WebKit,Xml}Unigine_${arch}.so.4 $instdir/bin
      install -m 0755 bin/libUnigine_${arch}.so $instdir/bin
      install -m 0755 bin/valley_${arch} $instdir/bin
      install -m 0755 valley $instdir

      # Install other files
      cp -R data documentation $instdir

      # Install and wrap executable
      mkdir -p $out/bin
      install -m 0755 valley $out/bin/valley
      wrapProgram $out/bin/valley \
        --run "cd $instdir" \
        --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:$instdir/bin:$libPath
    '';

    meta = {
      description = "The Unigine Valley GPU benchmarking tool";
      homepage = "http://unigine.com/products/benchmarks/valley/";
      license = stdenv.lib.licenses.unfree; # see also: /nix/store/*-unigine-valley-1.0/opt/unigine/valley/documentation/License.pdf
      maintainers = [ stdenv.lib.maintainers.kierdavis ];
      platforms = ["x86_64-linux" "i686-linux"];
    };
  }
