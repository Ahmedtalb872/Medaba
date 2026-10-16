"""يضيف رقم نسخة لروابط ملفات تطبيق الويب حتى لا تعرض المتصفحات نسخة قديمة.

GitHub Pages يرسل الملفات مع Cache-Control: max-age=600 وأسماؤها ثابتة
(main.dart.js، flutter_bootstrap.js)، فكانت المتصفحات تعرض النسخة السابقة بعد كل نشر.
يُشغَّل بعد `flutter build web`:  python3 tool/cache_bust.py build/web <version>
"""
import pathlib
import re
import sys

web = pathlib.Path(sys.argv[1])
version = sys.argv[2]

boot = web / "flutter_bootstrap.js"
text = boot.read_text()
text, n = re.subn(
    r'"mainJsPath":"main\.dart\.js"',
    f'"mainJsPath":"main.dart.js?v={version}"',
    text,
)
if n != 1:
    sys.exit("mainJsPath not found in flutter_bootstrap.js")
# لا نستخدم Service Worker (مهمل في Flutter)، ونزيل أي واحد قديم مسجَّل في المتصفح.
start = text.rindex("_flutter.loader.load(")
text = text[:start] + (
    "if (navigator.serviceWorker) {\n"
    "  navigator.serviceWorker.getRegistrations()\n"
    "    .then((rs) => rs.forEach((r) => r.unregister()));\n"
    "}\n"
    "_flutter.loader.load({});\n"
)
boot.write_text(text)

index = web / "index.html"
html = index.read_text()
html, n = re.subn(
    r'src="flutter_bootstrap\.js"', f'src="flutter_bootstrap.js?v={version}"', html
)
if n != 1:
    sys.exit("flutter_bootstrap.js script tag not found in index.html")
index.write_text(html)
(web / "flutter_service_worker.js").unlink(missing_ok=True)
print(f"cache-busted {web} as v={version}")
