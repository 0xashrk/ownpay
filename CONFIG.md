# Configuration Setup

This project uses environment variables stored in `Tap/Config.swift`. This file is git-ignored to prevent committing sensitive information.

## Setup Instructions

1. Create a new file `Tap/Config.swift` with the following content:

```swift
enum Config {
    static let privyAppId = "YOUR_PRIVY_APP_ID"
    
    // Add other environment variables here
}
```

2. Replace `YOUR_PRIVY_APP_ID` with your actual Privy App ID.

## Available Configuration Options

- `privyAppId`: Your Privy application ID for authentication

## Security Notes

- Never commit `Config.swift` to version control
- Keep your API keys and sensitive information secure
- The `Config.swift` file is already added to `.gitignore` 