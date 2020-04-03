## Native Page Transitions Cordova / PhoneGap Plugin
by [Telerik](http://www.telerik.com) and forked by [Mendix](https://mendix.com)

 This fork is to overcome the deprecation warning and eventual iOS App Store rejection of `UIWebView` code being present in the code. See [April 2020 App Store Deprecation](https://developer.apple.com/news/?id=12232019b) for more info. It assumes that the `WKWebViewOnly` preference is already applied on the project hence all instances of `UIWebView` has been removed.

> **WARNING**: This plugin is no longer maintained, and we now recommend using [NativeScript](https://www.nativescript.org/) as you get native transitions (and UI) out of the box.

Using the Cordova CLI?

```
cordova plugin add com.telerik.plugins.nativepagetransitions
```

Using PGB?

```xml
<plugin name="com.telerik.plugins.nativepagetransitions" source="https://github.com/mendix/cordova-plugin-secure-storage.git" />
```

[The MIT License (MIT)](http://www.opensource.org/licenses/mit-license.html)
