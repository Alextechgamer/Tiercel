# Tiercel Lab local iOS 26 Simulator gate

- Date: 2026-10-16
- Tiercel upstream commit: 2c025a7937ab65bc5b110c62c35ec1f2f72d4b5d (v3.3.0)
- Xcode: 26.0.1; build target: iOS 17+ (Simulator iOS 26.0)
- Physical ARM64 Release build: PASSED (unsigned), embedded Tiercel.framework
- Isolated disposable Simulator: iPhone 17 Pro Max, created and deleted
- Result: status Succeeded, exactly 1,048,576 bytes received and saved
- Saved-file SHA-256: bf79be0c21a100565100d16b31deee78ce5391f66c0774405d484ce38b6076e0
- Raw image evidence: tiercel-lab-simulator.png
- Simulator network mode: normal URLSession; physical iPhone Tiercel uses native background URLSession
- Remaining physical gate: user must install separate IPA, compare whether -3000 reproduces before the file callback. No claims of phone background success yet.
