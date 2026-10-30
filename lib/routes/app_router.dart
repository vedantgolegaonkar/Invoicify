import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/widgets/main_layout.dart';
import '../features/authentication/presentation/screens/splash_screen.dart';
import '../features/authentication/presentation/screens/pin_lock_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/dashboard/presentation/screens/more_screen.dart';
import '../features/customers/presentation/screens/customer_list_screen.dart';
import '../features/customers/presentation/screens/add_edit_customer_screen.dart';
import '../features/customers/presentation/screens/customer_details_screen.dart';
import '../features/products/presentation/screens/product_list_screen.dart';
import '../features/products/presentation/screens/add_edit_product_screen.dart';
import '../features/products/presentation/screens/product_details_screen.dart';
import '../features/invoices/presentation/screens/invoice_list_screen.dart';
import '../features/invoices/presentation/screens/create_invoice_screen.dart';
import '../features/invoices/presentation/screens/invoice_details_screen.dart';
import '../features/payments/presentation/screens/payment_list_screen.dart';
import '../features/payments/presentation/screens/record_payment_screen.dart';
import '../features/payments/presentation/screens/payment_details_screen.dart';
import '../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../features/inventory/presentation/screens/stock_action_screen.dart';
import '../features/inventory/presentation/screens/inventory_history_screen.dart';
import '../features/reports/presentation/screens/reports_home_screen.dart';
import '../features/reports/presentation/screens/sales_report_screen.dart';
import '../features/reports/presentation/screens/customer_report_screen.dart';
import '../features/reports/presentation/screens/outstanding_report_screen.dart';
import '../features/reports/presentation/screens/product_report_screen.dart';
import '../features/reports/presentation/screens/inventory_report_screen.dart';
import '../features/reports/presentation/screens/payment_report_screen.dart';
import '../features/reports/presentation/screens/gst_report_screen.dart';
import '../features/reports/presentation/screens/collection_report_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/business_profile_screen.dart';
import '../features/settings/presentation/screens/invoice_settings_screen.dart';
import '../features/settings/presentation/screens/legal_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'shellDashboard');
final GlobalKey<NavigatorState> _shellNavigatorCustomersKey = GlobalKey<NavigatorState>(debugLabel: 'shellCustomers');
final GlobalKey<NavigatorState> _shellNavigatorInvoicesKey = GlobalKey<NavigatorState>(debugLabel: 'shellInvoices');
final GlobalKey<NavigatorState> _shellNavigatorMoreKey = GlobalKey<NavigatorState>(debugLabel: 'shellMore');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => const PinLockScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCustomersKey,
            routes: [
              GoRoute(
                path: '/customers',
                builder: (context, state) => const CustomerListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddEditCustomerScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => CustomerDetailsScreen(customerId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => AddEditCustomerScreen(customerId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          StatefulShellBranch(
            navigatorKey: _shellNavigatorInvoicesKey,
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoiceListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateInvoiceScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => InvoiceDetailsScreen(invoiceId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => CreateInvoiceScreen(invoiceId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorMoreKey,
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MoreScreen(),
              ),
              GoRoute(
                path: '/products',
                builder: (context, state) => const ProductListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddEditProductScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ProductDetailsScreen(productId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => AddEditProductScreen(productId: state.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: '/payments',
                builder: (context, state) => const PaymentListScreen(),
                routes: [
                  GoRoute(
                    path: 'record',
                    builder: (context, state) {
                      final invoiceId = state.uri.queryParameters['invoiceId'];
                      final invoiceNumber = state.uri.queryParameters['invoiceNumber'];
                      final customerId = state.uri.queryParameters['customerId'];
                      final amountStr = state.uri.queryParameters['amount'];
                      final amount = amountStr != null ? double.tryParse(amountStr) : null;
                      
                      return RecordPaymentScreen(
                        invoiceId: invoiceId,
                        invoiceNumber: invoiceNumber,
                        customerId: customerId,
                        amount: amount,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => PaymentDetailsScreen(paymentId: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'action',
                    builder: (context, state) {
                      final type = state.uri.queryParameters['type'] ?? 'in';
                      return StockActionScreen(actionType: type);
                    },
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const InventoryHistoryScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsHomeScreen(),
                routes: [
                  GoRoute(path: 'sales', builder: (context, state) => const SalesReportScreen()),
                  GoRoute(path: 'customers', builder: (context, state) => const CustomerReportScreen()),
                  GoRoute(path: 'outstanding', builder: (context, state) => const OutstandingReportScreen()),
                  GoRoute(path: 'products', builder: (context, state) => const ProductReportScreen()),
                  GoRoute(path: 'inventory', builder: (context, state) => const InventoryReportScreen()),
                  GoRoute(path: 'payments', builder: (context, state) => const PaymentReportScreen()),
                  GoRoute(path: 'gst', builder: (context, state) => const GstReportScreen()),
                  GoRoute(path: 'collection', builder: (context, state) => const CollectionReportScreen()),
                ],
              ),

              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'business-profile',
                    builder: (context, state) => const BusinessProfileScreen(),
                  ),
                  GoRoute(
                    path: 'invoice-settings',
                    builder: (context, state) => const InvoiceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'legal',
                    builder: (context, state) {
                      final tabStr = state.uri.queryParameters['tab'];
                      final tab = tabStr != null ? int.tryParse(tabStr) ?? 0 : 0;
                      return LegalScreen(initialTabIndex: tab);
                    },
                  ),
                  GoRoute(
                    path: 'terms-conditions',
                    builder: (context, state) => const LegalScreen(initialTabIndex: 0),
                  ),
                  GoRoute(
                    path: 'privacy-policy',
                    builder: (context, state) => const LegalScreen(initialTabIndex: 1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
