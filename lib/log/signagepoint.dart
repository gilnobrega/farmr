import 'logitem.dart';

class SignagePoint extends LogItem {
  List<int> steps = [];

  bool _first = false;
  bool get complete => (_first || steps.toSet().length == 64);

  int get lastStep => steps.last;

  SignagePoint(int timestamp, [List<int> initialSteps = null, bool first = false])
      : super(timestamp, LogItemType.FullNode) {
    if (initialSteps != null) steps = initialSteps;
    _first = first;
  }

  addStep(int step) {
    steps.add(step);
  }
}
