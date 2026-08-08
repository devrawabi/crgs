abstract final class RouteNames {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const shell = '/';
  static const dashboard = '/dashboard';
  static const routes = '/routes';
  static const routeCustomers = '/routes/:routeId';
  static const othersCustomers = '/others-customers';
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';
  static const visit = '/visit/:customerId';
  static const recovery = '/recovery/:customerId';
  static const productIntro = '/products/:customerId';
  static const followUp = '/follow-up';
  static const marketResearch = '/market-research';
  static const newCustomer = '/new-customer';
  static const outstanding = '/outstanding';
  static const tasks = '/tasks';
  static const orders = '/orders';
  static const profile = '/profile';
  static const reports = '/reports';
  static const settings = '/settings';
  static const changePassword = '/change-password';

  static String routeCustomersPath(String routeId) => '/routes/$routeId';

  static String marketResearchPath({String? routeId}) {
    final route = (routeId ?? '').trim();
    if (route.isEmpty) return marketResearch;
    return Uri(
      path: marketResearch,
      queryParameters: {'routeId': route},
    ).toString();
  }
}
