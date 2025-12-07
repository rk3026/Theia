import 'package:uuid/uuid.dart';

class TraceService {
  TraceService();

  final Uuid _uuid = const Uuid();
  final Map<String, String> _traceIndex = {};

  void registerTraceLink({required String key, required String reference}) {
    _traceIndex[key] = reference;
  }

  String recordEventKey(String label) {
    return '${label}_${_uuid.v4()}';
  }

  String? resolveReference(String key) {
    return _traceIndex[key];
  }

  Map<String, String> dumpTraceIndex() {
    return Map.unmodifiable(_traceIndex);
  }
}
