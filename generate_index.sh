#!/bin/bash

# Script to generate index.json file for dynamic dropdown population
# This should be run whenever new JSON files are added to the data directory

# Get the directory where the script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the data directory (subdirectory of where the script is located)
data_dir="$script_dir/data"

# Output file
index_file="$data_dir/index.json"

# Check if data directory exists
if [[ ! -d "$data_dir" ]]; then
    echo "Error: Data directory not found: $data_dir"
    echo "Please create the data directory and add your JSON files."
    exit 1
fi

echo "Scanning for JSON files in: $data_dir"

# Find all JSON files in the data directory (excluding index.json)
json_files=()
while IFS= read -r -d '' file; do
    filename=$(basename "$file" .json)
    # Skip the index.json file itself
    if [[ "$filename" != "index" ]]; then
        json_files+=("$filename")
    fi
done < <(find "$data_dir" -name "*.json" -print0 2>/dev/null)

# Sort the array
IFS=$'\n' sorted_files=($(sort <<<"${json_files[*]}"))
unset IFS

echo "Found ${#sorted_files[@]} JSON file(s):"

# Generate the index.json file
echo "[" > "$index_file"

for i in "${!sorted_files[@]}"; do
    filename="${sorted_files[$i]}"
    echo "  - $filename"
    
    # Add comma if not the last item
    if [[ $i -lt $((${#sorted_files[@]} - 1)) ]]; then
        cat >> "$index_file" << EOF
  {
    "value": "$filename",
    "label": "$filename"
  },
EOF
    else
        cat >> "$index_file" << EOF
  {
    "value": "$filename",
    "label": "$filename"
  }
EOF
    fi
done

echo "]" >> "$index_file"

echo ""
echo "Generated index file: $index_file"
echo "The web application will now dynamically load these data sources."

# If no JSON files were found, create a minimal index file
if [[ ${#sorted_files[@]} -eq 0 ]]; then
    echo "[]" > "$index_file"
    echo "Warning: No JSON files found in data directory."
    echo "Add your JSON files to the data directory and run this script again."
fi