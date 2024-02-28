import 'dart:async' show Future, StreamSubscription;
import 'dart:io';

import 'package:arac_sarsinti/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_sound/flutter_sound.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
// ignore: depend_on_referenced_packages
import 'package:permission_handler/permission_handler.dart';
import 'package:restart_app/restart_app.dart';
// ignore: depend_on_referenced_packages
//import 'package:record/record.dat';
// ignore: depend_on_referenced_packages
import 'package:sensors_plus/sensors_plus.dart';

Future<void> main() async {
  runApp(const MyApp());
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
          // This is the theme of your application.
          //
          // TRY THIS: Try running your application with "flutter run". You'll see
          // the application has a purple toolbar. Then, without quitting the app,
          // try changing the seedColor in the colorScheme below to Colors.green
          // and then invoke "hot reload" (save your changes or press the "hot
          // reload" button in a Flutter-supported IDE, or press "r" if you used
          // the command line to start the app).
          //
          // Notice that the counter didn't reset back to zero; the application
          // state is not lost during the reload. To reset the state, use hot
          // restart instead.
          //
          // This works for code too, not just values: Most code changes can be
          // tested with just a hot reload.

          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 35, 134, 195))),
      home: const MyHomePage(title: 'Road Quality Measurement'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final recorder = FlutterSoundRecorder();
  late File _audioFile;
  int i = 0;
  int j = 0;
  int k = 0;
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController roadTypeController = TextEditingController();

  bool isRecorderReady = false;
  // List to store accelerometer data
  final List<AccelerometerEvent> _accelerometerValues = [];

  final List<GyroscopeEvent> _gyroscopeValues = [];

  // StreamSubscription for accelerometer events
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  //double _gyroX = 0.0;
  //double _gyroY = 0.0;
  //double _gyroZ = 0.0;

  @override
  void initState() {
    super.initState();
    // Subscribe to accelerometer events
    // ignore: deprecated_member_use
    /*_accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        // Update the _accelerometerValues list with the latest event
        _accelerometerValues = [event];
      });
    });*/
    initRecorder();

    // Listen to gyroscope data stream
    // ignore: deprecated_member_use
    /* gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroX = event.x;
        _gyroY = event.y;
        _gyroZ = event.z;
      });
    });*/
  }

  @override
  void dispose() {
    // Cancel the accelerometer event subscription to prevent memory leaks
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    recorder.closeRecorder();
    modelController.dispose();
    brandController.dispose();
    roadTypeController.dispose();
    super.dispose();
  }

  Future<int> saveAudioAndSensorData(
      File audioFile,
      List<AccelerometerEvent> accelerometerValues,
      List<GyroscopeEvent> gyroscopeValues) async {
    try {
      String vehicleBrand = brandController.text;
      String vehicleModel = modelController.text;
      String roadType = roadTypeController.text;
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      firebase_storage.Reference storageRef = firebase_storage
          .FirebaseStorage.instance
          .ref()
          .child('Records/${DateTime.now().millisecondsSinceEpoch}');
      CollectionReference reference = firestore.collection('data');
      await storageRef.putFile(audioFile);
      String audioUrl = await storageRef.getDownloadURL();

      await reference.add({
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'roadType': roadType,
        'accelerometerData': _accelerometerValues
            .map((event) => {
                  'x': event.x,
                  'y': event.y,
                  'z': event.z,
                })
            .toList(),
        'gyroscopeData': _gyroscopeValues
            .map((event) => {
                  'x': event.x,
                  'y': event.y,
                  'z': event.z,
                })
            .toList(),
        'audioUrl': audioUrl
      });
      return 1;
    } catch (error) {
      //print(error);
      return 0;
    }
  }

  Future initRecorder() async {
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      throw 'Microphone permission not granted';
    }

    await recorder.openRecorder();
    isRecorderReady = true;

    recorder.setSubscriptionDuration(
      const Duration(milliseconds: 500),
    );

    // ignore: deprecated_member_use
  }

  Future record() async {
    if (!isRecorderReady) return;
    //_accelerometerValues.clear();
    //Restart.restartApp(webOrigin: null);

    // ignore: deprecated_member_use
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        // Update the _accelerometerValues list with the latest event
        _accelerometerValues.add(event);
      });
    });

    // ignore: deprecated_member_use
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues.add(event);
      });
    });

    await recorder.startRecorder(toFile: 'audio');
  }

  Future stop() async {
    if (!isRecorderReady) return;
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();

    final path = await recorder.stopRecorder();
    _audioFile = File(path!);

    // ignore: avoid_print
    print('Recorded audio: $_audioFile');
  }

  Future<void> _confirmDialog() async {
    await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Başarıyla kaydedildi.'),
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).primaryColorDark,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          crossAxisAlignment: CrossAxisAlignment.center,

          children: <Widget>[
            const SizedBox(
              height: 20,
            ),
            const Text(
              'VEHICLE BRAND',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 18),
            ),
            SizedBox(
              height: 50,
              width: 300,
              child: TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please enter your vehicle brand',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'VEHICLE MODEL',
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 18),
            ),
            SizedBox(
              height: 50,
              width: 300,
              child: TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please enter your vehicle model',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'ROAD TYPE',
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 18),
            ),
            SizedBox(
              height: 50,
              width: 300,
              child: TextField(
                controller: roadTypeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please enter the road type for labeling',
                ),
              ),
            ),
            const Text(
              'CAR SOUND RECORD',
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 18),
            ),
            StreamBuilder<RecordingDisposition>(
              stream: recorder.onProgress,
              builder: (context, snapshot) {
                final duration =
                    snapshot.hasData ? snapshot.data!.duration : Duration.zero;
                if (duration == Duration.zero) {
                  _accelerometerValues.length = 0;
                }

                String twoDigits(int n) {
                  return n.toString().padLeft(0);
                }

                final twoDigitMinutes =
                    twoDigits(duration.inMinutes.remainder(60));
                final twoDigitSeconds =
                    twoDigits(duration.inSeconds.remainder(60));

                return Text('$twoDigitMinutes:$twoDigitSeconds',
                    style: const TextStyle(fontSize: 30));
              },
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Icon(
                    recorder.isRecording ? Icons.stop : Icons.mic,
                    size: 60,
                  ),
                  onPressed: () async {
                    if (recorder.isRecording) {
                      await stop();
                    } else {
                      await record();
                    }

                    setState(() {});
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    Restart.restartApp(webOrigin: null);
                  },
                  child: const Text(
                    "Reset",
                    style: TextStyle(
                        fontSize: 25,
                        color: Colors.black,
                        fontWeight: FontWeight.w400),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _confirmDialog();
                    saveAudioAndSensorData(
                            _audioFile, _accelerometerValues, _gyroscopeValues)
                        as int;
                  },
                  child: const Text(
                    "Save",
                    style: TextStyle(
                        fontSize: 25,
                        color: Colors.black,
                        fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'ACCELOREMETER DATA',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 20),
            ),
            const SizedBox(height: 10),
            if (_accelerometerValues.isNotEmpty)
              Text(
                'X: ${_accelerometerValues[i++].x.toStringAsFixed(2)}, '
                'Y: ${_accelerometerValues[i++].y.toStringAsFixed(2)}, '
                'Z: ${_accelerometerValues[i++].z.toStringAsFixed(2)}',
                //'Uzunluk: ${_accelerometerValues.length}',
                style: const TextStyle(fontSize: 16),
              )
            else
              const Text('No data available', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            const Text(
              'GYROSCOPE DATA',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 20),
            ),
            const SizedBox(height: 2),
            /*Text(
                'X: ${_gyroscopeValues[j++].x.toStringAsFixed(5)}'), // Display gyroscope X data
            Text(
                'Y: ${_gyroscopeValues[j++].y.toStringAsFixed(5)}'), // Display gyroscope Y data
            Text('Z: ${_gyroscopeValues[j++].z.toStringAsFixed(5)}'),*/
          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
