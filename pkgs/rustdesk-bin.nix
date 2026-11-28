{
  appimageTools,
  fetchurl,
}:
let
  pname = "rustdesk";
  version = "1.5.0";
  src = fetchurl {
    url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.AppImage";
    hash = "sha256-Qi67kVtMcJ81Ec+ilBq879yx09YPZz9aIM+IpKssmqU=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm644 "${contents}/rustdesk.desktop" "$out/share/applications/rustdesk.desktop"
    cp -r "${contents}/usr/share/icons" "$out/share/icons"
  '';
  meta.mainProgram = "rustdesk";
  meta.platforms = [ "x86_64-linux" ];
}
