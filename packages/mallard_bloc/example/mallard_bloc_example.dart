import 'package:bloc/bloc.dart';
import 'package:mallard_bloc/mallard_bloc.dart';

import 'random_number_repository.dart';

typedef RandomNumberFetchState = TaskBlocState<int, RandomNumberFetchException>;

class RandomNumberFetchCubit extends Cubit<RandomNumberFetchState>
    with TaskCubitMixin {
  RandomNumberFetchCubit(this.randomRepository) : super(.initial());

  final RandomRepository randomRepository;

  Future<void> fetchRandomNumber() =>
      request(randomRepository.fetchRandomNumber());
}

void main() async {
  final cubit = RandomNumberFetchCubit(RandomRepository());

  cubit.stream.listen(
    (state) => switch (state.status) {
      .initial => print('Initial state'),
      .inProgress => print('Fetching random number...'),
      .succeeded => print('Random number fetched: ${state.success}'),
      .failed => print('Failed to fetch random number: ${state.failure}'),
    },
  );

  await cubit.fetchRandomNumber();
}
