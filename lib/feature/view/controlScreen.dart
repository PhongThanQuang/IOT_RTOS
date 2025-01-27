import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:iot_rtos/core/utils/constants.dart';
import 'package:iot_rtos/core/utils/utils.dart';
import 'package:kdgaugeview/kdgaugeview.dart';
import 'package:lottie/lottie.dart';

class ControlScreen extends StatefulWidget {
  final Object device;

  const ControlScreen({Key? key, required this.device}) : super(key: key);

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {

  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;

  late StreamSubscription<List<int>> _lastValueSubscription;

  bool _isSendingDC = false;
  bool _isSendingSERVO = false;
  double _rowWidth = 0;
  int _preDC = 0;
  int _preServo = 0;

  final speedNotifier = ValueNotifier<double>(10);
  final key = GlobalKey<KdGaugeViewState>();

  bool _anim = false;

  @override
  void dispose() {
    // _connectionStateSubscription.cancel();

    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    _lastValueSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return true;
  }

  void prepareSendingData(int cmd, double data) {
    int remappingInt = 0;

    if (cmd == CMD_DC) {
      double remapping = data.remap(-1.00, 1.00, 255, 0);
      remappingInt = remapping.toInt();
      updateSpeedometer(remappingInt);

      if ((remappingInt - _preDC).abs() < DATA_GAP) {
        return;
      }
    } else if (cmd == CMD_SERVO) {
      double remapping = data.remap(-1.00, 1.00, 0, 255);
      remappingInt = remapping.toInt();
      if ((remappingInt - _preServo).abs() < DATA_GAP) {
        return;
      }
    }
    setState(() {});
    // writeBLE(cmd, remappingInt);
  }

  void updateSpeedometer(int rawValue) {
    int base = rawValue - 127;

    if (base <= 0) {
      base = 0;
      _anim = false;
    } else {
      _anim = true;
    }

    key.currentState!.updateSpeed(base.toDouble());
    speedNotifier.value = base.toDouble();
  }

  @override
  void didChangeDependencies() {
    _rowWidth = MediaQuery.of(context).size.width / 2;
    super.didChangeDependencies();
  }

  void _getOutOfApp() {

    Future.delayed(const Duration(milliseconds: 500), () {
      if (Platform.isIOS) {
        try {
          exit(0);
        } catch (e) {
          SystemNavigator.pop();
        }
      } else {
        try {
          SystemNavigator.pop();
        } catch (e) {
          exit(0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Lottie.asset('assets/lottiefiles/1701371264021.json',
                    animate: _anim),
              ),
              Center(
                child: Container(
                  width: 360,
                  height: 360,
                  padding: const EdgeInsets.all(10),
                  child: ValueListenableBuilder<double>(
                      valueListenable: speedNotifier,
                      builder: (context, value, child) {
                        return KdGaugeView(
                          unitOfMeasurement: "MPH",
                          speedTextStyle: TextStyle(
                            fontSize: 100,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 6
                              ..color = Colors.greenAccent,
                          ),
                          key: key,
                          minSpeed: 0,
                          maxSpeed: 125,
                          speed: 0,
                          animate: true,
                          alertSpeedArray: const [40, 80, 100],
                          alertColorArray: const [
                            Colors.orange,
                            Colors.indigo,
                            Colors.red
                          ],
                          duration: const Duration(seconds: 6),
                        );
                      }),
                ),
              ),

              Positioned(
                bottom: 50,  // Position joystick vertically
                left: -95,    // Position joystick horizontally from the left
                child: Container(
                  width: _rowWidth,
                  height: _rowWidth * 2,
                  alignment: Alignment.centerLeft,
                  child: JoystickArea(
                    base: Container(
                      width: 100,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    mode: JoystickMode.vertical,
                    initialJoystickAlignment: Alignment.bottomCenter,
                    listener: (details) {
                      prepareSendingData(CMD_DC, details.y);
                    },
                    onStickDragStart: () {
                      _isSendingDC = true;
                    },
                    onStickDragEnd: () {
                      _isSendingDC = false;
                    },
                  ),
                ),
              ),

              Positioned(
                bottom: 50,  // Position joystick vertically
                right: -100,    // Position joystick horizontally from the left
                child: Container(
                  width: _rowWidth,
                  height: 200,
                  alignment: Alignment.centerRight,
                  child: JoystickArea(
                    base: Container(
                      width: 200,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    mode: JoystickMode.horizontal,
                    initialJoystickAlignment: const Alignment(0, 0.8),
                    listener: (details) {
                      prepareSendingData(CMD_SERVO, details.x);
                    },
                    onStickDragStart: () {
                      _isSendingDC = true;
                    },
                    onStickDragEnd: () {
                      _isSendingDC = false;
                    },
                  ),
                ),
              ),
              Positioned(
                top: 0.0,
                right: 0.0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CloseButton(
                    color: Colors.red,
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Do you want to close App?'),
                        content: const Text(
                            '(Automatically disconnected when the app ends.)'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'Cancel'),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => _getOutOfApp(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
