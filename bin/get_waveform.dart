import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

String getArrayType(int bitDepth) {
  switch (bitDepth) {
    case 8:
      return 'b';
    case 16:
      return 'h';
    case 32:
      return 'i';
    default:
      throw Exception('bitDepth $bitDepth is invalid');
  }
}

class WavData {
  final int audioFormat;
  final int channels;
  final int sampleRate;
  final int bitDepth;
  final Uint8List rawData;

  WavData(this.audioFormat, this.channels, this.sampleRate, this.bitDepth,
      this.rawData);

  @override
  String toString() {
    return 'WavData(audioFormat=$audioFormat, channels=$channels, sampleRate=$sampleRate, bitDepth=$bitDepth, rawData=${rawData.toString()})';
  }
}

class WavSubChunk {
  final List<int> subchunkId;
  final int position;
  final int subchunkSize;

  WavSubChunk(this.subchunkId, this.position, this.subchunkSize);

  @override
  String toString() {
    var id = String.fromCharCodes(subchunkId);
    return 'WavSubChunk(id=$id, posithin=$position, size=$subchunkSize)';
  }
}

List<int> unpackFrom(String format, Endian endian, Uint8List bytes) {
  var byteData = ByteData.sublistView(bytes);
  List<int> result = [];
  switch (format) {
    case 'i':
      for (var i = 0; i < bytes.length / 4; i++) {
        result.add(byteData.getInt32(i * 4, endian));
      }
      break;
    case 'I':
      for (var i = 0; i < bytes.length / 4; i++) {
        result.add(byteData.getUint32(i * 4, endian));
      }
      break;
    case 'h':
      for (var i = 0; i < bytes.length / 2; i++) {
        result.add(byteData.getInt16(i * 2, endian));
      }
      break;
    case 'H':
      for (var i = 0; i < bytes.length / 2; i++) {
        result.add(byteData.getUint16(i * 2, endian));
      }
      break;
    default:
      throw Exception('Unknown format was input: $format');
  }

  return result;
}

List<int> pack(String format, int value) {
  switch (format) {
    case 'i':
      return Int8List(4)..buffer.asInt32List()[0] = value;
    case 'I':
      return Uint8List(4)..buffer.asInt32List()[0] = value;
    case 'h':
      return Int8List(2)..buffer.asInt16List()[0] = value;
    case 'H':
      return Uint8List(2)..buffer.asInt16List()[0] = value;
    default:
      throw Exception("Unknown format was input: $format");
  }
}

WavData readWavAudio(Uint8List data) {
  var headers = extractWavHeader(data);

  var fmts = headers
      .where((subchunk) =>
          subchunk.subchunkId.toString() == 'fmt '.codeUnits.toString())
      .toList();

  if (fmts.isEmpty || fmts[0].subchunkSize < 16) {
    throw Exception("Couldn't find fmt header in wav data");
  }

  var fmt = fmts[0];
  var pos = fmt.position + 8;

  var audioFormat =
      unpackFrom('H', Endian.little, data.sublist(pos, pos + 2))[0];
  if (audioFormat != 1 && audioFormat != 0xFFFE) {
    throw Exception('Unknown audio format $audioFormat in wav data');
  }

  var channels =
      unpackFrom('H', Endian.little, data.sublist(pos + 2, pos + 4))[0];
  var sampleRate =
      unpackFrom('I', Endian.little, data.sublist(pos + 4, pos + 8))[0];
  var bitDepth =
      unpackFrom('H', Endian.little, data.sublist(pos + 14, pos + 16))[0];

  var dataHdr = headers.last;
  if (dataHdr.subchunkId.toString() != 'data'.codeUnits.toString()) {
    throw Exception("Couldn't find data header in wav data");
  }

  pos = dataHdr.position + 8;
  return WavData(audioFormat, channels, sampleRate, bitDepth,
      data.sublist(pos, pos + dataHdr.subchunkSize));
}

Uint8List fixWavHeaders(Uint8List data) {
  var headers = extractWavHeader(data);

  var isData =
      headers.last.subchunkId.toString() != 'data'.codeUnits.toString();
  if (isData) return data;

  if (data.length > pow(2, 32)) throw Exception('Unable to process >4GB files');

  var pos = headers.last.position;
  var fileSize = pack('I', data.length - 8);
  var dataSize = pack('I', data.length - pos - 8);
  for (var i = 4; i < 8; i++) {
    data[i] = fileSize[i - 4];
    data[pos + i] = dataSize[i - 4];
  }

  return data;
}

List<WavSubChunk> extractWavHeader(Uint8List data) {
  var pos = 12;
  List<WavSubChunk> subchunks = [];
  while (pos + 8 <= data.length && subchunks.length < 10) {
    var subchunkId = data.sublist(pos, pos + 4);
    var subchunkSize =
        unpackFrom('I', Endian.little, data.sublist(pos + 4, pos + 8))[0];

    subchunks.add(WavSubChunk(subchunkId, pos, subchunkSize));

    if (subchunkId.toString() == 'data'.codeUnits.toString()) break;
    pos += subchunkSize + 8;
  }

  return subchunks;
}

// Future<List<int>> getWavefrom(String path) async {
//   var result = await Process.run('ffmpeg', ['-i', path, '-f', 'wav', '-']);

//   var out = Uint8List.fromList(result.stdout.codeUnits);
//   var fixed = fixWavHeaders(out);
//   var wav = readWavAudio(fixed);
//   return unpackFrom(getArrayType(wav.bitDepth), Endian.little, wav.rawData);
// }

void main(List<String> arguments) async {
  // var path = './assets/MissFireSystem.mp3';
  // var waveform = await getWavefrom(path);

  await Process.run('ffmpeg', [
    '-i',
    './assets/MissFireSystem.mp3',
    '-f',
    'wav',
    './assets/MissFireSystem.wav'
  ]);

  var file = File("./assets/MissFireSystem.wav");
  var bytes = file.readAsBytesSync();
  var fixed = fixWavHeaders(bytes);
  var wav = readWavAudio(fixed);
  print(wav.toString());
}
