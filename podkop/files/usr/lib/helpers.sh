# Check if string is valid IPv4
is_ipv4() {
    local ip="$1"
    local regex="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$"
    [[ "$ip" =~ $regex ]]
}

# Check if string is valid IPv4 with CIDR mask
is_ipv4_cidr() {
    local ip="$1"
    local regex="^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}(\/(3[0-2]|2[0-9]|1[0-9]|[0-9]))$"
    [[ "$ip" =~ $regex ]]
}

is_ipv4_ip_or_ipv4_cidr() {
    is_ipv4 "$1" || is_ipv4_cidr "$1"
}

is_domain() {
    local str="$1"
    local regex='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$'

    [[ "$str" =~ $regex ]]
}

is_domain_suffix() {
    local str="$1"
    local normalized="${str#.}"

    is_domain "$normalized"
}

# Checks if the given string is a valid base64-encoded sequence
is_base64() {
    local str="$1"

    if echo "$str" | base64 -d > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Checks if the given string looks like a Shadowsocks userinfo
is_shadowsocks_userinfo_format() {
    local str="$1"
    local regex='^[^:]+:[^:]+(:[^:]+)?$'

    [[ "$str" =~ $regex ]]
}

# Compares the current package version with the required minimum
is_min_package_version() {
    local current="$1"
    local required="$2"

    local lowest
    lowest="$(printf '%s\n' "$current" "$required" | sort -V | head -n1)"

    [ "$lowest" = "$required" ]
}

# Checks if the given file exists
file_exists() {
    local filepath="$1"

    if [[ -f "$filepath" ]]; then
        return 0
    else
        return 1
    fi
}

# Checks if a service script exists in /etc/init.d
service_exists() {
    local service="$1"

    if [ -x "/etc/init.d/$service" ]; then
        return 0
    else
        return 1
    fi
}

# Returns the inbound tag name by appending the postfix to the given section
get_inbound_tag_by_section() {
    local section="$1"
    local postfix="in"

    echo "$section-$postfix"
}

# Returns the outbound tag name by appending the postfix to the given section
get_outbound_tag_by_section() {
    local section="$1"
    local postfix="out"

    echo "$section-$postfix"
}

# Constructs and returns a domain resolver tag by appending a fixed postfix to the given section
get_domain_resolver_tag() {
    local section="$1"
    local postfix="domain-resolver"

    echo "$section-$postfix"
}

# Converts a comma-separated string into a JSON array string
comma_string_to_json_array() {
    local input="$1"

    if [ -z "$input" ]; then
        echo "[]"
        return
    fi

    local replaced="${input//,/\",\"}"

    echo "[\"$replaced\"]"
}

# Decodes a URL-encoded string
url_decode() {
    local encoded="$1"
    printf '%b' "$(echo "$encoded" | sed 's/+/ /g; s/%/\\x/g')"
}

# Returns the scheme (protocol) part of a URL
url_get_scheme() {
    local url="$1"
    echo "${url%%://*}"
}

# Extracts the userinfo (username[:password]) part from a URL
url_get_userinfo() {
    local url="$1"
    echo "$url" | sed -n -e 's#^[^:/?]*://##' -e '/@/!d' -e 's/@.*//p'
}

# Extracts the host part from a URL
url_get_host() {
    local url="$1"

    url="${url#*://}"
    url="${url#*@}"
    url="${url%%[/?#]*}"

    echo "${url%%:*}"
}

# Extracts the port number from a URL
url_get_port() {
    local url="$1"

    url="${url#*://}"
    url="${url#*@}"
    url="${url%%[/?#]*}"

    [[ "$url" == *:* ]] && echo "${url#*:}" || echo ""
}

# Extracts the path from a URL (without query or fragment; returns "/" if empty)
url_get_path() {
    local url="$1"
    echo "$url" | sed -n -e 's#^[^:/?]*://##' -e 's#^[^/]*##' -e 's#\([^?]*\).*#\1#p'
}

# Extracts the value of a specific query parameter from a URL
url_get_query_param() {
    local url="$1"
    local param="$2"

    local raw
    raw=$(echo "$url" | sed -n "s/.*[?&]$param=\([^&?#]*\).*/\1/p")

    [ -z "$raw" ] && echo "" && return

    echo "$raw"
}

# Extracts the basename (filename without extension) from a URL
url_get_basename() {
    local url="$1"

    local filename="${url##*/}"
    local basename="${filename%%.*}"

    echo "$basename"
}

# Extracts and returns the file extension from the given URL
url_get_file_extension() {
    local url="$1"

    local basename="${url##*/}"
    case "$basename" in
    *.*) echo "${basename##*.}" ;;
    *) echo "" ;;
    esac
}

# Remove url fragment (everything after the first '#')
url_strip_fragment() {
    local url="$1"

    echo "${url%%#*}"
}

# Decodes and returns a base64-encoded string
base64_decode() {
    local str="$1"
    local decoded_url

    decoded_url="$(echo "$str" | base64 -d 2> /dev/null)"

    echo "$decoded_url"
}

# Generates a unique 16-character ID based on the current timestamp and a random number
gen_id() {
    printf '%s%s' "$(date +%s)" "$RANDOM" | md5sum | cut -c1-16
}

# Adds a missing UCI option with the given value if it does not exist
migration_add_new_option() {
    local package="$1"
    local section="$2"
    local option="$3"
    local value="$4"

    local current
    current="$(uci -q get "$package.$section.$option")"
    if [ -z "$current" ]; then
        log "Adding missing option '$option' with value '$value'"
        uci set "$package.$section.$option=$value"
        uci commit "$package"
        return 0
    else
        return 1
    fi
}

# Migrates a configuration key in an OpenWrt config file from old_key_name to new_key_name
migration_rename_config_key() {
    local config="$1"
    local key_type="$2"
    local old_key_name="$3"
    local new_key_name="$4"

    if grep -q "$key_type $old_key_name" "$config"; then
        log "Deprecated $key_type found: $old_key_name migrating to $new_key_name"
        sed -i "s/$key_type $old_key_name/$key_type $new_key_name/g" "$config"
    fi
}

# Download URL to file
download_to_file() {
    local url="$1"
    local filepath="$2"
    local http_proxy_address="$3"
    local retries="${4:-3}"
    local wait="${5:-2}"

    for attempt in $(seq 1 "$retries"); do
        if [ -n "$http_proxy_address" ]; then
            http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" wget -O "$filepath" "$url" && break
        else
            wget -O "$filepath" "$url" && break
        fi

        log "Attempt $attempt/$retries to download $url failed" "warn"
        sleep "$wait"
    done
}

# Converts Windows-style line endings (CRLF) to Unix-style (LF)
convert_crlf_to_lf() {
    local filepath="$1"

    if grep -q $'\r' "$filepath"; then
        log "File '$filepath' contains CRLF line endings. Converting to LF..." "debug"
        local tmpfile
        tmpfile=$(mktemp)
        tr -d '\r' < "$filepath" > "$tmpfile" && mv "$tmpfile" "$filepath" || rm -f "$tmpfile"
    fi
}

#######################################
# Parses a whitespace-separated string, validates items as either domains
# or IPv4 addresses/subnets, and returns a comma-separated string of valid items.
# Arguments:
#   $1 - Input string (space-separated list of items)
#   $2 - Type of validation ("domains" or "subnets")
# Outputs:
#   Comma-separated string of valid domains or subnets
#######################################
parse_domain_or_subnet_string_to_commas_string() {
    local string="$1"
    local type="$2"

    tmpfile=$(mktemp)
    printf "%s\n" "$string" | sed 's/\/\/.*//' | tr ', ' '\n' | grep -v '^$' > "$tmpfile"

    result="$(parse_domain_or_subnet_file_to_comma_string "$tmpfile" "$type")"
    rm -f "$tmpfile"

    echo "$result"
}

#######################################
# Parses a file line by line, validates entries as either domains or subnets,
# and returns a single comma-separated string of valid items.
# Arguments:
#   $1 - Path to the input file
#   $2 - Type of validation ("domains" or "subnets")
# Outputs:
#   Comma-separated string of valid domains or subnets
#######################################
parse_domain_or_subnet_file_to_comma_string() {
    local filepath="$1"
    local type="$2"

    local result
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        [ -z "$line" ] && continue

        case "$type" in
        domains)
            if ! is_domain_suffix "$line"; then
                log "'$line' is not a valid domain" "debug"
                continue
            fi
            ;;
        subnets)
            if ! is_ipv4 "$line" && ! is_ipv4_cidr "$line"; then
                log "'$line' is not IPv4 or IPv4 CIDR" "debug"
                continue
            fi
            ;;
        *)
            log "Unknown type: $type" "error"
            return 1
            ;;
        esac

        if [ -z "$result" ]; then
            result="$line"
        else
            result="$result,$line"
        fi
    done < "$filepath"

    echo "$result"
}

# Returns the device model from OpenWrt sysinfo, or "OpenWrt Router" as fallback
get_device_model() {
    local model=""
    if [ -f /tmp/sysinfo/model ]; then
        model="$(cat /tmp/sysinfo/model 2>/dev/null)"
    fi
    echo "${model:-OpenWrt Router}"
}

# Returns the Linux kernel version
get_kernel_version() {
    uname -r
}

# Returns the sing-box version number (e.g. "1.12.0")
get_sing_box_version() {
    local version=""
    if command -v sing-box >/dev/null 2>&1; then
        version="$(sing-box version 2>/dev/null | head -1 | awk '{print $NF}')"
    fi
    echo "${version:-1.0}"
}

# Generates a deterministic HWID based on WAN MAC address and device model
# Format: xxxx-xxxx-xxxx-xxxx
# Same router always produces the same HWID
generate_hwid() {
    local mac="" model="" raw_hash=""

    # Try to get WAN MAC address
    if [ -f /sys/class/net/eth0/address ]; then
        mac="$(cat /sys/class/net/eth0/address 2>/dev/null)"
    elif [ -f /sys/class/net/br-lan/address ]; then
        mac="$(cat /sys/class/net/br-lan/address 2>/dev/null)"
    fi

    model="$(get_device_model)"

    # Generate hash from MAC + model
    raw_hash="$(printf '%s-%s' "$mac" "$model" | md5sum | cut -c1-16)"

    # Format as xxxx-xxxx-xxxx-xxxx
    printf '%s-%s-%s-%s' \
        "$(echo "$raw_hash" | cut -c1-4)" \
        "$(echo "$raw_hash" | cut -c5-8)" \
        "$(echo "$raw_hash" | cut -c9-12)" \
        "$(echo "$raw_hash" | cut -c13-16)"
}

# Downloads a subscription JSON from the given URL with custom headers
# Arguments:
#   $1 - subscription URL
#   $2 - output file path
#   $3 - http proxy address (optional)
#   $4 - retries (optional, default 3)
#   $5 - wait between retries (optional, default 2)
download_subscription() {
    local url="$1"
    local filepath="$2"
    local http_proxy_address="$3"
    local retries="${4:-3}"
    local wait="${5:-2}"
    local sb_version device_model kernel_version hwid
    sb_version="$(get_sing_box_version)"
    device_model="$(get_device_model)"
    kernel_version="$(get_kernel_version)"
    hwid="$(generate_hwid)"
    local header_args=""
    header_args="--header='User-Agent: singbox/$sb_version'"
    header_args="$header_args --header='X-HWID: $hwid'"
    header_args="$header_args --header='X-Device-OS: OpenWrt Linux'"
    header_args="$header_args --header='X-Device-Model: $device_model'"
    header_args="$header_args --header='X-Ver-OS: $kernel_version'"
    header_args="$header_args --header='Accept-Language: ru-RU,en,*'"
    header_args="$header_args --header='X-Device-Locale: EN'"

    local tmp_raw
    tmp_raw="$(mktemp)"

    local downloaded=0
    for attempt in $(seq 1 "$retries"); do
        if [ -n "$http_proxy_address" ]; then
            http_proxy="http://$http_proxy_address" https_proxy="http://$http_proxy_address" \
                eval wget -O "$tmp_raw" $header_args "$url"
        else
            eval wget -O "$tmp_raw" $header_args "$url"
        fi
        if [ $? -eq 0 ]; then
            downloaded=1
            break
        fi
        log "Attempt $attempt/$retries to download subscription from $url failed" "warn"
        sleep "$wait"
    done

    if [ "$downloaded" -eq 0 ]; then
        rm -f "$tmp_raw"
        return 1
    fi

    # Определяем формат: уже sing-box JSON или base64-encoded список vless://
    local first_char
    first_char="$(head -c 1 "$tmp_raw")"

    if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
        # Уже готовый sing-box JSON — используем как есть
        log "Subscription format: sing-box JSON" "info"
        mv "$tmp_raw" "$filepath"
        return 0
    fi

    # Пробуем декодировать как base64
    log "Subscription format: base64, converting vless:// to sing-box JSON" "info"
    local decoded
    decoded="$(base64 -d "$tmp_raw" 2>/dev/null)"
    rm -f "$tmp_raw"

    if ! echo "$decoded" | grep -q "vless://"; then
        log "Subscription: failed to decode base64 or no vless:// entries found" "error"
        return 1
    fi

    # Конвертируем vless:// строки в sing-box JSON outbounds
    local outbounds_json=""
    local first=1

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "$line" | grep -q "^vless://" || continue

        if echo "$line" | grep -iq "Россия\|Russia\|ruРоссия"; then
            continue
        fi

        local uri="${line#vless://}"

        # Тег (после #) — сырые UTF-8 байты, decode не нужен
        local tag
        tag="$(echo "$uri" | sed 's/.*#//')"
        tag="$(echo "$tag" | sed 's/\\/\\\\/g; s/"/\\"/g')"

        local uri_notag="${uri%%#*}"
        local userinfo="${uri_notag%%\?*}"
        local uuid="${userinfo%%@*}"
        local hostport="${userinfo##*@}"
        local host="${hostport%%:*}"
        local port="${hostport##*:}"
        local params="${uri_notag##*\?}"

        local security type flow sni fp pbk sid
        security="$(echo "$params" | grep -oE '(^|&)security=[^&]*' | cut -d= -f2)"
        type="$(echo "$params"     | grep -oE '(^|&)type=[^&]*'     | cut -d= -f2)"
        flow="$(echo "$params"     | grep -oE '(^|&)flow=[^&]*'     | cut -d= -f2)"
        sni="$(echo "$params"      | grep -oE '(^|&)sni=[^&]*'      | cut -d= -f2)"
        fp="$(echo "$params"       | grep -oE '(^|&)fp=[^&]*'       | cut -d= -f2)"
        pbk="$(echo "$params"      | grep -oE '(^|&)pbk=[^&]*'      | cut -d= -f2)"
        sid="$(echo "$params"      | grep -oE '(^|&)sid=[^&]*'      | cut -d= -f2)"

        [ -z "$type" ]     && type="tcp"
        [ -z "$security" ] && security="none"
        [ -z "$fp" ]       && fp="chrome"

        local tls_block=""
        if [ "$security" = "reality" ]; then
            tls_block="\"tls\":{\"enabled\":true,\"server_name\":\"$sni\",\"utls\":{\"enabled\":true,\"fingerprint\":\"$fp\"},\"reality\":{\"enabled\":true,\"public_key\":\"$pbk\",\"short_id\":\"$sid\"}}"
        elif [ "$security" = "tls" ]; then
            tls_block="\"tls\":{\"enabled\":true,\"server_name\":\"$sni\"}"
        fi

        local flow_block=""
        [ -n "$flow" ] && flow_block="\"flow\":\"$flow\","

        local tls_sep=""
        [ -n "$tls_block" ] && tls_sep=",$tls_block"

        local obj="{\"type\":\"vless\",\"tag\":\"$tag\",\"server\":\"$host\",\"server_port\":$port,\"uuid\":\"$uuid\",${flow_block}\"packet_encoding\":\"xudp\"${tls_sep}}"

        if [ "$first" = "1" ]; then
            outbounds_json="$obj"
            first=0
        else
            outbounds_json="$outbounds_json,$obj"
        fi
    done << VLESSEOF
$decoded
VLESSEOF

    if [ -z "$outbounds_json" ]; then
        log "Subscription: no valid vless:// outbounds converted" "error"
        return 1
    fi

    printf '{"outbounds":[%s]}' "$outbounds_json" > "$filepath"
    local count
    count="$(echo "$outbounds_json" | grep -o '"type":"vless"' | wc -l)"
    log "Subscription: converted $count vless:// outbounds to sing-box JSON" "info"
}
