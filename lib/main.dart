import 'dart:async' show Future, StreamSubscription;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

void main() async {
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
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final Duration _samplingPeriod = const Duration(seconds: 1);
  final recorder = FlutterSoundRecorder();
  bool isRecorderReady = false;
  // List to store accelerometer data
  List<UserAccelerometerEvent> _accelerometerValues = [];
  List<GyroscopeEvent> _gyroscopeValues = [];
  // StreamSubscription for accelerometer events
  late StreamSubscription<UserAccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;

  @override
  void initState() {
    super.initState();
    initRecorder();
  }

  @override
  void dispose() {
    // Cancel the accelerometer event subscription to prevent memory leaks
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    recorder.closeRecorder();
    modelController.dispose();
    brandController.dispose();
    super.dispose();
  }

  Future<void> saveAudioAndSensorData(File audioFile,
      List<UserAccelerometerEvent> accelerometerValues,
      List<GyroscopeEvent> gyroscopeValues) async{

    try{
      String vehicleBrand = brandController.text;
      String vehicleModel = modelController.text;
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      firebase_storage.Reference storageRef = firebase_storage.FirebaseStorage.instance.ref().child('audios/${DateTime.now().millisecondsSinceEpoch}');
      CollectionReference reference = firestore.collection('data');
      await storageRef.putFile(audioFile);
      String audioUrl = await storageRef.getDownloadURL();


      await reference.add({
        'vehicleBrand': vehicleBrand,
        'vehicleModel': vehicleModel,
        'accelerometerData': _accelerometerValues.map((event) => {
          'x': event.x,
          'y': event.y,
          'z': event.z,
        }).toList(),
        'gyroscopeData': _gyroscopeValues.map((event) => {
          'x': event.x,
          'y': event.y,
          'z': event.z,
        }).toList(),
        'audioUrl': audioUrl
      });
    }catch (error){
      print(error);
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
    _accelerometerSubscription = userAccelerometerEventStream(samplingPeriod:SensorInterval.normalInterval).listen((UserAccelerometerEvent event) {
      setState(() {
        // Update the _accelerometerValues list with the latest event
        _accelerometerValues.add(event);
      });
    });
    _gyroscopeSubscription = gyroscopeEventStream(samplingPeriod:SensorInterval.normalInterval).listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues.add(event);
      });
    });
    await recorder.startRecorder(toFile: 'audio');
  }

  Future stop() async {
    if (!isRecorderReady) return;

    final path = await recorder.stopRecorder();
    final audioFile = File(path!);
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    await saveAudioAndSensorData(audioFile, _accelerometerValues, _gyroscopeValues);
    // ignore: avoid_print
    print('Recorded audio: $audioFile');
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
          crossAxisAlignment: CrossAxisAlignment.start,

          children: <Widget>[
            const SizedBox(
              height: 20,
            ),
            const Text(
              'VEHICLE BRAND',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 20),
            ),
             SizedBox(
              width: 300,
              child: TextField(
                controller: brandController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please enter your vehicle brand',
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            const Text(
              'VEHICLE MODEL',
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 20),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: modelController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please enter your vehicle model',
                ),
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            const Text(
              'CAR SOUND RECORD',
              style: TextStyle(
                  color: Color.fromRGBO(245, 4, 52, 0.996), fontSize: 20),
            ),
            StreamBuilder<RecordingDisposition>(
              stream: recorder.onProgress,
              builder: (context, snapshot) {
                final duration =
                    snapshot.hasData ? snapshot.data!.duration : Duration.zero;

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
            const SizedBox(height: 32),
            ElevatedButton(
              child: Icon(
                recorder.isRecording ? Icons.stop : Icons.mic,
                size: 80,
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
            const SizedBox(
              height: 20,
            ),

          ],
        ),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
