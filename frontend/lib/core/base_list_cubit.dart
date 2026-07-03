import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'errors/app_exception.dart';

enum ListStatus { loading, loaded, error }

class ListState<T> extends Equatable {
  final ListStatus status;
  final List<T> items;
  final String? errorMessage;

  ListState({this.status = ListStatus.loading, List<T>? items, this.errorMessage}) : items = items ?? <T>[];

  ListState<T> copyWith({ListStatus? status, List<T>? items, String? errorMessage}) {
    return ListState<T>(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

/// Shared Loading/Loaded/Error shape for every screen that lists data from
/// a dummy service today and a real API tomorrow. Subclasses only need to
/// implement [fetch].
abstract class BaseListCubit<T> extends Cubit<ListState<T>> {
  BaseListCubit() : super(ListState<T>()) {
    load();
  }

  Future<List<T>> fetch();

  Future<void> load() async {
    emit(state.copyWith(status: ListStatus.loading));
    try {
      final items = await fetch();
      emit(state.copyWith(status: ListStatus.loaded, items: items));
    } on AppException catch (e) {
      emit(state.copyWith(status: ListStatus.error, errorMessage: e.message));
    }
  }
}
