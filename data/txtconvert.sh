#!/bin/bash

# Function to extract numbers from array format [num1, num2, num3] or single numbers
extract_numbers() {
    local input="$1"
    # Remove brackets and split by comma, then extract numbers
    echo "$input" | sed 's/\[//g; s/\]//g' | tr ',' '\n' | while read -r item; do
        # Handle format like "10:4968" - only take number after colon
        if [[ "$item" =~ :([0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        # Handle regular numbers, removing any whitespace
        elif [[ "$item" =~ ([0-9]+) ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done
}

# Function to process a single line and generate JSON entries
process_line() {
    local line="$1"
    
    # Skip comment lines and empty lines
    [[ "$line" =~ ^// ]] || [[ -z "$line" ]] && return
    
    # Extract the name
    if [[ "$line" =~ name\ =\ \"([^\"]+)\" ]]; then
        local name="${BASH_REMATCH[1]}"
    else
        return
    fi
    
    # Extract all model-related properties and their numbers
    local -a all_models=()
    local -a all_labels=()
    
    # Extract models = [...]
    if [[ "$line" =~ models\ =\ \[([^\]]+)\] ]]; then
        local models_str="${BASH_REMATCH[1]}"
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name")
            }
        done < <(extract_numbers "$models_str")
    fi
    
    # Extract ground-model = number
    if [[ "$line" =~ ground-model\ =\ ([0-9]+) ]]; then
        all_models+=("${BASH_REMATCH[1]}")
        all_labels+=("$name")
    fi
    
    # Extract head-models = [...]
    if [[ "$line" =~ head-models\ =\ \[([^\]]+)\] ]]; then
        local head_models_str="${BASH_REMATCH[1]}"
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name")
            }
        done < <(extract_numbers "$head_models_str")
    fi
    
    # Extract male-models = [...]
    if [[ "$line" =~ male-models\ =\ \[([^\]]+)\] ]]; then
        local male_models_str="${BASH_REMATCH[1]}"
        local male_counter=0
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name (male$male_counter)")
                ((male_counter++))
            }
        done < <(extract_numbers "$male_models_str")
    fi
    
    # Extract female-models = [...]
    if [[ "$line" =~ female-models\ =\ \[([^\]]+)\] ]]; then
        local female_models_str="${BASH_REMATCH[1]}"
        local female_counter=0
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name (female$female_counter)")
                ((female_counter++))
            }
        done < <(extract_numbers "$female_models_str")
    fi
    
    # Extract male-head-models = [...]
    if [[ "$line" =~ male-head-models\ =\ \[([^\]]+)\] ]]; then
        local male_head_models_str="${BASH_REMATCH[1]}"
        local male_head_counter=0
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name (male$male_head_counter)")
                ((male_head_counter++))
            }
        done < <(extract_numbers "$male_head_models_str")
    fi
    
    # Extract female-head-models = [...]
    if [[ "$line" =~ female-head-models\ =\ \[([^\]]+)\] ]]; then
        local female_head_models_str="${BASH_REMATCH[1]}"
        local female_head_counter=0
        while IFS= read -r model_num; do
            [[ -n "$model_num" ]] && {
                all_models+=("$model_num")
                all_labels+=("$name (female$female_head_counter)")
                ((female_head_counter++))
            }
        done < <(extract_numbers "$female_head_models_str")
    fi
    
    # Output JSON entries for all found models
    for i in "${!all_models[@]}"; do
        local label="${all_labels[$i]}"
        local index="${all_models[$i]}"
        
        # Add comma if not the first entry in the file
        [[ $is_first_entry == false ]] && echo ","
        
        echo " {"
        echo "  \"label\": \"$label\","
        echo "  \"index\": $index"
        echo -n " }"
        
        is_first_entry=false
    done
}

# Main script
# Get the directory where the script is located
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find all .txt files in the script directory
txt_files=("$script_dir"/*.txt)

# Check if any .txt files were found
if [[ ${#txt_files[@]} -eq 1 && ! -f "${txt_files[0]}" ]]; then
    echo "No .txt files found in directory: $script_dir"
    exit 1
fi

echo "Found ${#txt_files[@]} .txt file(s) to process..."

# Process each .txt file
for input_file in "${txt_files[@]}"; do
    # Get the base filename without extension
    base_name="$(basename "$input_file" .txt)"
    output_file="$script_dir/$base_name.json"
    
    echo "Processing: $(basename "$input_file") -> $(basename "$output_file")"
    
    # Redirect output to the JSON file
    {
        # Start JSON array
        echo "["
        
        # Track if this is the first entry to handle comma placement
        is_first_entry=true
        
        # Process each line
        while IFS= read -r line || [[ -n "$line" ]]; do
            process_line "$line"
        done < "$input_file"
        
        # Close JSON array
        echo ""
        echo "]"
    } > "$output_file"
done

echo "Conversion complete! Processed ${#txt_files[@]} file(s)."