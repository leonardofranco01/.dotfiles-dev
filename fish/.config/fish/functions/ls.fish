function ls --wraps='eza -a --hyperlink --icons=always --group-directories-first' --wraps='eza -a --hyperlink --icons=always --group-directories-first' --description 'alias ls=eza -a --hyperlink --icons=always --group-directories-first'
    eza -a --hyperlink --icons=always --group-directories-first $argv
end
