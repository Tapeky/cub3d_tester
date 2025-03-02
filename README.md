# 🧪 Cub3D Tester

***Cub3D Tester*** is a comprehensive testing script for validating Cub3D projects at 42 school. This script automatically tests your Cub3D parser for various error cases and can also check for memory leaks.

---

## 🛠 Installation
1. Clone the repository or download the script:
```bash
git clone https://github.com/yourusername/cub3d-tester.git
cd cub3d-tester
```

2. Make the script executable:
```bash
chmod +x cub3d_tester.sh
```

---
## 🚀 Usage
Basic usage :
```bash
./cub3d_tester.sh <executable> <north_texture> <south_texture> <west_texture> <east_texture> [--check-leaks]
```
Example
```bash
./cub3d_tester.sh ./cub3D ./textures/north.xpm ./textures/south.xpm ./textures/west.xpm ./textures/east.xpm --check-leaks
```
## Arguments

`<executable>` : Path to your Cub3D executable  
`<north_texture>` : Path to the north texture file  
`<south_texture>` : Path to the south texture file  
`<west_texture>` : Path to the west texture file  
`<east_texture>` : Path to the east texture file  
`--check-leaks` : Optional flag to enable memory leak checking  

---
# 📊 Output Example
```bash
==== Testing: Missing texture path ====
Exit code: 1
✅ TEST PASSED: Program correctly detected an error

...

==== Test Summary ====
Total tests: 49
Passed: 48
Failed: 1
Memory leaks detected: 0

❌ FAILED TESTS:
  1. Invalid texture file (cub3d_test_files/invalid_texture_file.cub) - program didn't detect error

✅ MOST PARSING TESTS PASSED!
✅ NO MEMORY LEAKS DETECTED!
```
# 💡 Benefits
* Save Time: Automate testing instead of creating test cases manually  
* Find Edge Cases: Discover parsing issues you might not have considered  
* Ensure Robustness: Make sure your program properly handles all error cases  
* Memory Management: Verify your program doesn't leak memory  
---
# 👨‍💻 Author
**tsadouk**  
[✉️ tsadouk@student.42angouleme.fr](mailto:tsadouk@42angouleme.fr)  
Étudiant à **42** | Angouleme, France

