import 'dart:async';


class EventDispatcher {
  factory EventDispatcher() {
    return _manager;
  }

  static final EventDispatcher _manager = EventDispatcher._internal();
  EventDispatcher._internal();

  // Structure of the stream data:
  // {
  //   "type": "<some message type descriptor>"
  //   "data": any
  // }

  StreamController<Map<String, dynamic>> _stream = new StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _stream.stream;

  void emit(String type, dynamic data) {
    _stream.sink.add({
      "type": type,
      "data": data
    });
  }

  dispose() {
    _stream.close();
  }
}
