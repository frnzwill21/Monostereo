import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:hetu_script/hetu_script.dart';
import 'package:pub_semver/pub_semver.dart';

class SimpleResourceContext extends HTResourceContext<HTSource> {
  @override
  late final String root;
  @override
  final Set<String> included = <String>{};
  final Map<String, HTSource> _cached = {};
  @override
  final List<String> binaryFileExtensions = const [];

  SimpleResourceContext(String rootDir) {
    root = getAbsolutePath(dirName: rootDir);
  }

  @override
  String getAbsolutePath({String key = '', String? dirName, String? fileName}) {
    final normalized = super.getAbsolutePath(key: key, dirName: dirName, fileName: fileName);
    if (Platform.isWindows && normalized.startsWith('/')) {
      return normalized.substring(1);
    }
    return normalized;
  }

  @override
  bool contains(String key) {
    final normalized = getAbsolutePath(key: key, dirName: root);
    return path.isWithin(root, normalized);
  }

  @override
  void addResource(String fullName, HTSource resource) {
    final normalized = getAbsolutePath(key: fullName);
    _cached[normalized] = resource;
    included.add(normalized);
  }

  @override
  void removeResource(String fullName) {
    final normalized = getAbsolutePath(key: fullName);
    _cached.remove(normalized);
    included.remove(normalized);
  }

  @override
  HTSource getResource(String key, {String? from}) {
    final normalized = getAbsolutePath(key: key, dirName: from != null ? path.dirname(from) : root);
    if (_cached.containsKey(normalized)) {
      return _cached[normalized]!;
    }
    final content = File(normalized).readAsStringSync();
    final ext = path.extension(normalized);
    final source = HTSource(content, fullName: normalized, type: checkExtension(ext));
    addResource(normalized, source);
    return source;
  }

  @override
  void updateResource(String fullName, HTSource resource) {
    final normalized = getAbsolutePath(key: fullName);
    _cached[normalized] = resource;
  }
}

void compileHetu(String inputEntry, String outputPath, {String? versionString}) {
  final entryFile = File(inputEntry).absolute;
  final rootDir = entryFile.parent.path;
  final context = SimpleResourceContext(rootDir);
  final hetu = Hetu(sourceContext: context);
  hetu.init(useDefaultModuleAndBinding: false);
  
  final source = context.getResource(entryFile.path);
  
  print('Bundling ${entryFile.path}...');
  final compilation = hetu.bundler.bundle(
    source: source,
    parser: hetu.parser,
    version: versionString != null ? Version.parse(versionString) : null,
  );
  
  if (compilation.errors.isNotEmpty) {
    for (final err in compilation.errors) {
      print('ERROR: $err');
    }
    exit(1);
  }
  
  print('Compiling to bytecode with Hetu $kHetuVersion...');
  final bytes = hetu.compiler.compile(compilation);
  
  final outFile = File(outputPath);
  if (!outFile.parent.existsSync()) {
    outFile.parent.createSync(recursive: true);
  }
  outFile.writeAsBytesSync(bytes);
  print('Successfully wrote ${bytes.length} bytes to $outputPath');
}

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart run bin/compile_plugin.dart <entry.ht> <output.out> [version]');
    exit(1);
  }
  compileHetu(args[0], args[1], versionString: args.length > 2 ? args[2] : null);
}
