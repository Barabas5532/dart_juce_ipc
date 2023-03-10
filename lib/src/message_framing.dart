// ignore_for_file: public_member_api_docs

import "dart:async";
import "dart:typed_data";

import "package:logging/logging.dart";

import "debug_print.dart";
import "message_framing_state.dart";

/// Converts data from a socket into messages
///
/// This class will parse the input data as a byte stream, and output a full
/// message, exactly as it was sent at the other side of the connection.
class MessageFramingDecoder {
  MessageFramingDecoder({required int magic}) : _magic = magic;

  final _log = Logger("juce_ipc.message_framing");

  final int _magic;
  var _state = const MessageFramingDecoderState.header([]);

  void _processByte(int byte, EventSink<List<int>> sink) {
    _log.finest(
      "Received byte: ${byte.toPadded()} ${byte.toHex()} ${byte.toChar()}",
    );
    assert(0 <= byte && byte <= 0xFF);

    _state = _state.map(
      header: (header) {
        final newBytes = [...header.data, byte];
        _log.finest("Receiving header: ${newBytes.toHex()}");

        if (newBytes.length < 4 * 2) {
          return MessageFramingDecoderState.header(newBytes);
        } else {
          final bytes = Uint8List.fromList(newBytes).buffer.asByteData();
          final magic = bytes.getUint32(0, Endian.little);
          if (magic != _magic) {
            sink.addError(Exception("Magic was missing from received data"));
            return const MessageFramingDecoderState.header([]);
          }

          final messageSize = bytes.getUint32(4, Endian.little);
          _log.fine("Got header with message size $messageSize");
          return MessageFramingDecoderState.message(messageSize, []);
        }
      },
      message: (message) {
        final newState = message.copyWith(data: [...message.data, byte]);

        if (newState.data.length == message.size) {
          _log.fine(
            "Got message: ${newState.data.toHex()} ${newState.data.toChar()}",
          );
          sink.add(newState.data);
          return const MessageFramingDecoderState.header([]);
        }

        return newState;
      },
    );
  }

  void processBytes(List<int> input, EventSink<List<int>> sink) {
    for (final byte in input) {
      _processByte(byte, sink);
    }
  }
}

List<int> encodeFramedMessage(List<int> message, int magic) {
  final header = ByteData(2 * 4)
    ..setUint32(0, magic, Endian.little)
    ..setUint32(4, message.length, Endian.little);

  return [...header.buffer.asUint8List(), ...message];
}
