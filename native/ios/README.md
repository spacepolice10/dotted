# Dotted iOS

A UIKit shell using Hotwire Native 1.3.1, targeting iOS 16 and later.
The existing Rails pages and cookie-based login run inside Hotwire's web view.
The native tab bar opens Index (`/search`), Daylog (`/bullets`), and User
(`/user`) in separate navigation stacks. Daylog is selected on launch; the other
tabs load when selected. Rails hides its HTML tab bar for iOS builds that advertise
`Dotted Native Tabs` in their user agent.

## Run locally

1. Start Rails from the repository root:

   ```sh
   cd web
   mise exec -- env -u BUNDLE_PATH bin/rails server -b 127.0.0.1 -p 3001
   ```

2. Open `native/ios/Dotted.xcodeproj` in Xcode.
3. Select the shared **Dotted** scheme and an iPhone simulator, then Run.

Debug builds connect to `http://localhost:3001`. The simulator shares the Mac's
network. An existing server on port 3001 can be reused.

To change the address, edit `Config/Debug.xcconfig` or add `DOTTED_SERVER_URL`
to the scheme's Run environment variables. On a physical phone, localhost is
the phone itself; use an accessible HTTPS server instead. Select your development
team in Signing & Capabilities before running on a physical device.

Release builds read `Config/Release.xcconfig`, require HTTPS, and reject the
placeholder deployment address. Configure that address before distribution.
Only the Debug Info.plist permits local networking; Release uses standard ATS.

## Build from the command line

From the repository root:

```sh
xcodebuild -project native/ios/Dotted.xcodeproj -scheme Dotted \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/dotted-ios-build CODE_SIGNING_ALLOWED=NO build
```

To open a simulator manually in Xcode 27, choose Xcode → Open Developer Tool →
Device Hub (or Manage Devices… in the run destination menu), then select a
simulated iPhone. Earlier Xcode versions use Open Developer Tool → Simulator.
If no compatible device is available, install an iOS runtime in Xcode Settings →
Components, then add a matching simulated iPhone in the device manager.
You can check Rails independently in the simulator's Safari at
`http://localhost:3001` before running the Dotted scheme.

The shell provides Hotwire navigation, its default loading/error handling, and
native tabs. Push notifications and offline editing are future work. No Rails
authentication changes are needed for the shell; verify email-code delivery
for the Rails environment you use.

Reference: https://native.hotwired.dev/ios/getting-started
