import 'package:flutter/foundation.dart';

/// Registers the licenses of the JavaScript libraries bundled inside
/// `assets/editor/editor.html`.
///
/// Flutter's [LicenseRegistry] discovers `LICENSE` files from pub packages
/// automatically, but the markdown editor arrives as a pre-built asset rather
/// than a Dart dependency, so nothing in that bundle is visible to the
/// automatic collector. MIT and Apache-2.0 both require the notice to travel
/// with every copy of the work, and the shipped app binary is a copy — hence
/// registering them here rather than relying on `THIRD-PARTY.md`, which only
/// covers the source distribution.
///
/// Keep this in step with `hoodik/editor/package.json`.
void registerBundledEditorLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Milkdown'], _mit('2021 Mirone'));

    yield LicenseEntryWithLineBreaks([
      'ProseMirror',
    ], _mit('2015-2017 by Marijn Haverbeke <marijn@haverbeke.nl> and others'));

    yield LicenseEntryWithLineBreaks([
      'refractor',
    ], _mit('2016 Titus Wormer <tituswormer@gmail.com>'));

    yield const LicenseEntryWithLineBreaks(['DOMPurify'], _dompurify);
  });
}

/// DOMPurify is offered under `MPL-2.0 OR Apache-2.0`. We take it under
/// Apache-2.0: the MPL branch would oblige us to publish the source of the
/// MPL-covered files, and there is no reason to accept that when the dual
/// licence lets us choose.
const String _dompurify = '''
DOMPurify
Copyright 2024 Dr.-Ing. Mario Heiderich, Cure53

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

DOMPurify is dual-licensed; this distribution takes it under Apache-2.0.
''';

/// The MIT text is identical across these libraries apart from the copyright
/// line, so it is built from one template instead of pasted four times.
String _mit(String copyright) =>
    '''
Copyright (c) $copyright

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
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';
