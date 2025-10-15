import 'package:flutter/material.dart';
import '../../bluetooth/devices/NuxDevice.dart';
import 'package:mighty_plug_manager/bluetooth/NuxDeviceControl.dart';
import 'package:mighty_plug_manager/audio/setlist_player/setlistPlayerState.dart';

class QuickSwitch extends StatefulWidget {
  const QuickSwitch({super.key});

  @override
  _QuickSwitchState createState() => _QuickSwitchState();
}

class _QuickSwitchState extends State<QuickSwitch> {
  late NuxDevice device;

  int _gridCount = 4; // number of buttons (2–4)
  List<int> _assignedChannels = [1, 2, 3, 4]; // channel mapping per button
  int? _selectedChannel; // which button is currently active

  @override
  void initState() {
    super.initState();
    device = NuxDeviceControl.instance().device;
    device.addListener(onDeviceDataChanged);
    NuxDeviceControl.instance().addListener(onDeviceChanged);
    SetlistPlayerState.instance().addListener(onJamTracksStateChange);
  }

  @override
  void dispose() {
    device.removeListener(onDeviceDataChanged);
    NuxDeviceControl.instance().removeListener(onDeviceChanged);
    SetlistPlayerState.instance().removeListener(onJamTracksStateChange);
    super.dispose();
  }

  void onDeviceChanged() {
    if (device != NuxDeviceControl.instance().device) {
      device.removeListener(onDeviceDataChanged);
      device = NuxDeviceControl.instance().device;
      device.addListener(onDeviceDataChanged);
    }
    setState(() {});
  }

  void onDeviceDataChanged() => setState(() {});
  void onJamTracksStateChange() => setState(() {});

  // --- change channel on amp ---
  void _switchChannel(BuildContext context, int channel) async {
    if (device.selectedChannel == channel) return;
    device.setSelectedChannel(channel,
        notifyBT: true, sendFullPreset: false, notifyUI: true);
    device.getPreset(device.selectedChannel).setupPresetFromNuxData();

    setState(() {
      _selectedChannel = channel;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Switched to channel $channel'),
        duration: const Duration(milliseconds: 800)));
  }

  // --- picker overlay on long press ---
  Future<void> _showChannelPicker(BuildContext context, int index) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: ListView.builder(
            itemCount: 7,
            itemBuilder: (_, i) {
              final ch = i + 1;
              return ListTile(
                title: Text('Channel $ch'),
                onTap: () => Navigator.pop(context, ch),
              );
            },
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _assignedChannels[index] = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Channel Switch')),
      body: Column(
        children: [
          // --- dynamic height area for the list of buttons ---
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalHeight = constraints.maxHeight;
                final buttonHeight = totalHeight / _gridCount;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_gridCount, (index) {
                    final channel = _assignedChannels[index];
                    final isActive = _selectedChannel == channel;

                    return SizedBox(
                      height: buttonHeight,
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: GestureDetector(
                          onLongPress: () => _showChannelPicker(context, index),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isActive ? Colors.blue : Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _switchChannel(context, channel),
                            child: Text(
                              'Channel $channel',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          // --- +/- buttons at bottom ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton('-', _decreaseGrid),
                const SizedBox(width: 16),
                _buildActionButton('+', _increaseGrid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 24)),
    );
  }

  void _increaseGrid() {
    if (_gridCount >= 4) return;
    setState(() {
      _gridCount++;
      _assignedChannels.add(_gridCount);
    });
  }

  void _decreaseGrid() {
    if (_gridCount <= 2) return;
    setState(() {
      _gridCount--;
      _assignedChannels.removeLast();
    });
  }
}
