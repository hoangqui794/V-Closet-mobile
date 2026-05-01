import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/datasources/api_service.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  //! External
  await dotenv.load(fileName: ".env");

  sl.registerLazySingleton(() => Dio());
  
  //! Core
  sl.registerLazySingleton(() => ApiService(sl()));

  //! Features - V-Closet
  // Register your Repositories, UseCases here
}
