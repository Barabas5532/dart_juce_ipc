import "dart:async";
import "dart:convert";

import "package:dcli_core/dcli_core.dart";
import "package:juce_ipc/src/interprocess_connection.dart";
import "package:path/path.dart" as p;
import "package:stdlibc/stdlibc.dart";
import "package:test/test.dart";

Future<void> performTest(InterprocessConnection interprocess) async {
  final receivedMessages = interprocess.read.transform(utf8.decoder).toList();

  interprocess.write.write("1");
  interprocess.write.write("2");
  interprocess.write.write("3");

  await interprocess.write.flush();
  await interprocess.write.close();

  expect(await receivedMessages, ["1", "2", "3"]);
}

void main() {
  test("InterprocessConnection using named pipe", () async {
    await withTempDir((dir) async {
      final pipePath = p.join(dir, "test-named-pipe");
      mkfifo(pipePath, (6 << 6) | (0 << 3) | 0);
      final interprocess = InterprocessConnectionNamedPipe(pipePath);
      await performTest(interprocess);
    });
  });
}
