#compdef tailscale

# Doesn't work very well
# https://gist.github.com/SulimanLab/28de6b246144ed722e861f1c7c2a8d33

_cli_zsh_autocomplete() {
	local -a opts
	local cur last_word FLAGS

	local wordsLen=${#words}

	for (( i=${#words[@]}; i>=1; i-- )); do
		if [[ -n "${words[i]}" ]]; then
			cur="${words[i]}"
			break
		fi
	done

	if [[ "$wordsLen" -eq 2 ]]; then
        # Run 'tailscale --help' and capture stdout
        help_output=$(tailscale --help 2>&1)

        # Use awk to extract commands and descriptions
        commands_with_descriptions=$(echo "$help_output" | awk '/SUBCOMMANDS/{ f = 1; next } /FLAGS/{ f = 0 } f && $1{ print $1 ":" $0 }')
        command_descriptions=("${(@f)commands_with_descriptions}")

        FLAGS=("-h" "--help" "--socket:path to tailscaled's unix socket (default /var/run/tailscale/tailscaled.sock)")
        _describe 'command_with_description' command_descriptions -- FLAGS

	elif [[ "$wordsLen" -eq 3 ]]; then

	    case "$cur" in
                    ssh|ping)
                        _cli_complete_ip_addresses
                        return
                        ;;
                esac

	fi

	return 1
}

# Custom completion function for IP addresses with descriptions
_cli_complete_ip_addresses() {
    # Run 'tailscale status' and capture the output
    local output
    output=$(tailscale status 2>&1)

    # Use awk to extract IP addresses and descriptions from the output
    local ips_with_descriptions
    ips_with_descriptions=($(echo "$output" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/{if($1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $1 ":" $2}'))
    ips_with_descriptions=(${(@f)ips_with_descriptions:#'\t'})

    # Format IP addresses with descriptions in the same way as commands and descriptions
    local ip_description_list
    for ip_desc_pair in $ips_with_descriptions; do
        echo $ip_desc_pair \n
        ip_description_list+=("$ip_desc_pair")
    done

    # Use _describe to display IP addresses with descriptions
    _describe "IP addresses with descriptions" ip_description_list
}
compdef _cli_zsh_autocomplete tailscale
