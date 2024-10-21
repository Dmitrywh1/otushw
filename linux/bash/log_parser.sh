#!/bin/bash

set -eu

date="$(date -u +"[%d/%b/%Y:%H:%M:%S" -d "5 minute ago")"
log_files=("/var/log/nginx/access.log" "/var/log/nginx/access.log")

analyze_logs() {
    local log_file="$1"
    local date="$2"
    local count=$(awk -v date="$date" '$4 <= date {print}' $log_file | wc -l)
    local now=$(date +"%m-%d-%Y %H:%M:%S")
    local ago=$(date -d "5 minute ago" +"%m-%d-%Y %H:%M:%S")
    local recieve_date="$ago - $now"

    if [ "$count" -eq 0 ]; then
        cat <<EOF
Report $recieve_date on $log_file
No events in $log_file
EOF
    else
        echo "Report $recieve_date on $log_file"
        echo "Top 10 popular ip"
        {
            echo "count ip"
            awk '{ print $1 }' "$log_file" | uniq -c | sort -r
        } | awk '{ print $2, $1 }' | head -n 10

        echo "Most popular endpoint"
        {
            echo "count endpoint"
            grep -oP "\/\w*(?= HTTP)" "$log_file" | uniq -c
        } | awk '{ print $2, $1 }' | column -t
        echo "Most popular response codes"
        {
            echo "count response_code"
            grep -oP "\d{3}(?= \d+)" "$log_file" | uniq -c
        } | awk '{ print $2, $1 }' | column -t
        echo "Error codes"
        if [ $(grep -oP "(4..|5..)(?= \d+)" "$log_file" | wc -l) -eq 0 ]; then
            echo "There were no HTTP errors"
        else
            {
                echo "count errors"
                grep -oP "(4..|5..)(?= \d+)" "$log_file" | uniq -c
            } | awk '{ print $2, $1 }' | column -t
        fi
    fi
}

for i in "${log_files[@]}"; do
    result=$(analyze_logs "$i" "$date")
    report+="$result"$'\n\n'
done

sent_report_to_tg() {
    local api_token="$1"
    local chat_id="$2"
    local data="$3"

    curl -X POST \
    "https://api.telegram.org/bot$api_token/sendMessage" \
    -d "chat_id=$chat_id&text=$3"
}

sent_report_to_tg "$TG_API_TOKEN" "$TG_CHAT_ID" "$report"