import 'dart:convert';

/// Offsets of a value in the formatted, exported JSON.
class JsonValueRange {
  const JsonValueRange(this.start, this.end);

  final int start;
  final int end;
}

JsonValueRange? findJsonValueRange(String source, List<Object> path) {
  try {
    final reader = _JsonRangeReader(source, path);
    reader.readValue(const []);
    return reader.match;
  } on FormatException {
    return null;
  }
}

class _JsonRangeReader {
  _JsonRangeReader(this.source, this.target);

  final String source;
  final List<Object> target;
  int offset = 0;
  JsonValueRange? match;

  void readValue(List<Object> path) {
    _skipWhitespace();
    final start = offset;
    if (offset >= source.length) throw const FormatException('Unexpected end of JSON');
    if (source[offset] == '{') {
      offset++;
      _skipWhitespace();
      if (!_consume('}')) {
        while (true) {
          final key = _readString();
          _skipWhitespace();
          _expect(':');
          readValue([...path, key]);
          _skipWhitespace();
          if (_consume('}')) break;
          _expect(',');
        }
      }
    } else if (source[offset] == '[') {
      offset++;
      _skipWhitespace();
      if (!_consume(']')) {
        var index = 0;
        while (true) {
          readValue([...path, index++]);
          _skipWhitespace();
          if (_consume(']')) break;
          _expect(',');
        }
      }
    } else if (source[offset] == '"') {
      _readString();
    } else {
      while (offset < source.length && !RegExp(r'[\s,}\]]').hasMatch(source[offset])) {
        offset++;
      }
      if (offset == start) throw const FormatException('Invalid JSON value');
    }
    if (_samePath(path, target)) match = JsonValueRange(start, offset);
  }

  String _readString() {
    _skipWhitespace();
    if (offset >= source.length || source[offset] != '"') {
      throw const FormatException('Expected JSON string');
    }
    final start = offset++;
    var escaped = false;
    while (offset < source.length) {
      final char = source[offset++];
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        return jsonDecode(source.substring(start, offset)) as String;
      }
    }
    throw const FormatException('Unterminated JSON string');
  }

  void _skipWhitespace() {
    while (offset < source.length && RegExp(r'\s').hasMatch(source[offset])) {
      offset++;
    }
  }

  bool _consume(String char) {
    if (offset < source.length && source[offset] == char) {
      offset++;
      return true;
    }
    return false;
  }

  void _expect(String char) {
    _skipWhitespace();
    if (!_consume(char)) throw FormatException('Expected $char');
  }

  bool _samePath(List<Object> path, List<Object> target) {
    if (path.length != target.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (path[i] != target[i]) return false;
    }
    return true;
  }
}
