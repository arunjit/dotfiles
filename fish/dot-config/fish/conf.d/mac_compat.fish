# Compatibility layer ensuring macOS muscle memory and conventions work on Linux
if test (uname) = "Linux"
    # Bat fallback: Debian / Ubuntu / Raspberry Pi OS packages bat as batcat
    if not type -q bat; and type -q batcat
        alias bat=batcat
    end

    # Fd fallback: Debian / Ubuntu / Raspberry Pi OS packages fd as fdfind
    if not type -q fd; and type -q fdfind
        alias fd=fdfind
    end

    # macOS 'open' command mapping (xdg-open on Linux)
    # Note: On some minimal Linux systems, 'open' is an alias or link to openvt
    if not type -q open; or test (type -p open 2>/dev/null) = "/bin/open" -a -e /bin/openvt
        if type -q xdg-open
            alias open=xdg-open
        end
    end

    # macOS clipboard commands (pbcopy / pbpaste)
    if not type -q pbcopy
        if type -q wl-copy
            alias pbcopy=wl-copy
            alias pbpaste=wl-paste
        else if type -q xclip
            alias pbcopy="xclip -selection clipboard"
            alias pbpaste="xclip -selection clipboard -o"
        else if type -q xsel
            alias pbcopy="xsel --clipboard --input"
            alias pbpaste="xsel --clipboard --output"
        end
    end
end
