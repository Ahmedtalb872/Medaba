/// ملء الشاشة في المتصفح؛ لا يفعل شيئاً على المنصات الأخرى.
library;

export 'fullscreen_stub.dart'
    if (dart.library.js_interop) 'fullscreen_web.dart';
