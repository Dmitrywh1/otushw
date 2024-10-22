#!/bin/bash

set -eu

log_files=("access.log" "error.log")

analyze_logs() {
    #for awk inspect in *.log
    local now="$(date -u +"[%d/%b/%Y:%H:%M:%S")"
    local five_minutes_ago="$(date -u -d "5 minutes ago" +"[%d/%b/%Y:%H:%M:%S")"
    local log_file=$(awk -v now="$now" -v five_minutes_ago="$five_minutes_ago" '$4 <= now && $4 >= five_minutes_ago {print}' $1)
    local count=$(echo "$log_file" | wc -w)
    #for report text
    local now=$(date +"%m-%d-%Y %H:%M:%S")
    local ago=$(date -d "5 minute ago" +"%m-%d-%Y %H:%M:%S")
    local recieve_date="$ago - $now"

    if [ "$count" -eq 0 ]; then
        cat <<EOF
Report $recieve_date on $1
No events in $1
EOF
    else
        echo "Report $recieve_date on $1"
        echo "Top 10 popular ip"
        {
            echo "count ip"
            echo "$log_file" | awk '{ print $1 }' | uniq -c | sort -r
        } | awk '{ print $2, $1 }' | head -n 10

        echo "Most popular endpoint"
        {
            echo "count endpoint"
            echo "$log_file" | grep -oP "\/\w*(?= HTTP)" | uniq -c
        } | awk '{ print $2, $1 }' | column -t
        echo "Most popular response codes"
        {
            echo "count response_code"
            echo "$log_file" | grep -oP "\d{3}(?= \d+)" | uniq -c
        } | awk '{ print $2, $1 }' | column -t
        echo "Error codes"
        if [ $(echo "$log_file" |grep -oP "(4..|5..)(?= \d+)"| wc -l) -eq 0 ]; then
            echo "There were no HTTP errors"
        else
            {
                echo "count errors"
                echo "$log_file" | grep -oP "(4..|5..)(?= \d+)" | uniq -c
            } | awk '{ print $2, $1 }' | column -t
        fi
    fi
}

for i in "${log_files[@]}"; do
    result=$(analyze_logs "$i")
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