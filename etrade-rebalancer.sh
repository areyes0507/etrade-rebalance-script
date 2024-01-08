#!/bin/bash

# Usage: ./script_name.sh csv_file "symbol1 symbol2 ..." "portion1 portion2 ..."

# Exit if no arguments provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <csv_file> \"symbol1 symbol2 ...\" \"portion1 portion2 ...\""
    exit 1
fi

csv_file=$1  # CSV file is the first argument
symbols=($2)  # Symbols are the second argument
portions=($3)  # Portions are the third argument

# Check if the file exists
if [ ! -f "$csv_file" ]; then
    echo "File not found: $csv_file"
    exit 1
fi

# Initialize total balance
total_balance=0

# Validate that the sum of all portions is 100
total_portion=0
for portion in "${portions[@]}"; do
    total_portion=$(echo "$total_portion + $portion" | bc)
done

if (( $(echo "$total_portion != 100" | bc -l) )); then
    echo "Error: The sum of all portions does not equal 100. Total is $total_portion%"
    exit 1
fi

# Function to get portion by symbol
get_portion() {
    local symbol=$1
    for i in "${!symbols[@]}"; do
        if [[ "${symbols[$i]}" == "$symbol" ]]; then
            echo "${portions[$i]}"
            return
        fi
    done
    echo 0  # Default case if symbol not found
}

# Flag to indicate next line should be read as total balance
read_next_line_for_balance=false

# Read the CSV file to process each line
while IFS=, read -r column1 column2 column3; do
    if [[ "$column2" == "Net Account Value" ]]; then
        read_next_line_for_balance=true
        continue
    fi

    if [[ "$read_next_line_for_balance" = true ]]; then
        # Assuming the value is the first element on the next line
        total_balance=$(echo "$column2" | tr -d ',')  # Clean total_balance value
        read_next_line_for_balance=false  # Reset the flag
        break  # Stop reading further as total balance is found
    fi
done < "$csv_file"

# Verify that total_balance is a valid number
if ! [[ "$total_balance" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Total balance is not a valid number: $total_balance"
    exit 1
fi

echo "Using Total Balance: $total_balance"

# Reset the file descriptor to read from the beginning of the file again
exec < "$csv_file"

# Print header
echo "| Symbol | Current Value | Desired Value (Portion %) | Difference |"

# Read the CSV file again for stock values
while IFS=, read -r -a line; do
    symbol="${line[0]}"
    
    # Skip non-stock lines or headers
    if [[ ! " ${symbols[*]} " =~ " $symbol " ]]; then
        continue
    fi

    # Assuming "Value $" is the 10th column, adjust the index 9 (0-based indexing)
    value="${line[9]}"  # Adjust the index based on actual position of "Value $"

    # Clean and isolate the numeric value from the 'Value $' field
    clean_value=$(echo $value | grep -o '[0-9]*\.[0-9]*' | head -n 1)

    # Verify that clean_value is a valid number
    if ! [[ "$clean_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Skipping $symbol: Invalid value encountered."
        continue
    fi

    # Get the portion for this symbol
    portion=$(get_portion "$symbol")

    # Calculate the desired portion of total balance for this symbol
    desired_portion=$(echo "scale=4; $total_balance * $portion / 100" | bc)

    # Calculate the difference (current value - desired portion)
    difference=$(echo "$clean_value - $desired_portion" | bc)

    # Output the row of data
    echo "| $symbol | $clean_value | $desired_portion ($portion%) | $difference |"
done < "$csv_file"