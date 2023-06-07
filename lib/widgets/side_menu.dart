import 'dart:html';

import 'package:dashboard_call_recording/constants/size_constants.dart';
import 'package:dashboard_call_recording/src/get_user_media_recording_web.dart';
import 'package:dashboard_call_recording/src/get_user_media_recording.dart';
import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:flutter/material.dart';

class SideMenuPage extends StatefulWidget {
  const SideMenuPage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<SideMenuPage> createState() => _SideMenuPageState();
}

class _SideMenuPageState extends State<SideMenuPage> {
  PageController page = PageController();
  SideMenuController sideMenu = SideMenuController();
  @override
  void initState() {
    sideMenu.addListener((p0) {
      page.jumpToPage(p0);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < SizeConstants.wideScreenBreakpoint;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SideMenu(
            controller: sideMenu,
            style: SideMenuStyle(
              // showTooltip: false,
              displayMode: SideMenuDisplayMode.auto,
              hoverColor: Colors.blue[100],
              selectedColor: Colors.lightBlue,
              selectedTitleTextStyle: const TextStyle(color: Colors.white),
              selectedIconColor: Colors.white,
              // decoration: BoxDecoration(
              //   borderRadius: BorderRadius.all(Radius.circular(10)),
              // ),
              // backgroundColor: Colors.blueGrey[700]
            ),
            title: const Column(
              children: [
                 Divider(
                  indent: 8.0,
                  endIndent: 8.0,
                ),
              ],
            ),
            footer: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                '',
                style: TextStyle(fontSize: 15),
              ),
            ),
            items: [
              SideMenuItem(
                priority: 0,
                title: 'Inicio',
                onTap: (page, _) {
                  sideMenu.changePage(page);
                },
                icon: const Icon(Icons.home),
              ),
              SideMenuItem(
                priority: 1,
                title: 'Gravação de video',
                onTap: (page, _) {
                  sideMenu.changePage(page);
                  window.open('/videoRecording/#/recording', '_blank');
                },
                icon: const Icon(Icons.supervisor_account),
                trailing: Container(
                    decoration: const BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.all(Radius.circular(6))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6.0, vertical: 3),
                      child: Text(
                        'New',
                        style: TextStyle(fontSize: 11, color: Colors.grey[800]),
                      ),
                    )),
              ),
            ],
          ),
          Expanded(
            child: PageView(
              controller: page,
              children: [
                Container(
                  color: Colors.white,
                  child: const Center(
                    child: Text(
                      'Dashboard',
                      style: TextStyle(fontSize: 35),
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: Center(
                    child: isMobile ? GetUserMediaSampleMobile() : Container()
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}