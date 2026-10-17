# Notes on how to create a release #

## Versioning ##
Versioning must follow the x.x.x format, breaking changes should be a major release.  
Set the version in Xcode (MARKETING_VERSION, and increase CURRENT_PROJECT_VERSION) for the HA Menu target.  
When publishing a release on https://github.com/pReya/ha-menu-x/releases, tag the release with the exact version number (e.g. 3.0.0). The New Version check reads the latest release from the releases.atom feed of that repository and shows the prompt when its tag is a newer version than the running app.  

To publish a beta release suffix beta to the tag, x.x.xbeta. Beta releases are never offered by the New Version check, the newest release without the suffix is used instead.  
You do not have to suffix the app version and if the beta release is suitable for a full release the tag can be edited to remove the beta suffix.

## Building ##
The app is ad-hoc signed and not notarized:

    xcodebuild -project "HA Menu.xcodeproj" -scheme "HA Menu" -configuration Release -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" clean build
    ditto -c -k --keepParent "build/DerivedData/Build/Products/Release/HA Menu X.app" "build/HA Menu X.zip"

Attach the zip to the release, GitHub names the asset HA.Menu.X.zip.

Running the tests launches the app as test host with your real settings, login item handling is skipped in that case.
