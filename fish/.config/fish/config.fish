if status is-interactive
    # Commands to run in interactive sessions can go here
    # Configure auto-attach/exit to your likings (default is off).
    # set ZELLIJ_AUTO_ATTACH true
    # set ZELLIJ_AUTO_EXIT false
    #
    # if not set -q ZELLIJ
    #     if test "$ZELLIJ_AUTO_ATTACH" = true
    #         zellij attach -c main
    #     else
    #         zellij
    #     end
    #
    #     if test "$ZELLIJ_AUTO_EXIT" = true
    #         kill $fish_pid
    #     end
    # end

    set -g fish_greeting
    # starship init fish | source
    zoxide init fish --cmd cd | source
    fzf --fish | source
    # direnv hook fish | source
end
