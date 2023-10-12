import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ButtonState { download, cancel, pause, resume, reset }

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'cmed_task1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Home Screen'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final buttonTexts = ['Download', 'Cancel', 'Pause', 'Resume', 'Reset'];

  ButtonState buttonState = ButtonState.download;
  bool downloadWithError = false;
  TaskStatus? downloadTaskStatus;
  DownloadTask? backgroundDownloadTask;
  StreamController<TaskProgressUpdate> progressUpdateStream = StreamController();

  SharedPreferences? sharedPreferences;
  bool isLoading = false;
  String lastDownloadStatus = "";

  Future<void> initData() async {
    sharedPreferences = await SharedPreferences.getInstance();
    lastDownloadStatus = sharedPreferences?.getString("last_download_status")??"N/A";

    FileDownloader().configure(globalConfig: [
      (Config.requestTimeout, const Duration(seconds: 100)),
    ], androidConfig: [
      (Config.useCacheDir, Config.whenAble),
    ], iOSConfig: [
      (Config.localize, {'Cancel': 'StopIt'}),
    ]).then((result) => debugPrint('Configuration result = $result'));

    FileDownloader().configure(globalConfig: [
      (Config.requestTimeout, const Duration(seconds: 200)),
    ], androidConfig: [
      (Config.useCacheDir, Config.whenAble),
    ], iOSConfig: [
      (Config.localize, {'Cancel': 'StopIt'}),
    ]).then((result) => debugPrint('Configuration result = $result'));

    FileDownloader()
        .registerCallbacks(taskNotificationTapCallback: myNotificationTapCallback)
        .configureNotificationForGroup(
          FileDownloader.defaultGroup,
          running: const TaskNotification('Download {filename}', 'File: {filename} - {progress} - speed {networkSpeed} and {timeRemaining} remaining'),
          complete: const TaskNotification('Download {filename}', 'Download complete'),
          error: const TaskNotification('Download {filename}', 'Download failed'),
          paused: const TaskNotification('Download {filename}', 'Paused with metadata {metadata}'),
          progressBar: true,
        )
        .configureNotification(
          complete: const TaskNotification('Download {filename}', 'Download complete'),
          // tapOpensFile: false,
        );

    FileDownloader().updates.listen((update) {
      switch (update) {
        case TaskStatusUpdate _:
          if (update.task == backgroundDownloadTask) {
            buttonState = switch (update.status) { TaskStatus.running || TaskStatus.enqueued => ButtonState.pause, TaskStatus.paused => ButtonState.resume, _ => ButtonState.reset };
            setState(() {
              downloadTaskStatus = update.status;
              sharedPreferences?.setString("last_download_status", lastDownloadStatus.toString());
            });
          }

        case TaskProgressUpdate _:
          progressUpdateStream.add(update); // pass on to widget for indicator
      }
    });
  }

  @override
  void initState() {
    initData();
    super.initState();
  }

  void myNotificationTapCallback(Task task, NotificationType notificationType) {
    manageData(task);
  }

  manageData(var task) async {
    final record = await FileDownloader().database.recordForId(task.taskId);
    debugPrint("record: ${record?.toString()}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
             Text(
               lastDownloadStatus,
             ),
            const SizedBox(height: 20),
            Center(
                child: ElevatedButton(
              onPressed: processButtonPress,
              child: Text(
                'Download',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.black,
                      fontSize: 16,
                    ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> processButtonPress() async {
    switch (buttonState) {
      case ButtonState.download:
        backgroundDownloadTask = DownloadTask(url: "https://file-examples.com/storage/feaade38c1651bd01984236/2017/04/file_example_MP4_1920_18MG.mp4", filename: 'video_file.mp4', directory: 'my/directory', baseDirectory: BaseDirectory.applicationDocuments, updates: Updates.statusAndProgress, allowPause: true, metaData: '<example metaData>');
        await FileDownloader().enqueue(backgroundDownloadTask!);
        break;
      case ButtonState.cancel:
        // cancel download
        if (backgroundDownloadTask != null) {
          await FileDownloader().cancelTasksWithIds([backgroundDownloadTask!.taskId]);
        }
        break;
      case ButtonState.reset:
        downloadTaskStatus = null;
        buttonState = ButtonState.download;
        break;
      case ButtonState.pause:
        if (backgroundDownloadTask != null) {
          await FileDownloader().pause(backgroundDownloadTask!);
        }
        break;
      case ButtonState.resume:
        if (backgroundDownloadTask != null) {
          await FileDownloader().resume(backgroundDownloadTask!);
        }
        break;
    }
    if (mounted) {
      setState(() {});
    }
  }
}
