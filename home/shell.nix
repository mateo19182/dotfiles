{ ... }:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [
      "erasedups"
      "ignorespace"
    ];
    historySize = 100000;
    historyFileSize = 100000;
    shellOptions = [
      "histappend"
      "checkwinsize"
      "globstar"
    ];

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lsa = "ls -a";
      lt = "eza --tree --level=2 --long --icons --git";
      cat = "bat --paging=never --style=plain";
      g = "git";
      n = "nvim";
      clauded = "claude --dangerously-skip-permissions";
      rebuild = "nh os switch";
      update = "nh os switch --update";
    };

    initExtra = ''
      # Secrets stay out of git: DD_API_KEY, DD_APP_KEY, tokens...
      [ -f "$HOME/.config/secrets.env" ] && set -a && . "$HOME/.config/secrets.env" && set +a

      export DD_SITE="datadoghq.eu"

      # AWS profile switcher. Usage:
      #   awsp              # list profiles + show active
      #   awsp zepord       # switch; auto-runs sso login if needed
      #   awsp -            # unset everything (no profile, no static creds)
      awsp() {
        if [ -z "$1" ]; then
          aws configure list-profiles
          echo "active: ''${AWS_PROFILE:-<default>}"
          return
        fi
        if [ "$1" = "-" ]; then
          unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
          echo "cleared"
          return
        fi
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
        export AWS_PROFILE="$1"
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
          aws sso login --profile "$1" || return 1
        fi
        aws sts get-caller-identity
      }
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
}
