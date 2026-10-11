"""Add a restricted debug launch adapter to the generated Godot Android template."""
from pathlib import Path

START = '\t// FOREST_ARENA_QA_START'
END = '\t// FOREST_ARENA_QA_END'
ADAPTER = '''
	// FOREST_ARENA_QA_START
	private java.util.List<String> forestArenaQaArgs = java.util.Collections.emptyList();
	private void readForestArenaQaArgs() {
		if (!BuildConfig.DEBUG) return;
		String[] args = getIntent().getStringArrayExtra("command_line_params");
		if (args == null || args.length != 3 || !"--".equals(args[0])) return;
		if (args[1] == null || args[2] == null) return;
		if (!args[1].matches("--qa-run=[A-Za-z0-9_-]{1,64}") ||
			!args[2].matches("--qa-device=[A-Za-z0-9_-]{1,64}")) return;
		forestArenaQaArgs = java.util.Arrays.asList(args);
	}
	@Override
	public java.util.List<String> getCommandLine() {
		java.util.List<String> args = new java.util.ArrayList<>(super.getCommandLine());
		if (BuildConfig.DEBUG) args.addAll(forestArenaQaArgs);
		return args;
	}
	// FOREST_ARENA_QA_END
'''


def prepare(source):
    if source.count(START) != source.count(END) or source.count(START) > 1:
        raise ValueError('손상된 QA Android 템플릿입니다.')
    if START in source:
        first = source.index(START) - 1
        last = source.index(END, first) + len(END) + 1
        source = source[:first] + source[last:]
    source = source.replace('\t\treadForestArenaQaArgs();\n', '')
    anchor = '\t\tSplashScreen splashScreen = SplashScreen.installSplashScreen(this);'
    if source.count(anchor) != 1 or source.count('public class GodotApp extends GodotActivity {') != 1:
        raise ValueError('지원하지 않는 Godot Android 템플릿입니다.')
    source = source.replace(anchor, '\t\treadForestArenaQaArgs();\n' + anchor)
    return source.replace('public class GodotApp extends GodotActivity {',
                          'public class GodotApp extends GodotActivity {' + ADAPTER)


def prepare_manifest(source):
    import xml.etree.ElementTree as ET
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    root = ET.fromstring(source)
    app = root.find('application')
    if app is None:
        raise ValueError('Android application이 없습니다.')
    name = '{http://schemas.android.com/apk/res/android}name'
    value = '{http://schemas.android.com/apk/res/android}value'
    for child in list(app):
        if child.tag == 'meta-data' and child.get(name) == 'org.forest_arena.qa_launch_adapter':
            app.remove(child)
    ET.SubElement(app, 'meta-data', {name: 'org.forest_arena.qa_launch_adapter', value: '1'})
    return ET.tostring(root, encoding='unicode') + '\n'


if __name__ == '__main__':
    target = Path('android/build/src/main/java/com/godot/game/GodotApp.java')
    target.write_text(prepare(target.read_text()))
    # Godot regenerates src/debug/AndroidManifest.xml on every export. The main
    # template persists; the marker advertises adapter presence, not activation.
    manifest = Path('android/build/src/main/AndroidManifest.xml')
    manifest.write_text(prepare_manifest(manifest.read_text()))
