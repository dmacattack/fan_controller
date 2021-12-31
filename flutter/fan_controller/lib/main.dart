import 'package:flutter/material.dart';
import 'dart:developer' as dbg;
import 'package:flutter_blue/flutter_blue.dart';

void main() { runApp(MyApp()); }

class MyApp extends StatelessWidget 
{

  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

///
/// eBT_STATE - bluetooth state
/// 
enum eBT_STATE
{
  IDLE,
  SCANNING,
  CONNECTING,
  CONNECTED,
  CHAR_FOUND, 
}

///
/// MyHomePageState - state to implement on the homepage
/// 
class _MyHomePageState extends State<MyHomePage> 
{
  // constants
  static const String FAN_CONTROLLER_BT_NAME = 'Fan Controller';
  static const String FAN_CMD_ON = "fan_on";
  static const String FAN_CMD_OFF = "fan_off";
  static const String SERVICE_UUID        = "deadbeef-1fb5-459e-8fcc-555555555555";
  static const String CHARACTERISTIC_UUID = "b000b135-36e1-4688-b7f5-666666666666";

  // member vars
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice _device;
  String _currentStatus = "idle";
  eBT_STATE _currentState = eBT_STATE.IDLE;
  BluetoothCharacteristic _fanCharacteristic;

  ///
  /// _scanForeDevices - scan for bluetooth devices
  /// 
  void _scanForDevices()
  {
    // update the state
    _updateUIStatus(eBT_STATE.SCANNING);

    // Start scanning
    flutterBlue.startScan(timeout: Duration(seconds: 5));

    // Listen to scan results

    flutterBlue.scanResults.listen((results) 
    {
      for (ScanResult r in results)
      {
        bool isMatch = (r.device.name == FAN_CONTROLLER_BT_NAME);
        dbg.log('${r.device.name} found. rssi: ${r.rssi}. match = $isMatch');

        // connect to the device
        if (isMatch)
        {
          _connectToDevice(r.device);
        }
      }
    });
  }

  ///
  /// _updateUIStatus - update the ui status
  /// 
  void _updateUIStatus(eBT_STATE state)
  {
    _currentState = state;
    setState(() 
    { 
      _currentStatus = (_currentState == eBT_STATE.IDLE       ? "idle"       : 
                       (_currentState == eBT_STATE.CONNECTING ? "connecting" : 
                       (_currentState == eBT_STATE.CONNECTED  ? "connected"  : 
                       (_currentState == eBT_STATE.SCANNING   ? "scanning"   : 
                       (_currentState == eBT_STATE.CHAR_FOUND ? "ready"      : "???" )))));
    });
  }

  /// 
  /// _connectToDevice - connect to the bluetooth device
  /// 
  void _connectToDevice(BluetoothDevice device) async
  {
    if ((_currentState == eBT_STATE.CONNECTING) || (_currentState == eBT_STATE.CONNECTED) )
    {
      dbg.log('do not connect in state ' + _currentState.toString());
      return;
    }

    // update the status
    _updateUIStatus(eBT_STATE.CONNECTING);

    // stop scanning
    dbg.log('stoping scanning');
    flutterBlue.stopScan();

    dbg.log('trying to connect to the fan controller ... ');

    // Connect to the device
    await device.connect();

    // save the device for later
    _device = device;

    dbg.log('now connected to ${device.name}');

    // update status
    _updateUIStatus(eBT_STATE.CONNECTED);

    // list services and all that
    _listServices(device);
  }

  ///
  /// _disconnectDevice - disconnect from the bluetooth device
  ///
  void _disconnectDevice(BluetoothDevice device)
  {
    try
    {
      // Disconnect from device
      device.disconnect();
      _device = null;
    }
    catch (ex)
    {
      dbg.log('couldnt disconnect ' + ex.toString());
    }
    
    _updateUIStatus(eBT_STATE.IDLE);
  }

  ///
  /// _listServices - list the services of the bluetooth device
  /// 
  void _listServices(BluetoothDevice device) async
  {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) 
    {
      dbg.log('<${device.name}> service: UUID = ${service.uuid.toString()} ');
      if (service.uuid.toString() == SERVICE_UUID)
      {
        _readCharacteristic(service);
      }
    });
  }

  ///
  /// _readCharacteristic - read a characteristic
  /// 
  void _readCharacteristic(BluetoothService service) async
  {
    // Reads all characteristics
    var characteristics = service.characteristics;
    for(BluetoothCharacteristic c in characteristics) 
    {
      if (c.uuid.toString() == CHARACTERISTIC_UUID)
      {
        List<int> value = await c.read();
        String s = listToString(value);
        dbg.log('characteristic ${c.uuid.toString()} = $s');

        // set the characteristic
        _fanCharacteristic = c;
        _updateUIStatus(eBT_STATE.CHAR_FOUND);
      }
    }
  }

  ///
  /// _writeCharacteristicValue - write a list to the characteristic
  /// 
  void _writeCharacteristicValue(BluetoothCharacteristic characteristic, List<int> values) async
  {
    await characteristic.write(values);
  }

  ///
  /// _writeCharacteristicString - write a string to the characteristic 
  /// 
  void _writeCharacteristicString(BluetoothCharacteristic characteristic, String value) async 
  {
    _writeCharacteristicValue(characteristic, stringToList(value));
  }

  ///
  /// _getButtons - get the buttons for the app
  ///
  List<Widget> _getButtons()
  {
    List<Widget> list = [];
    var connBtn = ElevatedButton
    (
      onPressed: ()
      {
        dbg.log('clicked the button');
        _scanForDevices();
      }, 
      child: Text('Connect'),
    );
    

    var disBtn = ElevatedButton(onPressed:() => _disconnectDevice(_device), child: Text ('Disconnect'));
    var onBtn = ElevatedButton(onPressed:() => _writeCharacteristicString(_fanCharacteristic, FAN_CMD_ON), child: Text ('FAN ON'));
    var offBtn = ElevatedButton(onPressed:() => _writeCharacteristicString(_fanCharacteristic, FAN_CMD_OFF), child: Text ('FAN OFF'));

    list.add(Text(_currentStatus));
    list.add(connBtn);
    list.add(onBtn);
    list.add(offBtn);
    list.add(disBtn);

    return list;
  }

  ///
  /// build function
  ///
  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      appBar: AppBar
      (
        title: Text(widget.title),
      ),
      body: Center
      (
        child: Column
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children: _getButtons(),
        ),
      ),
   
    );
  }

  ///
  /// listToString - convert an int list to a string
  /// 
  String listToString(List<int> arr) 
  {
    return String.fromCharCodes(arr);
  }

  ///
  /// stringToList - convert string to an integer list
  /// 
  List<int> stringToList(String s)
  {
    return s.codeUnits;
  }
}
