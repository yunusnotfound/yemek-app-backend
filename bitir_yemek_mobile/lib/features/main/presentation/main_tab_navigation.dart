import 'package:flutter/material.dart';

enum MainTab { home, orders }

/// Payment and success pages are separate Navigator routes. Attach return
/// actions to the actual main route; weak keys do not retain old sessions.
abstract final class MainTabNavigation {
  static final _handlers = Expando<ValueChanged<MainTab>>();

  static void register(
    ModalRoute<dynamic> route,
    ValueChanged<MainTab> handler,
  ) {
    _handlers[route] = handler;
  }

  static void unregister(ModalRoute<dynamic> route) {
    _handlers[route] = null;
  }

  static void returnTo(BuildContext context, MainTab tab) {
    Navigator.of(context).popUntil((route) {
      final handler = _handlers[route];
      if (handler != null) {
        handler(tab);
        return true;
      }
      return route.isFirst;
    });
  }
}
