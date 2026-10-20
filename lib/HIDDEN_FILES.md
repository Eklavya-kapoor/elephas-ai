# Hidden Files in ScamShield Flutter App

The following files have been hidden (renamed with `.hide` suffix):

## Simplified App Version (Lacks Critical Features)

1. `main_simple.dart.hide`
   - A stripped-down version of the main app entry point
   - Missing essential providers and services (SMS, Call, Screen monitors)
   - Lacks proper service initialization
   - Does not include overlay service and scam detection service

2. `screens/modern_permissions_screen.dart.hide`
   - Alternative permissions screen used by the simple version
   - Uses a more modern UI but lacks complete permission handling
   - Was only used by the simplified app version

## Legacy System Components

3. `legacy_system/scam_detection_service.dart.hide`
   - Previous version of the scam detection service
   - Replaced by the enhanced version in `lib/services/scam_detection_service.dart`
   - Contains older detection algorithms and patterns
   - Preserved for reference and comparison

4. `legacy_system/contact_service.dart.hide`
   - Previous version of contact management
   - Contains incomplete SMS database query functionality
   - Replaced by enhanced services in the main app
   - Kept for historical reference

## Development and Testing Files

5. `test_import.dart.hide`
   - Simple test file for verifying imports
   - Contains debug print statements
   - Not used in production
   - Likely a temporary file that was never removed
   - Has invalid relative imports

## Why These Files Exist

These files are preserved for different reasons:

### Simplified Version Files
- Represent an experimental simplified version of the app
- Lack critical security features and proper service initialization
- Unsuitable for production use

### Legacy System Files
- Contain previous implementations of core functionality
- Provide historical context and implementation references
- May be useful for debugging or understanding the evolution of features
- Some contain unfinished features that were reimplemented differently

### Development Files
- Used during development for testing
- May contain useful test cases or examples
- Not meant for production use

## Why They're Hidden

The files are hidden (not deleted) because:
1. They may contain useful UI patterns or code that could be referenced in the future
2. They provide historical context about the app's development
3. Some of their features might be integrated into the main app in a more secure way
4. They serve as documentation of previous implementations
5. They might be useful for understanding test cases and development history

## Using the Full App

Always use the main implementation files:
- `main.dart` - Proper app initialization with all required services
- `screens/detailed_permissions_screen.dart` - Complete permissions handling
- `services/scam_detection_service.dart` - Enhanced scam detection with latest algorithms
- Various service files in `lib/services/` for complete functionality

The full version includes all necessary security features, proper service initialization, and the latest detection algorithms.
