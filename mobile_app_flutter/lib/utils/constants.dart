class ApiConstants {
  // 10.0.2.2 is the magic IP that tells the Android Emulator
  // to talk to your computer's localhost port.
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String recommendEndpoint = '/recommendations';
  static const String sousChefEndpoint = '/cook';
}