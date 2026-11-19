import 'package:flutter/material.dart';

/// Global navigator so services (AI gateway, force-update gate) can show
/// safety-critical UI without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
