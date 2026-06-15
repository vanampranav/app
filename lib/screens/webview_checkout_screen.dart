import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/cart_model.dart';
import '../models/address_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

class WebViewCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;

  const WebViewCheckoutScreen({
    Key? key,
    required this.checkoutUrl,
  }) : super(key: key);

  @override
  State<WebViewCheckoutScreen> createState() => _WebViewCheckoutScreenState();
}

class _WebViewCheckoutScreenState extends State<WebViewCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _retryCount = 0;
  static const int maxRetries = 3;
  Timer? _timeoutTimer;
  bool _isNetworkAvailable = true;
  String _deviceInfo = '';
  String _selectedUserAgent = '';

  @override
  void initState() {
    super.initState();
    _checkNetworkConnectivity();
    if (kIsWeb) {
      _openInNewTab();
    } else {
      _initializeWithDeviceInfo();
    }
  }

  // Await device info so the correct Chrome UA is set before the WebView loads.
  Future<void> _initializeWithDeviceInfo() async {
    await _initializeDeviceInfo();
    if (mounted) _initializeWebView();
  }

  Future<void> _initializeDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = 'Android ${androidInfo.version.release} - ${androidInfo.model}';
        _selectedUserAgent = _getOptimalUserAgent(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
        _selectedUserAgent = _getIOSUserAgent(iosInfo);
      }
      debugPrint('Device Info: $_deviceInfo');
      debugPrint('Selected User Agent: $_selectedUserAgent');
    } catch (e) {
      debugPrint('Error getting device info: $e');
      _selectedUserAgent = _getDefaultUserAgent();
    }
  }

  String _getOptimalUserAgent(AndroidDeviceInfo androidInfo) {
    // Use different user agents based on Android version and device capabilities
    final sdkInt = androidInfo.version.sdkInt;
    final model = androidInfo.model.toLowerCase();
    
    if (sdkInt >= 33) { // Android 13+
      return 'Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; ${androidInfo.model}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    } else if (sdkInt >= 29) { // Android 10+
      return 'Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; ${androidInfo.model}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36';
    } else if (sdkInt >= 26) { // Android 8+
      return 'Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; ${androidInfo.model}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36';
    } else {
      // Older Android versions
      return 'Mozilla/5.0 (Linux; Android ${androidInfo.version.release}; ${androidInfo.model}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36';
    }
  }

  String _getIOSUserAgent(IosDeviceInfo iosInfo) {
    final version = iosInfo.systemVersion.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $version like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
  }

  String _getDefaultUserAgent() {
    if (Platform.isAndroid) {
      return 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    } else if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Mobile; rv:120.0) Gecko/120.0 Firefox/120.0';
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      final hasNetwork = connectivityResult != ConnectivityResult.none;
      setState(() { _isNetworkAvailable = hasNetwork; });
      if (!hasNetwork) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No internet connection. Please check your network and try again.';
        });
      }
      // Don't pre-check URL — Shopify cart links return 404 to HEAD requests
      // because they require a real browser session to initialise the checkout.
    } catch (e) {
      // Connectivity check failure is non-fatal; let the WebView try anyway.
    }
  }

  void _initializeWebView() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        limitsNavigationsToAppBoundDomains: false,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    // Enhanced Android WebView configuration
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      (controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setUserAgent(_selectedUserAgent.isNotEmpty ? _selectedUserAgent : _getDefaultUserAgent())
        ..setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            return GeolocationPermissionsResponse(
              allow: false,
              retain: false,
            );
          },
        );
    }
    
    // Enhanced iOS WebView configuration
    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
        ..setAllowsBackForwardNavigationGestures(false)
        ..setUserAgent(_selectedUserAgent.isNotEmpty ? _selectedUserAgent : _getDefaultUserAgent());
    }

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          final msg = message.message;
          debugPrint('JavaScript message: $msg');

          // UPI deep-link intercepted from window.open override (iOS fix)
          if (msg.startsWith('upi_launch:')) {
            final upiUrl = msg.substring('upi_launch:'.length);
            debugPrint('UPI launch from JS bridge: $upiUrl');
            _launchExternalUrl(upiUrl);
            return;
          }

          if (msg.contains('shop_pay_callback')) {
            if (msg.contains('success')) {
              context.read<CartModel>().clearCart();
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order placed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%) - Device: $_deviceInfo');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url - Device: $_deviceInfo');
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
            
            // Set timeout for page load (longer for slower devices)
            _timeoutTimer?.cancel();
            final timeoutDuration = Platform.isIOS ? 
                const Duration(seconds: 45) : const Duration(seconds: 35);
            _timeoutTimer = Timer(timeoutDuration, () {
              if (_isLoading) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Page load timeout on $_deviceInfo. Please check your internet connection, try switching networks, or use a VPN.';
                  _isLoading = false;
                });
              }
            });
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url - Device: $_deviceInfo');
            _timeoutTimer?.cancel();
            setState(() {
              _isLoading = false;
            });

            // Detect Razorpay payment success from the URL itself
            if (url.contains('razorpay_payment_id') || url.contains('rzp_payment_id')) {
              context.read<CartModel>().clearCart();
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment successful! Order placed.'),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }
            
            // ── UPI window.open interceptor (ALL pages, including Razorpay) ──────
            // On iOS, Razorpay triggers UPI app opening via window.open('upi://...')
            // which bypasses onNavigationRequest entirely. We override window.open
            // here to catch it and post to FlutterBridge instead.
            controller.runJavaScript('''
              (function() {
                if (window._upiOverride) return;
                window._upiOverride = true;
                var UPI_RE = /^(upi|phonepe|tez|googlepay|gpay|paytm|bhim|amazonpay|razorpay|rzp):/i;
                var _orig = window.open;
                window.open = function(url, t, f) {
                  if (url && UPI_RE.test(url)) {
                    console.log('[EleFit] UPI intercepted via window.open: ' + url);
                    try { window.FlutterBridge.postMessage('upi_launch:' + url); } catch(e) {}
                    return { closed: false, close: function(){}, location: { href: '' } };
                  }
                  return _orig ? _orig.apply(this, arguments) : null;
                };
                document.addEventListener('click', function(e) {
                  var el = e.target;
                  for (var i = 0; i < 6 && el; i++, el = el.parentElement) {
                    if (el.tagName === 'A' && UPI_RE.test(el.href || '')) {
                      e.preventDefault();
                      e.stopPropagation();
                      console.log('[EleFit] UPI intercepted via anchor: ' + el.href);
                      try { window.FlutterBridge.postMessage('upi_launch:' + el.href); } catch(e2) {}
                      return;
                    }
                  }
                }, true);
              })();
            ''').catchError((_) {});

            // Only inject Shopify-specific scripts on Shopify / theelefit.com pages.
            // Razorpay's hosted checkout (api.razorpay.com / checkout.razorpay.com)
            // is cross-origin; running our DOM scripts there causes DOMExceptions
            // and breaks Razorpay's own JS.
            final isShopifyPage = url.contains('theelefit.com') ||
                url.contains('shopify.com') ||
                url.contains('myshopify.com');

            if (!isShopifyPage) return;

            final addressModel = context.read<AddressModel>();
            final autofillScript = addressModel.generateAutofillScript();

            controller.runJavaScript('''
              try {
                console.log('Checkout page loaded on: $_deviceInfo');

                // Strip X-Requested-With from JS-level XHR/fetch so Razorpay
                // does not identify this session as an unregistered Android app.
                // The native WebView adds this header automatically; overriding
                // setRequestHeader removes it from Razorpay's payment API calls.
                (function() {
                  var _origSetHeader = XMLHttpRequest.prototype.setRequestHeader;
                  XMLHttpRequest.prototype.setRequestHeader = function(n, v) {
                    if (n.toLowerCase() === 'x-requested-with') return;
                    _origSetHeader.call(this, n, v);
                  };
                  if (window.fetch) {
                    var _origFetch = window.fetch;
                    window.fetch = function(url, opts) {
                      if (opts && opts.headers) {
                        var h = opts.headers;
                        if (h instanceof Headers) {
                          h.delete('X-Requested-With');
                        } else if (typeof h === 'object') {
                          Object.keys(h).forEach(function(k) {
                            if (k.toLowerCase() === 'x-requested-with') delete h[k];
                          });
                        }
                      }
                      return _origFetch.call(this, url, opts);
                    };
                  }
                })();

                // Auto-fill saved address if available
                $autofillScript
                
                // Enhanced payment button detection and handling
                function handlePaymentButtons() {
                  console.log('Setting up payment button handlers');
                  
                  // Google Pay button selectors
                  var googlePaySelectors = [
                    'button[aria-label*="Google Pay"]',
                    'button[data-testid*="google-pay"]',
                    'button[class*="google-pay"]',
                    'div[data-brand="google_pay"]',
                    '.google-pay-button',
                    '[data-payment-method="google_pay"]',
                    'button:contains("Google Pay")',
                    'gpay-button'
                  ];
                  
                  // Shop Pay button selectors
                  var shopPaySelectors = [
                    'button[aria-label*="Shop Pay"]',
                    'button[data-testid*="shop-pay"]',
                    'button[class*="shop-pay"]',
                    'div[data-brand="shop_pay"]',
                    '.shop-pay-button',
                    '[data-payment-method="shop_pay"]',
                    'button:contains("Shop Pay")'
                  ];
                  
                  // PayPal button selectors
                  var paypalSelectors = [
                    'button[aria-label*="PayPal"]',
                    'button[data-testid*="paypal"]',
                    'div[data-brand="paypal"]',
                    '.paypal-button',
                    '[data-payment-method="paypal"]'
                  ];
                  
                  // Function to add click listeners to payment buttons
                  function addPaymentListeners(selectors, paymentType) {
                    selectors.forEach(function(selector) {
                      var buttons = document.querySelectorAll(selector);
                      buttons.forEach(function(button) {
                        if (!button.hasAttribute('data-flutter-handled')) {
                          button.setAttribute('data-flutter-handled', 'true');
                          
                          button.addEventListener('click', function(e) {
                            console.log(paymentType + ' button clicked');
                            
                            // Allow the original click to proceed
                            setTimeout(function() {
                              // Monitor for popup blockers or redirects
                              var checkForRedirect = setInterval(function() {
                                if (window.location.href !== url || 
                                    document.querySelector('[class*="popup"], [class*="modal"], [class*="overlay"]')) {
                                  console.log('Payment flow detected for ' + paymentType);
                                  clearInterval(checkForRedirect);
                                }
                              }, 100);
                              
                              // Clear the interval after 5 seconds
                              setTimeout(function() {
                                clearInterval(checkForRedirect);
                              }, 5000);
                            }, 100);
                          });
                          
                          console.log('Added listener to ' + paymentType + ' button');
                        }
                      });
                    });
                  }
                  
                  // Add listeners for all payment types
                  addPaymentListeners(googlePaySelectors, 'Google Pay');
                  addPaymentListeners(shopPaySelectors, 'Shop Pay');
                  addPaymentListeners(paypalSelectors, 'PayPal');
                }
                
                // Call immediately and set up observer
                handlePaymentButtons();
                
                // Set up mutation observer for dynamically loaded payment buttons
                var paymentObserver = new MutationObserver(function(mutations) {
                  var hasNewButtons = false;
                  mutations.forEach(function(mutation) {
                    if (mutation.addedNodes.length > 0) {
                      mutation.addedNodes.forEach(function(node) {
                        if (node.nodeType === 1) {
                          var hasPaymentButton = node.querySelector && (
                            node.querySelector('[class*="pay"], [data-brand], [aria-label*="Pay"]') ||
                            node.matches && node.matches('[class*="pay"], [data-brand], [aria-label*="Pay"]')
                          );
                          if (hasPaymentButton) {
                            hasNewButtons = true;
                          }
                        }
                      });
                    }
                  });
                  
                  if (hasNewButtons) {
                    setTimeout(handlePaymentButtons, 500);
                  }
                });
                
                paymentObserver.observe(document.body, {
                  childList: true,
                  subtree: true
                });
                
                // Listen for Shopify checkout events
                if (window.Shopify && window.Shopify.Checkout) {
                  window.Shopify.Checkout.OrderStatus.addCallback(function(orderStatus) {
                    console.log('Order status:', orderStatus);
                    if (orderStatus.status === 'complete') {
                      window.FlutterBridge.postMessage('shop_pay_callback:success');
                    }
                  });
                }

                // Razorpay payment event listeners
                (function() {
                  // Listen for Razorpay success/failure postMessage events
                  window.addEventListener('message', function(event) {
                    if (!event.data) return;
                    var data = (typeof event.data === 'string') ? event.data : JSON.stringify(event.data);
                    console.log('PostMessage received:', data);
                    if (data.indexOf('razorpay') !== -1 || data.indexOf('payment_id') !== -1) {
                      if (data.indexOf('success') !== -1 || data.indexOf('payment_id') !== -1) {
                        console.log('Razorpay payment success detected via postMessage');
                        window.FlutterBridge.postMessage('shop_pay_callback:success');
                      }
                    }
                  });

                  // Patch Razorpay handler if SDK is present on page
                  function patchRazorpay() {
                    if (window.Razorpay) {
                      var _orig = window.Razorpay;
                      window.Razorpay = function(options) {
                        var origSuccess = options.handler;
                        options.handler = function(response) {
                          console.log('Razorpay payment success:', response.razorpay_payment_id);
                          if (origSuccess) origSuccess(response);
                          // Notify Flutter after a short delay to let Shopify process
                          setTimeout(function() {
                            window.FlutterBridge.postMessage('shop_pay_callback:success');
                          }, 2000);
                        };
                        return new _orig(options);
                      };
                      window.Razorpay.prototype = _orig.prototype;
                      console.log('Razorpay SDK patched for Flutter bridge');
                    }
                  }
                  patchRazorpay();
                  // Also retry after DOM settles in case Razorpay loads later
                  setTimeout(patchRazorpay, 2000);
                  setTimeout(patchRazorpay, 5000);
                })();
                
                // Enhanced completion detection
                function checkForCompletion() {
                  // Razorpay payment ID in URL = payment captured
                  if (window.location.href.indexOf('razorpay_payment_id') !== -1 ||
                      window.location.href.indexOf('rzp_payment_id') !== -1) {
                    console.log('Razorpay payment ID detected in URL');
                    window.FlutterBridge.postMessage('shop_pay_callback:success');
                    return true;
                  }

                  // Enhanced detection for various checkout completion indicators
                  var thankYouElements = document.querySelectorAll([
                    '[data-testid="thank-you"]',
                    '[data-step="thank_you"]',
                    '.thank-you',
                    '.order-confirmation',
                    '.checkout-complete',
                    '.order-complete',
                    'h1:contains("Thank you")',
                    'h2:contains("Order confirmed")',
                    '.step-thank-you',
                    '[class*="thank"]',
                    '[class*="complete"]',
                    '[class*="success"]'
                  ].join(', '));
                  
                  var completionText = document.body.innerText.toLowerCase();
                  var hasCompletionText = completionText.includes('thank you') ||
                                        completionText.includes('order confirmed') ||
                                        completionText.includes('order complete') ||
                                        completionText.includes('payment successful');
                  
                  if (thankYouElements.length > 0 || hasCompletionText) {
                    console.log('Checkout completion detected via elements/text');
                    window.FlutterBridge.postMessage('shop_pay_callback:success');
                    return true;
                  }
                  return false;
                }
                
                // Check immediately
                if (!checkForCompletion()) {
                  // Set up enhanced observer with debouncing
                  var timeoutId;
                  var completionObserver = new MutationObserver(function(mutations) {
                    clearTimeout(timeoutId);
                    timeoutId = setTimeout(function() {
                      checkForCompletion();
                    }, 500);
                  });
                  
                  completionObserver.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['class', 'data-step', 'data-testid']
                  });
                  
                  // Monitor URL changes (wrapped in try-catch: some pages
                  // block history patching and throw DOMException)
                  try {
                    var originalPushState = history.pushState;
                    var originalReplaceState = history.replaceState;
                    history.pushState = function() {
                      originalPushState.apply(history, arguments);
                      setTimeout(checkForCompletion, 1000);
                    };
                    history.replaceState = function() {
                      originalReplaceState.apply(history, arguments);
                      setTimeout(checkForCompletion, 1000);
                    };
                    window.addEventListener('popstate', function() {
                      setTimeout(checkForCompletion, 1000);
                    });
                  } catch(histErr) {
                    console.log('history patching skipped:', histErr.message);
                  }
                }
                
              } catch (e) {
                console.error('Error in checkout detection script:', e);
              }
            ''').catchError((error) {
              debugPrint('JavaScript injection error: $error');
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Resource error [${error.errorType}]: ${error.description}');

            // Only show the error screen for DNS failures (server not found)
            // or genuine timeouts.
            //
            // ERR_CONNECTION_REFUSED (type: connect) is intentionally excluded:
            // Razorpay's checkout JS tries to open WebSocket / telemetry
            // connections that are refused on emulators and restricted networks.
            // Those are sub-resource failures that do NOT prevent payment.
            const fatalTypes = {
              WebResourceErrorType.hostLookup,
              WebResourceErrorType.timeout,
            };
            if (fatalTypes.contains(error.errorType)) {
              setState(() {
                _hasError = true;
                _errorMessage = _getFriendlyErrorMessage(error);
                _isLoading = false;
              });
            }
            // connect / unknown / authentication / unsupportedScheme → log only.
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            final urlLower = url.toLowerCase();
            debugPrint('Navigation: $url');

            // ── App deep-link schemes → open the native app ──────────────
            // These must be intercepted BEFORE the http/https check.
            const appSchemes = [
              'upi://', 'intent://',
              'tez://', 'googlepay://',
              'paytm://', 'phonepe://', 'bhim://',
              'amazonpay://', 'razorpay://', 'rzp://',
              'market://',
            ];
            if (appSchemes.any((s) => urlLower.startsWith(s))) {
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            // ── Allow ALL http / https navigation ────────────────────────
            // Razorpay, Shopify, CDNs, analytics — we cannot predict every
            // domain the payment SDK will touch, so we let the WebView load
            // anything over http/https and rely on the Android network
            // security config for cleartext policy.
            if (urlLower.startsWith('http://') || urlLower.startsWith('https://')) {
              return NavigationDecision.navigate;
            }

            // ── Everything else (unknown schemes) → block ─────────────────
            debugPrint('Blocked unknown scheme: $url');
            return NavigationDecision.prevent;
          },
        ),
      )..loadRequest(Uri.parse(widget.checkoutUrl));

    _controller = controller;
  }

  String _getFriendlyErrorMessage(WebResourceError error) {
    final deviceContext = _deviceInfo.isNotEmpty ? ' on $_deviceInfo' : '';
    
    switch (error.errorType) {
      case WebResourceErrorType.hostLookup:
        return 'Unable to connect to checkout server$deviceContext. This may be due to network restrictions or DNS issues. Try:\n• Switching to mobile data\n• Using a VPN\n• Changing DNS to 8.8.8.8';
      case WebResourceErrorType.timeout:
        return 'Connection timed out$deviceContext. The checkout server may be slow or unreachable. Try:\n• Waiting and retrying\n• Using a different network\n• Enabling VPN';
      case WebResourceErrorType.connect:
        return 'Failed to connect to checkout server$deviceContext. This could be due to:\n• Network firewall blocking the connection\n• ISP restrictions\n• Server maintenance\n\nSolutions:\n• Switch to mobile data\n• Use a VPN\n• Try again later';
      case WebResourceErrorType.authentication:
        return 'Authentication failed$deviceContext. The checkout session may have expired. Please:\n• Go back and try again\n• Clear app cache\n• Contact support if issue persists';
      case WebResourceErrorType.unsupportedScheme:
        return 'Unsupported URL scheme$deviceContext. The checkout link may be invalid. Please contact support.';
      case WebResourceErrorType.redirectLoop:
        return 'Redirect loop detected$deviceContext. This may be a server configuration issue. Try:\n• Clearing app cache\n• Using external browser\n• Contact support';
      case WebResourceErrorType.fileNotFound:
        return 'Checkout page not found$deviceContext. The link may be expired or invalid. Please:\n• Go back and try again\n• Contact support if issue persists';
      case WebResourceErrorType.tooManyRequests:
        return 'Too many requests$deviceContext. Please wait a moment and try again.';
      case WebResourceErrorType.unknown:
      default:
        // Provide device-specific guidance for unknown errors
        String deviceSpecificAdvice = '';
        if (Platform.isAndroid) {
          deviceSpecificAdvice = '\n\nAndroid-specific solutions:\n• Enable "Allow third-party cookies"\n• Disable battery optimization for this app\n• Try clearing WebView cache';
        } else if (Platform.isIOS) {
          deviceSpecificAdvice = '\n\niOS-specific solutions:\n• Check Safari settings\n• Enable JavaScript\n• Try restarting the app';
        }
        
        return 'Checkout page failed to load$deviceContext.\n\nError: ${error.description}\n\nGeneral solutions:\n• Check internet connection\n• Try using VPN\n• Switch networks\n• Use external browser$deviceSpecificAdvice';
    }
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.clearCache();
    _controller.clearLocalStorage();
    _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _launchExternalUrl(String url) async {
    debugPrint('Attempting to launch external URL: $url');
    
    try {
      // Handle different types of payment URLs
      if (url.toLowerCase().startsWith('intent://')) {
        await _handleAndroidIntent(url);
      } else if (url.toLowerCase().contains('googlepay') || 
                 url.toLowerCase().contains('tez://') ||
                 url.toLowerCase().contains('pay.google.com')) {
        await _handleGooglePay(url);
      } else if (url.toLowerCase().contains('upi://') ||
                 url.toLowerCase().contains('paytm://') ||
                 url.toLowerCase().contains('phonepe://') ||
                 url.toLowerCase().contains('bhim://')) {
        await _handleUPIPayment(url);
      } else {
        // Generic external URL handling
        await _launchGenericUrl(url);
      }
    } catch (e) {
      debugPrint('Error launching external URL: $e');
      await _showPaymentError(url, e.toString());
    }
  }
  
  Future<void> _handleAndroidIntent(String intentUrl) async {
    if (Platform.isIOS) {
      // intent:// is Android-only — ignore on iOS.
      debugPrint('Skipping Android intent URL on iOS: $intentUrl');
      return;
    }

    debugPrint('Handling Android intent: $intentUrl');
    try {
      final Uri uri = Uri.parse(intentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      final packageMatch = RegExp(r'package=([^;]+)').firstMatch(intentUrl);
      if (packageMatch != null) {
        final packageName = packageMatch.group(1);
        final appUri = Uri.parse('market://details?id=$packageName');
        if (await canLaunchUrl(appUri)) {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      throw Exception('Could not handle intent URL');
    } catch (e) {
      debugPrint('Intent handling failed: $e');
      rethrow;
    }
  }
  
  Future<void> _handleGooglePay(String url) async {
    debugPrint('Handling Google Pay URL: $url');

    final List<String> googlePayUrls = [
      url,
      'googlepay://pay',
      'tez://pay',
    ];

    for (final payUrl in googlePayUrls) {
      try {
        final Uri uri = Uri.parse(payUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {
        debugPrint('Failed to launch Google Pay URL $payUrl: $e');
      }
    }

    // Fallback: open the store page for Google Pay
    if (Platform.isIOS) {
      await launchUrl(
        Uri.parse('https://apps.apple.com/app/google-pay/id1193357041'),
        mode: LaunchMode.externalApplication,
      );
    } else {
      await _openPlayStore('com.google.android.apps.nfc.payment');
    }
  }
  
  Future<void> _handleUPIPayment(String url) async {
    debugPrint('Handling UPI payment URL: $url');

    try {
      final Uri uri = Uri.parse(url);
      if (Platform.isIOS) {
        // On iOS, skip canLaunchUrl — it can return false even when the app IS
        // installed if the user gesture window has expired. Try launching directly
        // instead; iOS will show its own "app not installed" prompt if needed.
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
        // Fallback: try without specifying a mode
        try {
          await launchUrl(uri);
          return;
        } catch (_) {}
        // App genuinely not installed — show App Store options.
        if (mounted) await _showUPIAppOptions();
        return;
      }

      // Android path
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('UPI payment launch failed: $e');
    }

    await _showUPIAppOptions();
  }
  
  Future<void> _launchGenericUrl(String url) async {
    final Uri uri = Uri.parse(url);
    
    // Try different launch modes
    final List<LaunchMode> modes = [
      LaunchMode.externalApplication,
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.platformDefault,
    ];
    
    for (LaunchMode mode in modes) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: mode);
          debugPrint('Successfully launched URL with mode: $mode');
          return;
        }
      } catch (e) {
        debugPrint('Failed to launch with mode $mode: $e');
        continue;
      }
    }
    
    throw Exception('Could not launch URL with any mode');
  }
  
  Future<void> _openPlayStore(String packageName) async {
    try {
      final playStoreUri = Uri.parse('market://details?id=$packageName');
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
      
      // Fallback to web Play Store
      final webPlayStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
      if (await canLaunchUrl(webPlayStoreUri)) {
        await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open Play Store: $e');
    }
  }
  
  Future<void> _showUPIAppOptions() async {
    if (!mounted) return;

    if (Platform.isIOS) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('UPI App Required'),
          content: const Text(
              'You need a UPI payment app installed to complete this payment. '
              'Install one from the App Store:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                launchUrl(
                  Uri.parse('https://apps.apple.com/app/phonepe/id1173054228'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('PhonePe'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                launchUrl(
                  Uri.parse('https://apps.apple.com/app/google-pay/id1193357041'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Google Pay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                launchUrl(
                  Uri.parse('https://apps.apple.com/app/paytm/id473941634'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Paytm'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('UPI Payment'),
          content: const Text(
              'Please install a UPI app like Google Pay, PhonePe, or Paytm to complete the payment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _openPlayStore('com.google.android.apps.nfc.payment');
              },
              child: const Text('Install Google Pay'),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _showPaymentError(String url, String error) async {
    if (!mounted) return;
    
    debugPrint('Payment error for URL $url: $error');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment app could not be opened'),
            const SizedBox(height: 4),
            Text(
              'Please ensure you have the required payment app installed',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Install Apps',
          textColor: Colors.white,
          onPressed: () => _showUPIAppOptions(),
        ),
      ),
    );
  }

  Future<void> _openInNewTab() async {
    final Uri url = Uri.parse(widget.checkoutUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          final completed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Order Status'),
              content: const Text('Did you complete your order?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('NO'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('YES'),
                ),
              ],
            ),
          );

          if (completed == true) {
            context.read<CartModel>().clearCart();
            Navigator.of(context).pop(true);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order placed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            Navigator.of(context).pop(false);
          }
        }
      } else {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Could not open checkout page - ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave Checkout?'),
            content: const Text('Are you sure you want to leave the checkout process? Your progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('STAY'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('LEAVE'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final shouldClose = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Leave Checkout?'),
                  content: const Text('Are you sure you want to leave the checkout process? Your progress will be lost.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('STAY'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('LEAVE'),
                    ),
                  ],
                ),
              );
              if (shouldClose == true) {
                Navigator.of(context).pop(false);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            if (_hasError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load checkout page',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_retryCount < maxRetries)
                      ElevatedButton(
                        onPressed: _retryLoad,
                        child: const Text('Retry'),
                      )
                    else ...[
                      ElevatedButton(
                        onPressed: _retryLoad,
                        child: const Text('Retry with Cache Cleared'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _openInNewTab,
                        child: const Text('Open in Browser'),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tip: Try switching to a different network, changing DNS (e.g., 8.8.8.8), or using a VPN.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading checkout...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}