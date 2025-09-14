#!/bin/bash

# Script to remove duplicate entries from JSON files in the data directory
# Duplicates are defined as entries with the same label AND index

# Get the directory where the script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the data directory
data_dir="$script_dir/data"

# Check if data directory exists
if [[ ! -d "$data_dir" ]]; then
    echo "Error: Data directory not found: $data_dir"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install jq: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
    exit 1
fi

echo "Scanning for JSON files in: $data_dir"
echo "Removing duplicates based on matching label AND index..."
echo ""

# Find all JSON files in the data directory (excluding index.json)
json_files=()
while IFS= read -r -d '' file; do
    filename=$(basename "$file" .json)
    # Skip the index.json file itself
    if [[ "$filename" != "index" ]]; then
        json_files+=("$file")
    fi
done < <(find "$data_dir" -name "*.json" -print0 2>/dev/null)

if [[ ${#json_files[@]} -eq 0 ]]; then
    echo "No JSON files found to process."
    exit 0
fi

total_removed=0
files_processed=0

# Process each JSON file
for json_file in "${json_files[@]}"; do
    filename=$(basename "$json_file")
    echo "Processing: $filename"
    
    # Check if file is valid JSON
    if ! jq empty "$json_file" 2>/dev/null; then
        echo "  ⚠️  Skipping $filename - Invalid JSON format"
        continue
    fi
    
    # Count original entries
    original_count=$(jq 'length' "$json_file" 2>/dev/null)
    
    if [[ -z "$original_count" || "$original_count" == "null" ]]; then
        echo "  ⚠️  Skipping $filename - Could not read array length"
        continue
    fi
    
    # Create temporary file
    temp_file=$(mktemp)
    
    # Remove duplicates using jq
    # This creates a unique key from label+index and keeps only unique combinations
    if jq 'group_by(.label + "|" + (.index | tostring)) | map(.[0])' "$json_file" > "$temp_file" 2>/dev/null; then
        
        # Count entries after deduplication
        new_count=$(jq 'length' "$temp_file" 2>/dev/null)
        
        if [[ -n "$new_count" && "$new_count" != "null" ]]; then
            duplicates_removed=$((original_count - new_count))
            
            if [[ $duplicates_removed -gt 0 ]]; then
                # Replace original file with deduplicated version
                mv "$temp_file" "$json_file"
                echo "  ✅ Removed $duplicates_removed duplicate(s) ($original_count → $new_count entries)"
                total_removed=$((total_removed + duplicates_removed))
            else
                echo "  ✨ No duplicates found ($original_count entries)"
                rm "$temp_file"
            fi
            
            files_processed=$((files_processed + 1))
        else
            echo "  ⚠️  Error processing $filename"
            rm "$temp_file"
        fi
    else
        echo "  ⚠️  Error processing $filename with jq"
        rm "$temp_file"
    fi
done

echo ""
echo "🎉 Deduplication complete!"
echo "📁 Files processed: $files_processed"
echo "🗑️  Total duplicates removed: $total_removed"

if [[ $total_removed -gt 0 ]]; then
    echo ""
    echo "💡 Tip: Run the generate_index.sh script to update the dropdown options."
fi