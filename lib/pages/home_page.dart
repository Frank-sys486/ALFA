import 'package:flutter/material.dart';
import 'dart:ui';
import 'activity_page1.dart';
import 'activity_page2.dart';
import 'activity_page3.dart';
import 'activity_page4.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<bool> starStates = [false, false, false, false]; // 4 buttons, 4 stars
  bool showActivityPage = false;
  Widget? rightPane;
  Widget? selectedActivity;
  int selectedIndex = -1;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Laboratory Activities'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (selectedActivity != null)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              onPressed: _toggleFullScreen,
              tooltip: 'Open in Full Page',
            ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(color: Colors.deepPurple),
          child: ListView(
            children: [
              DrawerHeader(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.book, color: Colors.white, size: 50),
                      Column(
                        children: [
                          Text(
                            'ALFA',
                            style: TextStyle(color: Colors.white, fontSize: 20),
                          ),
                          Text(
                            'Activity Library by Frank',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.home, color: Colors.white),
                title: Text(
                  'Home',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.circle, color: Colors.blue),
                title: Text(
                  'Subject 1',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.circle, color: Colors.green),
                title: Text(
                  'Subject 2',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.circle, color: Colors.yellow),
                title: Text(
                  'Subject 3',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.circle, color: Colors.purple),
                title: Text(
                  'Subject 4',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: MediaQuery.of(context).size.width > 1000
          ? Row(
              // tablet mode
              children: [
                Container(
                  width: 300,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildActivityButton(
                        context,
                        Icons.school,
                        'Activity 1',
                        ActivityPage1(),
                        Colors.blue,
                        0,
                        setState,
                        starStates,
                        () => _onActivitySelected(ActivityPage1(), 0),
                      ),

                      _buildActivityButton(
                        context,
                        Icons.school,
                        'Activity 2',
                        const ActivityPage2(),
                        Colors.green,
                        1,
                        setState,
                        starStates,
                        () => _onActivitySelected(const ActivityPage2(), 1),
                      ),
                      _buildActivityButton(
                        context,
                        Icons.school,
                        'Activity 3',
                        const ActivityPage3(),
                        Colors.orange,
                        2,
                        setState,
                        starStates,
                        () => _onActivitySelected(const ActivityPage3(), 2),
                      ),
                      _buildActivityButton(
                        context,
                        Icons.school,
                        'Activity 4',
                        const ActivityPage4(),
                        Colors.purple,
                        3,
                        setState,
                        starStates,
                        () => _onActivitySelected(const ActivityPage4(), 3),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    child: selectedActivity != null
                        ? Stack(
                            children: [
                              // The actual activity page
                              selectedActivity!,
                              // Blur overlay with message (only for ActivityPage1 - music player)
                              if (selectedActivity is ActivityPage1)
                                Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 3.0,
                                        sigmaY: 3.0,
                                      ),
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.open_in_full,
                                                size: 64,
                                                color: Colors.white,
                                              ),
                                              SizedBox(height: 16),
                                              Text(
                                                'Click "Open in Full Page" button',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'for the best experience',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const Center(child: Text("Select a page")),
                  ),
                ),
              ],
            )
          : Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildActivityButton(
                    context,
                    Icons.school,
                    'Activity 1',
                    ActivityPage1(),
                    Colors.blue,
                    0,
                    setState,
                    starStates,
                    () => _onActivitySelected(ActivityPage1(), 0),
                  ),

                  _buildActivityButton(
                    context,
                    Icons.school,
                    'Activity 2',
                    const ActivityPage2(),
                    Colors.green,
                    1,
                    setState,
                    starStates,
                    () => _onActivitySelected(const ActivityPage2(), 1),
                  ),
                  _buildActivityButton(
                    context,
                    Icons.school,
                    'Activity 3',
                    const ActivityPage3(),
                    Colors.orange,
                    2,
                    setState,
                    starStates,
                    () => _onActivitySelected(const ActivityPage3(), 2),
                  ),
                  _buildActivityButton(
                    context,
                    Icons.school,
                    'Activity 4',
                    const ActivityPage4(),
                    Colors.purple,
                    3,
                    setState,
                    starStates,
                    () => _onActivitySelected(const ActivityPage4(), 3),
                  ),
                ],
              ),
            ),
    );
  }

  void _onActivitySelected(Widget page, int index) {
    setState(() {
      selectedActivity = page;
      selectedIndex = index;
    });
  }

  void _toggleFullScreen() {
    if (selectedActivity != null) {
      // open the activity in fullscreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => selectedActivity!),
      );
    }
  }
}

Widget _buildActivityButton(
  BuildContext context,
  IconData icon,
  String label,
  Widget page,
  Color color,
  int buttonIndex,
  Function setState,
  List<bool> starStates,
  VoidCallback onActivitySelected,
) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          spreadRadius: 1,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (MediaQuery.of(context).size.width > 1000) {
            onActivitySelected(); // Call the callback
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                //Icon, title, info, date
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0),
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, size: 48, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Description',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Date',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    starStates[buttonIndex] = !starStates[buttonIndex];
                  });
                },
                child: Icon(
                  starStates[buttonIndex] ? Icons.star : Icons.star_border,
                  color: starStates[buttonIndex] ? Colors.yellow : Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
