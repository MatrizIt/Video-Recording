import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;


void connectAndEmit(String comando) {
  bool open = false;
  IO.Socket socket = IO.io('http://192.168.1.193:65432', <String, dynamic>{
    'transports': ['websocket'],
  });
  if(open == false){

    socket.onConnect((_) {
      print('Conectado!');
      open = true;

      // Enviar um evento (emit)
      socket.emit('comando', comando);
    });
  }else if(open == true){
    socket.onDisconnect((_) {
      print('Desconectado!');
    });

    socket.close();
  }
}

/*final socket = IO.io('http://192.168.1.188:65432', <String, dynamic>{
  'transports': ['websocket'],
});

void _enviarComando(String comando) {
  socket.emit('comando', comando);
}*/
