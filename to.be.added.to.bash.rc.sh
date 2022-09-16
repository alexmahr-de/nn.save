# given that `history` is a shell builtin nn.save is better implemented as a 
# bash shell function as this way calling `history` can be used to also get the most 
# recent history items

#initial setup to be run as root uid=0
test -d "bin/nn.scripts" || {
    # create the necessary directory to be appended to $PATH 
    # this /bin/nn.scripts directory serves the purpose that 
    # only root can write files into it, so once added to $PATH
    # only links created by the proxy shell script /usr/bin/nn.save.link
    # will be able to sudo (NOPASSWD) elevate rights to uid=0
    # and make sure that no user can abuse this
    sudo mkdir -p "/bin/nn.scripts"
    sudo chmod 0755 "/bin/nn.scripts"
    
    #generate the proxy shellscript
    cat | sudo tee /usr/bin/nn.save.link << 'EOF'
#!/bin/bash

set -euo pipefail
read -t 1 FILE || exit 1
FILE="$(realpath "$FILE")"
test -f "$FILE" || exit 2
test -x "$FILE" || exit 3
cd /usr/bin/nn.scripts
ln -s "$FILE" "nn.$(basename "$FILE" | tail -c+4)"
EOF

    sudo chmod 0500 /usr/bin/nn.save.link
    echo 'ALL ALL=(ALL) NOPASSWD: /usr/bin/nn.save.link' | sudo tee -a /etc/sudoers
}


#
nn.save() {
    local SCRIPTNAME
    local LINKNAME
    local NNSCRIPTDIR
    local LAST
    local LINE
    local BUFFER
    local BUFFERHEAD
    loca HISTTIMEFORMAT='%y/%m/%d - %T> '
    SCRIPTNAME="$1"
    test -n "$SCRIPTNAME" || { echo "usage: $0 <scriptname>" >&2; return 1; }
    LINKNAME="/bin/nn.scripts/nn.${SCRIPTNAME///}"
    test -e "$LINKNAME" && { echo "error duplicate name $1 file $LINKNAME exits" >&2 ; return 2; }
    NNSCRIPTDIR="${HOME:-.}/nn.scripts";
    mkdir -p "$NNSCRIPTDIR"
    SCRIPTNAME="$NNSCRIPTDIR/nn.${SCRIPTNAME///}"
    echo "creating script at $SCRIPTNAME" >&2 ;
    {
        BUFFERHEAD="$(printf '#!/bin/bash\n'"## created on $(date -Iseconds)\n## by $USER \n## at $(pwd)\n\n" | tee "$SCRIPTNAME")"
        chmod u+x "$SCRIPTNAME"
        echo "$SCRIPTNAME" | sudo nn.save.link
        {
            printf '!/bin/bash\n\n'
            LAST=2
            while true
            do
                LINE="$(history $LAST | head -n 1 )"
                printf "include[Y/n]? ($LAST) >%s\n"  "${LINE#*>}" >&2;
                read -e YESADDTHISLINE || break
                test "n" != "$YESADDTHISLINE" && {
                    BUFFER="$(printf '#%s\n%s\n' "${LINE%>*}" "$BUFFER")"
                    BUFFER="$(printf '%s\n%s\n' "${LINE#*> }" "$BUFFER")"
                    {
                        echo "$BUFFERHEAD";
                        echo "$BUFFER";
                    } > "$SCRIPTNAME"
                }
                LAST=$(($LAST+1))
            done
        }
    }
}
