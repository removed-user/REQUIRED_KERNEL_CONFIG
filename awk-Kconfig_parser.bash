#!/usr/bin/awk -f

# Main tracking function to clean up and print the current accumulated config object
function emit_config() {
    if (name == "") return

    # Clean up fields
    gsub(/^[ \t]+|[ \t]+$/, "", type)
    gsub(/^[ \t]+|[ \t]+$/, "", prompt)
    gsub(/^[ \t]+|[ \t]+$/, "", depends)
    gsub(/^[ \t]+|[ \t]+$/, "", visible)
    gsub(/^[ \t]+|[ \t]+$/, "", selects)
    gsub(/^[ \t]+|[ \t]+$/, "", implies)
    gsub(/^[ \t]+|[ \t]+$/, "", defaults)

    if (type == "") type = "unknown"

    # Format output as JSON for easy consumption by other programming languages
    printf "  \"%s\": {\n", name
    printf "    \"type\": \"%s\",\n", type
    printf "    \"prompt\": %s,\n", (prompt != "" ? prompt : "null")
    printf "    \"depends_on\": %s,\n", (depends != "" ? "\"" depends "\"" : "null")
    printf "    \"visible_if\": %s,\n", (visible != "" ? "\"" visible "\"" : "null")
    printf "    \"selects\": %s,\n", (selects != "" ? "[" selects "]" : "[]")
    printf "    \"implies\": %s,\n", (implies != "" ? "[" implies "]" : "[]")
    printf "    \"defaults\": %s\n", (defaults != "" ? "[" defaults "]" : "[]")
    
    printf "  },\n"

    # Reset tracking variables
    name = ""; type = ""; prompt = ""; depends = ""; visible = ""; selects = ""; implies = ""; defaults = ""
}

BEGIN {
    print "{"
}

{
    orig_line = $0
    sub(/^[ \t]+/, "", orig_line)
    sub(/[ \t]+$/, "", orig_line)
    
    if (orig_line ~ /^#/ || orig_line == "") next

    # 1. New Symbol Target Block Boundary
    if (orig_line ~ /^(config|menuconfig)[ \t]+/) {
        emit_config()  
        match(orig_line, /^(config|menuconfig)[ \t]+[^ \t]+/)
        split(substr(orig_line, RSTART, RLENGTH), parts, /[ \t]+/)
        name = parts[2]
        next
    }

    if (name == "") next

    # 2. Type definition and direct inline prompt matching
    if (orig_line ~ /^(bool|tristate|string|int|hex)([ \t]+|$)/) {
        split(orig_line, parts, /[ \t]+/)
        type = parts[1]
        if (match(orig_line, /".*"/)) {
            prompt = substr(orig_line, RSTART, RLENGTH)
        }
        next
    }

    # 3. Explicit prompts
    if (orig_line ~ /^prompt[ \t]+/) {
        if (match(orig_line, /".*"/)) {
            prompt = substr(orig_line, RSTART, RLENGTH)
        }
        next
    }

    # 4. Dependency tracking ("depends on")
    if (orig_line ~ /^depends[ \t]+on[ \t]+/) {
        val = orig_line
        sub(/^depends[ \t]+on[ \t]+/, "", val)
        depends = (depends != "") ? depends " && (" val ")" : "(" val ")"
        next
    }

    # 5. Visibility constraints ("visible if")
    if (orig_line ~ /^visible[ \t]+if[ \t]+/) {
        val = orig_line
        sub(/^visible[ \t]+if[ \t]+/, "", val)
        visible = (visible != "") ? visible " && (" val ")" : "(" val ")"
        next
    }

    # 6. Select statements (Accumulated target arrays)
    if (orig_line ~ /^select[ \t]+/) {
        val = orig_line
        sub(/^select[ \t]+/, "", val)
        selects = (selects != "") ? selects ", \"" val "\"" : "\"" val "\""
        next
    }

    # 7. Imply statements (Accumulated target arrays)
    if (orig_line ~ /^imply[ \t]+/) {
        val = orig_line
        sub(/^imply[ \t]+/, "", val)
        implies = (implies != "") ? implies ", \"" val "\"" : "\"" val "\""
        next
    }

    # 8. Defaults tracking
    if (orig_line ~ /^default[ \t]+/) {
        val = orig_line
        sub(/^default[ \t]+/, "", val)
        defaults = (defaults != "") ? defaults ", \"" val "\"" : "\"" val "\""
        next
    }
}

END {
    emit_config()
    print "  \"__EOF__\": null\n}"
}
