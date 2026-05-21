import QtQuick

// Provides exposed `date` and `time` strings + a Timer that updates them every
// second. Render the two pieces separately so the separator can sit on the
// monitor's exact horizontal center.
QtObject {
  id: root
  property string dateFmt: "dd MMM"
  property string timeFmt: "HH:mm"
  property string date: ""
  property string time: ""

  property Timer _tick: Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const d = new Date()
      root.date = Qt.formatDateTime(d, root.dateFmt)
      root.time = Qt.formatDateTime(d, root.timeFmt)
    }
  }
}
