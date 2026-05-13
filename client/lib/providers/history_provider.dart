import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/history_service.dart';

class HistoryState {
  final bool loading;
  final List<HistoryEntry> entries;

  const HistoryState({this.loading = false, this.entries = const []});

  HistoryState copyWith({bool? loading, List<HistoryEntry>? entries}) =>
      HistoryState(loading: loading ?? this.loading, entries: entries ?? this.entries);
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  final HistoryService _svc;

  HistoryNotifier(this._svc) : super(const HistoryState(loading: true)) {
    _load();
  }

  Future<void> _load() async {
    final entries = await _svc.load();
    state = HistoryState(entries: entries);
  }

  Future<void> addEntry(HistoryEntry entry) async {
    await _svc.save(entry);
    state = state.copyWith(entries: [entry, ...state.entries]);
  }

  Future<void> clear() async {
    await _svc.clear();
    state = const HistoryState();
  }

  void refresh() {
    state = const HistoryState(loading: true);
    _load();
  }
}

final historyServiceProvider = Provider<HistoryService>((ref) => HistoryService());

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  final svc = ref.watch(historyServiceProvider);
  return HistoryNotifier(svc);
});
