import '../../../common/domain/entities/eps_signal.dart';

class FeedState {
  const FeedState({this.loading = true, this.feed, this.error, this.lastUpdated});

  final bool loading;
  final EpsFeed? feed;

  /// Why the last poll failed; null once one succeeds.
  final String? error;
  final DateTime? lastUpdated;

  bool get isEmpty => feed == null || feed!.isEmpty;

  FeedState copyWith({bool? loading, EpsFeed? feed, String? error, DateTime? lastUpdated, bool clearError = false}) =>
      FeedState(
        loading: loading ?? this.loading,
        feed: feed ?? this.feed,
        error: clearError ? null : error ?? this.error,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}
