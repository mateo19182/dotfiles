{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  autoAddDriverRunpath,
  makeWrapper,
  alsa-lib,
  alsa-plugins,
  curl,
  ffmpeg-headless,
  fontconfig,
  libva,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  openblas,
  openssl,
  pipewire,
  symlinkJoin,
  vulkan-loader,
  wayland,
  wl-clipboard,
  wtype,
  xdg-utils,
}:
let
  alsaPlugins = symlinkJoin {
    name = "hex-alsa-plugins";
    paths = [
      "${pipewire}/lib/alsa-lib"
      "${alsa-plugins}/lib/alsa-lib"
    ];
  };
  runtimeLibraries = [
    alsa-lib
    fontconfig
    libva
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    openblas
    openssl
    pipewire
    vulkan-loader
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hex-bin";
  version = "3.5.2";

  src = fetchurl {
    url = "https://github.com/anomalyco/hex/releases/download/v${finalAttrs.version}/hex-${finalAttrs.version}-linux-x64.deb";
    hash = "sha256-eFy1ArtVaGXNptqe7LQaUvUHNOzvPfvemRVfd21/NGI=";
  };

  nativeBuildInputs = [
    autoAddDriverRunpath
    autoPatchelfHook
    dpkg
    makeWrapper
  ];
  buildInputs = runtimeLibraries ++ [ stdenv.cc.cc.lib ];
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 usr/bin/hex "$out/bin/hex"
    cp -r usr/share "$out/share"
    substituteInPlace "$out/share/applications/anomaly.hex.desktop" \
      --replace-fail /usr/bin/hex "$out/bin/hex"
    runHook postInstall
  '';

  # Hex loads some audio and display libraries at runtime.
  postFixup = ''
    wrapProgram "$out/bin/hex" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibraries} \
      --set ALSA_PLUGIN_DIR ${alsaPlugins} \
      --prefix PATH : ${lib.makeBinPath [ curl ffmpeg-headless wl-clipboard wtype xdg-utils ]}
  '';

  meta.mainProgram = "hex";
  meta.platforms = [ "x86_64-linux" ];
})
