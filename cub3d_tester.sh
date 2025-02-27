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

# Function to run a test
run_test() {
    local test_name=$1
    local test_file=$2
    local expected_error=$3
    
    TOTAL=$((TOTAL+1))
    
    echo -e "\n==== Testing: $test_name ===="
    echo "Test file content:"
    cat $test_file
    
    # Run the program with the test file
    echo -e "\nRunning: $EXECUTABLE $test_file"
    
    if [ $CHECK_LEAKS -eq 1 ]; then
        if [ "$OS" == "Linux" ]; then
            # Use valgrind for leak checking on Linux
            valgrind_output=$(valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --verbose --log-file="$TEST_DIR/valgrind_output.txt" $EXECUTABLE $test_file 2>&1)
            output=$(cat "$TEST_DIR/valgrind_output.txt")
            exit_code=${PIPESTATUS[0]}
            
            # Check for memory leaks in valgrind output
            if grep -q "definitely lost:" "$TEST_DIR/valgrind_output.txt" && ! grep -q "definitely lost: 0 bytes" "$TEST_DIR/valgrind_output.txt"; then
                echo "❌ MEMORY LEAK DETECTED!"
                grep -A 2 "definitely lost:" "$TEST_DIR/valgrind_output.txt"
                LEAKS=$((LEAKS+1))
            elif grep -q "indirectly lost:" "$TEST_DIR/valgrind_output.txt" && ! grep -q "indirectly lost: 0 bytes" "$TEST_DIR/valgrind_output.txt"; then
                echo "❌ MEMORY LEAK DETECTED!"
                grep -A 2 "indirectly lost:" "$TEST_DIR/valgrind_output.txt"
                LEAKS=$((LEAKS+1))
            elif grep -q "still reachable:" "$TEST_DIR/valgrind_output.txt" && ! grep -q "still reachable: 0 bytes" "$TEST_DIR/valgrind_output.txt"; then
                echo "⚠️ MEMORY STILL REACHABLE (possible leak)!"
                grep -A 2 "still reachable:" "$TEST_DIR/valgrind_output.txt"
            else
                echo "✅ NO MEMORY LEAKS DETECTED!"
            fi
            
        elif [ "$OS" == "Darwin" ]; then
            # Use leaks for leak checking on macOS
            # Launch program and get its PID
            $EXECUTABLE $test_file > "$TEST_DIR/output.txt" 2>&1 & 
            PID=$!
            
            # Let the program run for a short time
            sleep 1
            
            # Run leaks on the process
            leaks_output=$(leaks $PID)
            
            # Kill the process
            kill -9 $PID 2>/dev/null
            wait $PID 2>/dev/null
            
            output=$(cat "$TEST_DIR/output.txt")
            exit_code=1  # Assuming error because we killed the process
            
            # Check for memory leaks in leaks output
            if echo "$leaks_output" | grep -q "0 leaks"; then
                echo "✅ NO MEMORY LEAKS DETECTED!"
            else
                echo "❌ MEMORY LEAK DETECTED!"
                echo "$leaks_output" | grep "leaks for"
                LEAKS=$((LEAKS+1))
            fi
        fi
    else
        # Just run the program without leak checking
        output=$($EXECUTABLE $test_file 2>&1)
        exit_code=$?
    fi
    
    echo -e "\nOutput: $output"
    echo "Exit code: $exit_code"
    
    # Check if program detected an error (non-zero exit code)
    if [ $exit_code -ne 0 ]; then
        # Check if the error message contains expected text (if provided)
        if [ -n "$expected_error" ] && [[ "$output" != *"Error"* ]]; then
            echo "❌ TEST FAILED: Program exited with error but didn't display 'Error' message"
        else
            echo "✅ TEST PASSED: Program correctly detected an error"
            PASSED=$((PASSED+1))
        fi
    else
        echo "❌ TEST FAILED: Program should have detected an error but didn't"
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

# Test 28: Extension piège - .cubcub
cp $TEST_DIR/valid.cub $TEST_DIR/piege_extension.cubcub
run_test "Extension piège (.cubcub)" "$TEST_DIR/piege_extension.cubcub" "Error"

# Test 29: Extension piège - .cu
cp $TEST_DIR/valid.cub $TEST_DIR/piege_extension.cu
run_test "Extension piège (.cu)" "$TEST_DIR/piege_extension.cu" "Error"

# Test 30: Mauvaise extension cachée
cat > $TEST_DIR/extension_cachee.cub.txt << EOF
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
run_test "Extension cachée (.cub.txt)" "$TEST_DIR/extension_cachee.cub.txt" "Error"

# Test 31: Textures avec identifiants similaires
cat > $TEST_DIR/identifiants_similaires.cub << EOF
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
run_test "Identifiants similaires (N0 au lieu de NO)" "$TEST_DIR/identifiants_similaires.cub" "Error"

# Test 32: Couleurs avec séparateurs trompeurs
cat > $TEST_DIR/separateurs_couleurs.cub << EOF
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
run_test "Séparateurs couleurs (points au lieu de virgules)" "$TEST_DIR/separateurs_couleurs.cub" "Error"

# Test 33: Couleurs sans séparateurs
cat > $TEST_DIR/sans_separateurs.cub << EOF
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
run_test "Couleurs sans séparateurs (espaces)" "$TEST_DIR/sans_separateurs.cub" "Error"

# Test 34: Caractères Unicode dans la carte
cat > $TEST_DIR/unicode_carte.cub << EOF
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
run_test "Caractères Unicode dans la carte" "$TEST_DIR/unicode_carte.cub" "Error"

# Test 35: Caractères de contrôle dans le fichier
printf "NO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100\b101\n101001\n1100N1\n111111\n" > $TEST_DIR/controle_fichier.cub
run_test "Caractères de contrôle dans le fichier" "$TEST_DIR/controle_fichier.cub" "Error"

# Test 36: Fichier sans newline final
printf "NO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100101\n101001\n1100N1\n111111" > $TEST_DIR/sans_newline.cub
run_test "Fichier sans newline final" "$TEST_DIR/sans_newline.cub" "Error"

# Test 37: Tab et espaces mélangés dans la carte
cat > $TEST_DIR/tab_espaces.cub << EOF
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
run_test "Tab et espaces mélangés dans la carte" "$TEST_DIR/tab_espaces.cub" "Error"

# Test 38: Espaces entre identifiant et chemin
cat > $TEST_DIR/espaces_identifiant.cub << EOF
NO      $NO_TEXTURE
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
run_test "Espaces multiples entre identifiant et chemin" "$TEST_DIR/espaces_identifiant.cub" "Error"

# Test 39: Ligne vide dans la carte
cat > $TEST_DIR/ligne_vide_carte.cub << EOF
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
run_test "Ligne vide dans la carte" "$TEST_DIR/ligne_vide_carte.cub" "Error"

# Test 40: Paramètres supplémentaires inutiles
cat > $TEST_DIR/parametres_supplementaires.cub << EOF
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
run_test "Paramètres supplémentaires après texture" "$TEST_DIR/parametres_supplementaires.cub" "Error"

# Test 41: Fichier avec caractères invisibles (ZWSP - Zero Width Space)
printf "NO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100\u200B101\n101001\n1100N1\n111111\n" > $TEST_DIR/caracteres_invisibles.cub
run_test "Caractères invisibles dans le fichier" "$TEST_DIR/caracteres_invisibles.cub" "Error"

# Test 42: Fichier avec BOM (Byte Order Mark)
printf "\xEF\xBB\xBFNO $NO_TEXTURE\nSO $SO_TEXTURE\nWE $WE_TEXTURE\nEA $EA_TEXTURE\nF 220,100,0\nC 225,30,0\n\n111111\n100101\n101001\n1100N1\n111111\n" > $TEST_DIR/fichier_avec_bom.cub
run_test "Fichier avec BOM (Byte Order Mark)" "$TEST_DIR/fichier_avec_bom.cub" "Error"

# Test 43: Joueur placé exactement à la bordure
cat > $TEST_DIR/joueur_bordure.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 225,30,0

111111
1N0101
101001
110001
111111
EOF
run_test "Joueur placé à la bordure" "$TEST_DIR/joueur_bordure.cub" "Error"

# Test 44: Valeurs RGB avec leading zeros
cat > $TEST_DIR/rgb_leading_zeros.cub << EOF
NO $NO_TEXTURE
SO $SO_TEXTURE
WE $WE_TEXTURE
EA $EA_TEXTURE
F 220,100,0
C 000,030,000

111111
100101
101001
1100N1
111111
EOF
run_test "Valeurs RGB avec leading zeros" "$TEST_DIR/rgb_leading_zeros.cub" "Error"

# Test 45: Fichier avec retours chariot Windows (CRLF)
printf "NO $NO_TEXTURE\r\nSO $SO_TEXTURE\r\nWE $WE_TEXTURE\r\nEA $EA_TEXTURE\r\nF 220,100,0\r\nC 225,30,0\r\n\r\n111111\r\n100101\r\n101001\r\n1100N1\r\n111111\r\n" > $TEST_DIR/crlf_windows.cub
run_test "Fichier avec retours chariot Windows (CRLF)" "$TEST_DIR/crlf_windows.cub" "Error"


# Show summary
echo -e "\n==== Test Summary ===="
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $((TOTAL-PASSED))"
if [ $CHECK_LEAKS -eq 1 ]; then
    echo "Memory leaks detected: $LEAKS"
fi

if [ $PASSED -eq $TOTAL ]; then
    echo "✅ ALL PARSING TESTS PASSED!"
else
    echo "❌ SOME PARSING TESTS FAILED!"
fi

if [ $CHECK_LEAKS -eq 1 ] && [ $LEAKS -eq 0 ]; then
    echo "✅ NO MEMORY LEAKS DETECTED!"
elif [ $CHECK_LEAKS -eq 1 ]; then
    echo "❌ MEMORY LEAKS DETECTED IN $LEAKS TESTS!"
fi