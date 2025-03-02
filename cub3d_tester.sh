#!/bin/bash

# Usage: ./test_cub3d.sh <executable> <north_texture> <south_texture> <west_texture> <east_texture> [--check-leaks]
# Example: ./test_cub3d.sh ./cub3D ./textures/north.xpm ./textures/south.xpm ./textures/west.xpm ./textures/east.xpm --check-leaks

CHECK_LEAKS=0
EXECUTABLE=""
NO_TEXTURE=""
SO_TEXTURE=""
WE_TEXTURE=""
EA_TEXTURE=""

# Parse arguments
for arg in "$@"; do
    if [ "$arg" == "--check-leaks" ]; then
        CHECK_LEAKS=1
    elif [ -z "$EXECUTABLE" ]; then
        EXECUTABLE="$arg"
    elif [ -z "$NO_TEXTURE" ]; then
        NO_TEXTURE="$arg"
    elif [ -z "$SO_TEXTURE" ]; then
        SO_TEXTURE="$arg"
    elif [ -z "$WE_TEXTURE" ]; then
        WE_TEXTURE="$arg"
    elif [ -z "$EA_TEXTURE" ]; then
        EA_TEXTURE="$arg"
    fi
done

if [ -z "$EXECUTABLE" ] || [ -z "$NO_TEXTURE" ] || [ -z "$SO_TEXTURE" ] || [ -z "$WE_TEXTURE" ] || [ -z "$EA_TEXTURE" ]; then
    echo "Usage: $0 <executable> <north_texture> <south_texture> <west_texture> <east_texture> [--check-leaks]"
    exit 1
fi

# Detect OS for leak checking
OS=$(uname)
if [ $CHECK_LEAKS -eq 1 ]; then
    if [ "$OS" == "Linux" ]; then
        # Check if valgrind is installed
        if ! command -v valgrind &> /dev/null; then
            echo "Valgrind is not installed. Please install it to check for memory leaks on Linux."
            CHECK_LEAKS=0
        fi
    elif [ "$OS" == "Darwin" ]; then
        # Check if leaks tool is available (macOS)
        if ! command -v leaks &> /dev/null; then
            echo "leaks command not found. Memory leak detection may not work properly on this version of macOS."
            CHECK_LEAKS=0
        fi
    else
        echo "Unsupported OS for leak checking. Memory leak detection disabled."
        CHECK_LEAKS=0
    fi
fi

TEST_DIR="cub3d_test_files"

# Create test directory
mkdir -p $TEST_DIR

# Counter for tests
TOTAL=0
PASSED=0
LEAKS=0
FAILED_TESTS=()
LEAKED_TESTS=()

# Function to run a test
run_test() {
    local test_name=$1
    local test_file=$2
    local expected_error=$3
    local test_passed=true
    
    TOTAL=$((TOTAL+1))
    
    echo -e "\n==== Testing: $test_name ===="
    
    # Run the program with the test file to check for errors
    output=$($EXECUTABLE $test_file 2>&1)
    exit_code=$?
    
    # Check for memory leaks if requested
    if [ $CHECK_LEAKS -eq 1 ] && [ "$OS" == "Linux" ]; then
        # Exécuter valgrind et capturer sa sortie complète
        valgrind_output=$(valgrind --leak-check=full --show-leak-kinds=all $EXECUTABLE $test_file 2>&1)
        
        # Rechercher explicitement "definitely lost" dans la sortie brute
        if echo "$valgrind_output" | grep -q "definitely lost" && ! echo "$valgrind_output" | grep -q "definitely lost: 0 bytes"; then
            echo "❌ MEMORY LEAK DETECTED!"
            echo "Leak details:"
            echo "$valgrind_output" | grep -A 2 "definitely lost"
            LEAKS=$((LEAKS+1))
            LEAKED_TESTS+=("$test_name ($test_file)")
            
            # Commande pour déboguer manuellement
            echo "Run manually: valgrind --leak-check=full --show-leak-kinds=all $EXECUTABLE $test_file"
        else
            echo "✅ NO MEMORY LEAKS DETECTED"
        fi
    fi
    
    echo "Exit code: $exit_code"
    
    # Check if program detected an error (non-zero exit code)
    if [ $exit_code -ne 0 ]; then
        # Check if the error message contains expected text (if provided)
        if [ -n "$expected_error" ] && [[ "$output" != *"Error"* ]]; then
            echo "❌ TEST FAILED: Program exited with error but didn't display 'Error' message"
            test_passed=false
            FAILED_TESTS+=("$test_name ($test_file) - exited with error but no 'Error' message")
        else
            echo "✅ TEST PASSED: Program correctly detected an error"
            PASSED=$((PASSED+1))
        fi
    else
        echo "❌ TEST FAILED: Program should have detected an error but didn't"
        test_passed=false
        FAILED_TESTS+=("$test_name ($test_file) - program didn't detect error")
    fi
}

# Generate valid base file for modification
cat > $TEST_DIR/valid.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF

# Test 1: Missing texture path
cat > $TEST_DIR/missing_texture_path.cub << EOF
NO 
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Missing texture path" "$TEST_DIR/missing_texture_path.cub" "Error"

# Test 2: Invalid texture identifier
cat > $TEST_DIR/invalid_texture_id.cub << EOF
XX $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Invalid texture identifier" "$TEST_DIR/invalid_texture_id.cub" "Error"

# Test 3: Missing floor color
cat > $TEST_DIR/missing_floor_color.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Missing floor color" "$TEST_DIR/missing_floor_color.cub" "Error"

# Test 4: Invalid floor color format
cat > $TEST_DIR/invalid_floor_color.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,abc
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Invalid floor color format" "$TEST_DIR/invalid_floor_color.cub" "Error"

# Test 5: RGB color out of range
cat > $TEST_DIR/rgb_color_out_of_range.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,300,0

111111
100101
101001
1100N1
111111
EOF
run_test "RGB color out of range" "$TEST_DIR/rgb_color_out_of_range.cub" "Error"

# Test 6: Missing ceiling color
cat > $TEST_DIR/missing_ceiling_color.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C

111111
100101
101001
1100N1
111111
EOF
run_test "Missing ceiling color" "$TEST_DIR/missing_ceiling_color.cub" "Error"

# Test 7: Duplicated texture
cat > $TEST_DIR/duplicated_texture.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
NO $NO_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Duplicated texture" "$TEST_DIR/duplicated_texture.cub" "Error"

# Test 8: Missing texture identifier
cat > $TEST_DIR/missing_texture_id.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
$WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Missing texture identifier" "$TEST_DIR/missing_texture_id.cub" "Error"

# Test 9: Map not closed
cat > $TEST_DIR/map_not_closed.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100001
101001
1100N0
111111
EOF
run_test "Map not closed" "$TEST_DIR/map_not_closed.cub" "Error"

# Test 10: Invalid character in map
cat > $TEST_DIR/invalid_char_in_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
10X101
101001
1100N1
111111
EOF
run_test "Invalid character in map" "$TEST_DIR/invalid_char_in_map.cub" "Error"

# Test 11: Multiple player positions
cat > $TEST_DIR/multiple_player_positions.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100S01
101001
1100N1
111111
EOF
run_test "Multiple player positions" "$TEST_DIR/multiple_player_positions.cub" "Error"

# Test 12: No player position
cat > $TEST_DIR/no_player_position.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100001
101001
110001
111111
EOF
run_test "No player position" "$TEST_DIR/no_player_position.cub" "Error"

# Test 13: Missing texture
cat > $TEST_DIR/missing_texture.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Missing texture" "$TEST_DIR/missing_texture.cub" "Error"

# Test 14: Missing color definition
cat > $TEST_DIR/missing_color.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0

111111
100101
101001
1100N1
111111
EOF
run_test "Missing color definition" "$TEST_DIR/missing_color.cub" "Error"

# Test 15: Empty map
cat > $TEST_DIR/empty_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

EOF
run_test "Empty map" "$TEST_DIR/empty_map.cub" "Error"

# Test 16: Empty file
cat > $TEST_DIR/empty_file.cub << EOF
EOF
run_test "Empty file" "$TEST_DIR/empty_file.cub" "Error"

# Test 17: Map with spaces that create openings
cat > $TEST_DIR/map_with_openings.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100 01
101001
1100N1
111111
EOF
run_test "Map with spaces creating openings" "$TEST_DIR/map_with_openings.cub" "Error"

# Test 18: Wrong file extension
cat > $TEST_DIR/wrong_extension.txt << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Wrong file extension" "$TEST_DIR/wrong_extension.txt" "Error"

# Test 19: Invalid texture file
cat > $TEST_DIR/invalid_texture_file.cub << EOF
NO ./nonexistent.xpm
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Invalid texture file" "$TEST_DIR/invalid_texture_file.cub" "Error"

# Test 20: Too few RGB values
cat > $TEST_DIR/too_few_rgb.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Too few RGB values" "$TEST_DIR/too_few_rgb.cub" "Error"

# Test 21: Too many RGB values
cat > $TEST_DIR/too_many_rgb.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0,50
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Too many RGB values" "$TEST_DIR/too_many_rgb.cub" "Error"

# Test 22: Map with non-rectangular shape
cat > $TEST_DIR/non_rectangular_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
1001
101001
1100N1
111111
EOF
run_test "Map with non-rectangular shape" "$TEST_DIR/non_rectangular_map.cub" "Error"

# Test 23: Map not the last element in file
cat > $TEST_DIR/map_not_last.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0

111111
100101
101001
1100N1
111111

C 225,30,0
EOF
run_test "Map not the last element" "$TEST_DIR/map_not_last.cub" "Error"

# Test 24: Texture path with spaces
cat > $TEST_DIR/texture_path_with_spaces.cub << EOF
NO ./textures/north texture.xpm
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Texture path with spaces" "$TEST_DIR/texture_path_with_spaces.cub" "Error"

# Test 25: Comments in file
cat > $TEST_DIR/comments_in_file.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
# This is a comment
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Comments in file" "$TEST_DIR/comments_in_file.cub" "Error"

# Test 27: Missing map
cat > $TEST_DIR/missing_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0
EOF
run_test "Missing map" "$TEST_DIR/missing_map.cub" "Error"

# Test 28: Trap extension - .cubcub
cp $TEST_DIR/valid.cub $TEST_DIR/trap_extension.cubcub
run_test "Trap extension (.cubcub)" "$TEST_DIR/trap_extension.cubcub" "Error"

# Test 29: Trap extension - .cu
cp $TEST_DIR/valid.cub $TEST_DIR/trap_extension.cu
run_test "Trap extension (.cu)" "$TEST_DIR/trap_extension.cu" "Error"

# Test 30: Hidden wrong extension
cat > $TEST_DIR/hidden_extension.cub.txt << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Hidden extension (.cub.txt)" "$TEST_DIR/hidden_extension.cub.txt" "Error"

# Test 31: Textures with similar identifiers
cat > $TEST_DIR/similar_identifiers.cub << EOF
N0 $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Similar identifiers (N0 instead of NO)" "$TEST_DIR/similar_identifiers.cub" "Error"

# Test 32: Colors with misleading separators
cat > $TEST_DIR/misleading_separators.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220.100.0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Misleading separators (dots instead of commas)" "$TEST_DIR/misleading_separators.cub" "Error"

# Test 33: Colors without separators
cat > $TEST_DIR/no_separators.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220 100 0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Colors without separators (spaces)" "$TEST_DIR/no_separators.cub" "Error"

# Test 34: Unicode characters in the map
cat > $TEST_DIR/unicode_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101★01
1100N1
111111
EOF
run_test "Unicode characters in the map" "$TEST_DIR/unicode_map.cub" "Error"

# Test 35: Control characters in the file
printf "NO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100\b101\n101001\n1100N1\n111111\n" > $TEST_DIR/control_characters.cub
run_test "Control characters in the file" "$TEST_DIR/control_characters.cub" "Error"

# Test 37: Mixed tabs and spaces in the map
cat > $TEST_DIR/mixed_tabs_spaces.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100	101
101001
1100N1
111111
EOF
run_test "Mixed tabs and spaces in the map" "$TEST_DIR/mixed_tabs_spaces.cub" "Error"

# Test 39: Empty line in the map
cat > $TEST_DIR/empty_line_map.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101

101001
1100N1
111111
EOF
run_test "Empty line in the map" "$TEST_DIR/empty_line_map.cub" "Error"

# Test 40: Extra parameters after texture
cat > $TEST_DIR/extra_parameters.cub << EOF
NO $NO_TEXTURE extra_param
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Extra parameters after texture" "$TEST_DIR/extra_parameters.cub" "Error"

# Test 41: File with invisible characters (ZWSP - Zero Width Space)
printf "NO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100\u200B101\n101001\n1100N1\n111111\n" > $TEST_DIR/invisible_characters.cub
run_test "Invisible characters in the file" "$TEST_DIR/invisible_characters.cub" "Error"

# Test 42: File with BOM (Byte Order Mark)
printf "\xEF\xBB\xBFNO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100101\n101001\n1100N1\n111111\n" > $TEST_DIR/file_with_bom.cub
run_test "File with BOM (Byte Order Mark)" "$TEST_DIR/file_with_bom.cub" "Error"

# Test 45: File with Windows carriage returns (CRLF)
printf "NO $NO_TEXTURE\r\nSO $SO_TEXTURE\r\nWE $WE_TEXTURE\r\nEA $EA_TEXTURE\r\nF 220,100,0\r\nC 225,30,0\r\n\r\n111111\r\n100101\r\n101001\r\n1100N1\r\n111111\r\n" > $TEST_DIR/crlf_windows.cub
run_test "File with Windows carriage returns (CRLF)" "$TEST_DIR/crlf_windows.cub" "Error"

# Test 46: Texture file without read permission
# Create a copy of a texture and remove read permissions
cp $NO_TEXTURE $TEST_DIR/no_read_texture.jpg
chmod 0 $TEST_DIR/no_read_texture.jpg

cat > $TEST_DIR/texture_no_read_permission.cub << EOF
NO $TEST_DIR/no_read_texture.jpg
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Texture without read permission" "$TEST_DIR/texture_no_read_permission.cub" "Error"

# Test 47: All texture files without read permission
# Create copies of all textures and remove read permissions
cp $NO_TEXTURE $TEST_DIR/no_read_north.jpg
cp $SO_TEXTURE $TEST_DIR/no_read_south.jpg
cp $WE_TEXTURE $TEST_DIR/no_read_west.jpg
cp $EA_TEXTURE $TEST_DIR/no_read_east.jpg
chmod 0 $TEST_DIR/no_read_north.jpg
chmod 0 $TEST_DIR/no_read_south.jpg
chmod 0 $TEST_DIR/no_read_west.jpg
chmod 0 $TEST_DIR/no_read_east.jpg

cat > $TEST_DIR/all_textures_no_read.cub << EOF
NO $TEST_DIR/no_read_north.jpg
SO $TEST_DIR/no_read_south.jpg
WE $TEST_DIR/no_read_west.jpg
EA $TEST_DIR/no_read_east.jpg
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "All textures without read permission" "$TEST_DIR/all_textures_no_read.cub" "Error"

# Test 48: Directory as texture file
# Create a directory and use it as a texture
mkdir -p $TEST_DIR/texture_dir
cat > $TEST_DIR/texture_directory.cub << EOF
NO $TEST_DIR/texture_dir
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Directory used as texture" "$TEST_DIR/texture_directory.cub" "Error"

# Test 49: Invalid texture path with special characters
cat > $TEST_DIR/special_characters_path.cub << EOF
NO $TEST_DIR/texture@\$%^&*()|.jpg
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
100101
101001
1100N1
111111
EOF
run_test "Texture path with special characters" "$TEST_DIR/special_characters_path.cub" "Error"

# Cleanup temporary files at the end of the script
cleanup() {
    echo "Cleaning up temporary files..."
    # Remove test files with modified permissions
    rm -f $TEST_DIR/no_read_texture.jpg
    rm -f $TEST_DIR/no_read_north.jpg
    rm -f $TEST_DIR/no_read_south.jpg
    rm -f $TEST_DIR/no_read_west.jpg
    rm -f $TEST_DIR/no_read_east.jpg
    rm -rf $TEST_DIR/texture_dir
}

# Execute the cleanup function at the end of the script
trap cleanup EXIT

# Show summary
echo -e "\n==== Test Summary ===="
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $((TOTAL-PASSED))"
if [ $CHECK_LEAKS -eq 1 ]; then
    echo "Memory leaks detected: $LEAKS"
fi

# Show failed tests
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo -e "\n❌ FAILED TESTS:"
    for i in "${!FAILED_TESTS[@]}"; do
        echo "  $((i+1)). ${FAILED_TESTS[$i]}"
    done
fi

# Show leaked tests
if [ $CHECK_LEAKS -eq 1 ] && [ ${#LEAKED_TESTS[@]} -gt 0 ]; then
    echo -e "\n❌ TESTS WITH MEMORY LEAKS:"
    for i in "${!LEAKED_TESTS[@]}"; do
        echo "  $((i+1)). ${LEAKED_TESTS[$i]}"
    done
fi

if [ $PASSED -eq $TOTAL ]; then
    echo -e "\n✅ ALL PARSING TESTS PASSED!"
else
    echo -e "\n❌ SOME PARSING TESTS FAILED!"
fi

if [ $CHECK_LEAKS -eq 1 ] && [ $LEAKS -eq 0 ]; then
    echo "✅ NO MEMORY LEAKS DETECTED!"
elif [ $CHECK_LEAKS -eq 1 ]; then
    echo "❌ MEMORY LEAKS DETECTED IN $LEAKS TESTS!"
fi

# Cleanup test directory
rm -rf $TEST_DIR