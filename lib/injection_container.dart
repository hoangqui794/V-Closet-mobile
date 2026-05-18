import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/datasources/api_service.dart';

import 'data/datasources/bg_removal_service.dart';
import 'data/datasources/wardrobe_api_service.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  //! External
  await dotenv.load(fileName: ".env");

  sl.registerLazySingleton(() => Dio());
  
  //! Core
  sl.registerLazySingleton(() => ApiService(sl()));

  //! Features - V-Closet
  sl.registerLazySingleton(() => BgRemovalService(sl()));
  sl.registerLazySingleton(() => WardrobeApiService(sl()));
  // Register your Repositories, UseCases here
}
