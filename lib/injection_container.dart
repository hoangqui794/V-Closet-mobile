import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasources/api_service.dart';
import 'data/datasources/auth_local_storage.dart';
import 'data/datasources/auth_api_service.dart';
import 'data/datasources/user_api_service.dart';

import 'data/datasources/bg_removal_service.dart';
import 'data/datasources/outfit_api_service.dart';
import 'data/datasources/wardrobe_api_service.dart';
import 'data/datasources/tryon_api_service.dart';
import 'data/datasources/affiliate_api_service.dart';
import 'data/datasources/subscription_api_service.dart';
import 'data/datasources/gemini_api_service.dart';

final sl = GetIt.instance; // sl: Service Locator

Future<void> init() async {
  //! External
  await dotenv.load(fileName: ".env");

  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  sl.registerLazySingleton(() => Dio());
  
  //! Core
  sl.registerLazySingleton(() => AuthLocalStorage(sl()));
  sl.registerLazySingleton(() => ApiService(sl()));

  //! Features - V-Closet
  sl.registerLazySingleton(() => AuthApiService(sl(), sl()));
  sl.registerLazySingleton(() => UserApiService(sl()));
  sl.registerLazySingleton(() => BgRemovalService(sl()));
  sl.registerLazySingleton(() => OutfitApiService(sl()));
  sl.registerLazySingleton(() => WardrobeApiService(sl()));
  sl.registerLazySingleton(() => TryOnApiService(sl()));
  sl.registerLazySingleton(() => AffiliateApiService(sl()));
  sl.registerLazySingleton(() => SubscriptionApiService(sl()));
  sl.registerLazySingleton(() => GeminiApiService());
  // Register your Repositories, UseCases here
}
