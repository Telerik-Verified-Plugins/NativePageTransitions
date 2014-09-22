# Native Page Transitions Cordova / PhoneGap Plugin
by [Telerik](http://www.telerik.com)

## 0. Index

1. [Description](#1-description)
2. [Screenshots](#2-screenshots)
3. [Installation](#3-installation)
	3. [Automatically (CLI / Plugman)](#automatically-cli--plugman)
	3. [Manually](#manually)
4. [Usage](#4-usage)
5. [License](#5-license)

## 1. Description

Slide out the current page to reveal the next one. By a native transitions.

* Compatible with [Cordova Plugman](https://github.com/apache/cordova-plugman).
* For iOS and Android.

### Currently supported transtions

* slide left ("next page")
* slide right ("previous page")
* slide up
* slide down

## 2. Screenshots

iOS

<img src="screenshots/ios-share.png" width="235"/>&nbsp;
<img src="screenshots/ios-delete.png" width="235"/>&nbsp;
<img src="screenshots/ios-logout.png" width="235"/>


Android

<img src="screenshots/android-share.png" width="235"/>&nbsp;
<img src="screenshots/android-delete.png" width="235"/>&nbsp;
<img src="screenshots/android-logout.png" width="235"/>

## 3. Installation

### Automatically (CLI / Plugman)
Compatible with [Cordova Plugman](https://github.com/apache/cordova-plugman), compatible with [PhoneGap 3.0 CLI](http://docs.phonegap.com/en/3.0.0/guide_cli_index.md.html#The%20Command-line%20Interface_add_features), here's how it works with the CLI (backup your project first!):

```
$ phonegap local plugin add https://github.com/EddyVerbruggen/cordova-plugin-pagetransitions.git
```
or
```
$ cordova plugin add https://github.com/EddyVerbruggen/cordova-plugin-pagetransitions
$ cordova prepare
```

PageTransitions.js is brought in automatically. There is no need to change or add anything in your html.

### Manually

1\. Add the following xml to your `config.xml` files:

#### iOS
```xml
<feature name="PageTransitions">
  <param name="ios-package" value="PageTransitions" />
</feature>
```

#### Android
```xml
<feature name="PageTransitions">
  <param name="android-package" value="nl.xservices.plugins.pagetransitions.PageTransitions"/>
</feature>
```

2\. Grab a copy of PageTransitions.js, add it to your project and reference it in `index.html`:
```html
<script type="text/javascript" src="js/PageTransitions.js"></script>
```

3\. Download the source files and copy them to your project.

iOS: Copy the `.h` and `.m` files to `platforms/ios/<ProjectName>/Plugins`

Android: Copy `PageTransitions.java` to `src/nl/xservices/plugins/pagetransitions/`

### PhoneGap Build
PageTransitions is pending approval at PhoneGap build too. Hang on..

## 4. Usage (TODO: a few sample apps in the demo dir?)
Check the [demo code](demo) to get you going quickly,
or copy-paste some of the code below.

TODO STUFF BELOW..

```js
  var callback = function(buttonIndex) {
    setTimeout(function() {
      // like other Cordova plugins (prompt, confirm) the buttonIndex is 1-based (first button is index 1)
      alert('button index clicked: ' + buttonIndex);
    });
  };

  function testShareSheet() {
    var options = {
        'title': 'What do you want with this image?',
        'buttonLabels': ['Share via Facebook', 'Share via Twitter'],
        'androidEnableCancelButton' : true,
        'addCancelButtonWithLabel': 'Cancel',
        'addDestructiveButtonWithLabel' : 'Delete it'
    };
    // Depending on the buttonIndex, you can now call shareViaFacebook or shareViaTwitter
    // of the SocialSharing plugin (https://github.com/EddyVerbruggen/SocialSharing-PhoneGap-Plugin)
    window.plugins.actionsheet.show(options, callback);
  };

  function testDeleteSheet() {
    var options = {
        'addCancelButtonWithLabel': 'Cancel',
        'addDestructiveButtonWithLabel' : 'Delete note'
    };
    window.plugins.actionsheet.show(options, callback);
  };

  function testLogoutSheet() {
    var options = {
        'buttonLabels': ['Log out'],
        'androidEnableCancelButton' : true,
        'addCancelButtonWithLabel': 'Cancel'
    };
    window.plugins.actionsheet.show(options, callback);
  };
```

## 5. License

[The MIT License (MIT)](http://www.opensource.org/licenses/mit-license.html)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
