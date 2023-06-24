import 'package:flutter/material.dart';

mixin Messages<T extends StatefulWidget> on State<T> {
  void showError(String message, [VoidCallback? reload]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: reload == null
            ? const Duration(seconds: 5)
            : const Duration(days: 1),
        backgroundColor: Colors.red,
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(message),
            Visibility(
              visible: reload != null,
              child: TextButton(
                onPressed: reload,
                child: const Text("Tentar novamente"),
              ),
            )
          ],
        ),
      ),
    );
  }

  void hideError() {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
