# Websites as Chrome app windows with their own launcher entries.
{ lib, ... }:
let
  webapps = {
    Gmail = "https://gmail.com";
    Calendar = "https://calendar.google.com/";
    "Google Contacts" = "https://contacts.google.com/";
    "Google Maps" = "https://maps.google.com";
    "Google Messages" = "https://messages.google.com/web/conversations";
    "Google Photos" = "https://photos.google.com/";
    WhatsApp = "https://web.whatsapp.com/";
    ChatGPT = "https://chatgpt.com/";
    Gemini = "https://gemini.google.com/";
    Perplexity = "https://perplexity.ai";
    GitHub = "https://github.com/";
    YouTube = "https://youtube.com/";
    "YouTube Music" = "https://music.youtube.com/";
    X = "https://x.com/";
    Substack = "https://substack.com";
    Bandcamp = "https://bandcamp.com";
    Polymarket = "https://polymarket.com";
    HyperLiquid = "https://app.hyperliquid.xyz/trade";
    HydraHD = "https://hydrahd.org";
    Linkwarden = "https://links.m19182.dev/";
    Medialib = "https://medialib.m19182.dev/";
    Navidrome = "https://navidrome.m19182.dev/";
    Syncthing = "http://127.0.0.1:8384/";
  };
in
{
  xdg.desktopEntries = lib.mapAttrs' (
    name: url:
    let
      slug = lib.toLower (lib.replaceStrings [ " " ] [ "-" ] name);
      png = ../webapps/icons + "/${slug}.png";
    in
    lib.nameValuePair "webapp-${slug}" {
      inherit name;
      exec = ''google-chrome-stable --app="${url}" --profile-directory=Default'';
      icon = if builtins.pathExists png then png else "web-browser";
      terminal = false;
      categories = [ "Network" ];
    }
  ) webapps;
}
