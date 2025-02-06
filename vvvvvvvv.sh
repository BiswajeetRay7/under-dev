#!/bin/bash

# ASCII UI for Hanuman Tool
clear
echo "====================================="
echo "         H A N U M A N               "
echo "  Multi-Tool Domain & URL Crawler    "
echo "====================================="
echo "  🚀 Fast, Unique, and Efficient URL Extraction 🚀"
echo "  🛠️ Includes Katana, Hakrawler, Waybackurls, and more"
echo "====================================="

# User input for domains
echo "Enter domains (separated by spaces):"
read -p "Domains: " -a domains

# URL File Path
base_dir=$(pwd)
url_file="$base_dir/all_urls.txt"
subdomains_file="$base_dir/subdomains.txt"

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install it to continue."
        exit 1
    fi
}

# Check for required tools
check_command "amass"
check_command "assetfinder"
check_command "subfinder"
check_command "hakrawler"
check_command "waybackurls"
check_command "urlfinder"
check_command "curl"
check_command "jq"

# Function to fetch subdomains
fetch_subdomains() {
    source=$1
    command=$2
    echo "[*] Fetching subdomains using $source..."
    eval "$command" >> "$subdomains_file"
}

# Function to fetch subdomains from crt.sh JSON
fetch_json_subdomains() {
    source=$1
    url=$2
    jq_filter=$3
    regex=$4
    echo "[*] Fetching subdomains from $source..."
    curl -s "$url" | jq -r "$jq_filter" | grep -E "$regex" >> "$subdomains_file"
}

# Function for URL Extraction from Subdomains
extract_urls() {
    local subdomain=$1
    echo "[*] Crawling subdomain: $subdomain"
    
    # Use Katana for Subdomain Crawling
    katana -u "https://$subdomain" -w - | tee -a "$url_file" &

    # Use Hakrawler to find URLs
    hakrawler -u "https://$subdomain" -t 10 -json -w -silent | tee -a "$url_file" &

    # Use Waybackurls to find archived URLs
    waybackurls "$subdomain" | tee -a "$url_file" &

    # Use URLFinder to find URLs from any sources
    urlfinder -d "$subdomain" -v -t 3 | tee -a "$url_file" &

    # Wait for all background jobs to finish
    wait
}

# Function to Filter URLs
filter_urls() {
    echo "[*] Filtering URLs based on extensions..."
    grep -aE '\.doc|\.docx|\.dot|\.dotm|\.xls|\.xlsx|\.xlt|\.xlsm|\.xlsb|\.ppt|\.pptx|\.pot|\.pps|\.pptm|\.mdb|\.accdb|\.mde|\.accde|\.adp|\.accdt|\.pub|\.puz|\.one|\.xml|\.pdf|\.sql|\.txt|\.zip|\.tar\.gz|\.tgz|\.bak|\.7z|\.rar|\.log|\.cache|\.secret|\.db|\.backup|\.yml|\.gz|\.config|\.csv|\.exe|\.dll|\.bin|\.ini|\.bat|\.sh|\.deb|\.rpm|\.iso|\.apk|\.msi|\.dmg|\.tmp|\.crt|\.pem|\.key|\.pub|\.asc|\.bz2|\.xz|\.lzma|\.z|\.cab|\.arj|\.lha|\.ace|\.arc|\.sqlite|\.sqlite3|\.db3|\.sqlitedb|\.sdb|\.sqlite2|\.frm|\.old|\.sav|\.enc|\.pgp|\.locky|\.secure|\.gpg|\.json' "$url_file" > "$base_dir/filtered_urls.txt"
    echo "[*] Filtered URLs saved to filtered_urls.txt"
}

# Main function to start crawling
start_crawling() {
    for domain in "${domains[@]}"; do
        # 1. Fetch subdomains from various tools (Enumeration)
        echo "[*] Starting subdomain enumeration for domain: $domain"
        fetch_subdomains "Amass" "amass enum -passive -d $domain -o /dev/null"
        fetch_subdomains "Assetfinder" "assetfinder --subs-only $domain"
        fetch_subdomains "Subfinder" "subfinder -d $domain -silent"
        fetch_json_subdomains "crt.sh" "https://crt.sh/?q=%25.$domain&output=json" '.[].name_value' "\w.*$domain"
        fetch_subdomains "Archive" "curl -s \"http://web.archive.org/cdx/search/cdx?url=*.$domain/*&output=text&fl=original&collapse=urlkey\" | sed -e 's_https*://__' -e \"s/\/.*//\""

        # Remove duplicate subdomains
        sort -u "$subdomains_file" -o "$subdomains_file"
        
        echo "[*] Subdomain enumeration complete. Crawling subdomains now..."

        # 2. Crawl the subdomains for URLs (Crawling)
        while IFS= read -r subdomain; do
            extract_urls "$subdomain"
        done < "$subdomains_file"
        
        # 3. Filter URLs based on extensions
        filter_urls
    done
}

# Start enumeration and crawling
start_crawling

# Final output
echo "------------------------------------"
echo "[*] Crawling and filtering complete!"
echo "[*] Filtered URLs saved in $base_dir/filtered_urls.txt"
echo "------------------------------------"
