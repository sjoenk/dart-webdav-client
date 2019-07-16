import 'package:string_scanner/string_scanner.dart';

class HttpDateTime {
  static final _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  static final _months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  static final _shortWeekdayRegExp = RegExp(r"Mon|Tue|Wed|Thu|Fri|Sat|Sun");
  static final _longWeekdayRegExp = RegExp(r"Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday");
  static final _monthRegExp = RegExp(r"Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec");
  static final _digitRegExp = RegExp(r"\d+");

  static DateTime tryParse(String date) {
    try {
      return parse(date);
    } on Exception {
      return null;
    }
  }

  static DateTime parse(String date) {
    var scanner = StringScanner(date);

    if (scanner.scan(_longWeekdayRegExp)) {
      // RFC 850 starts with a long weekday.
      scanner.expect(", ");
      var day = _parseInt(scanner, 2);
      scanner.expect("-");
      var month = _parseMonth(scanner);
      scanner.expect("-");
      var year = 1900 + _parseInt(scanner, 2);
      scanner.expect(" ");
      var time = _parseTime(scanner);
      scanner.expect(" GMT");
      scanner.expectDone();

      return _makeDateTime(year, month, day, time);
    }

    // RFC 1123 and asctime both start with a short weekday.
    scanner.expect(_shortWeekdayRegExp);
    if (scanner.scan(", ")) {
      // RFC 1123 follows the weekday with a comma.
      var day = _parseInt(scanner, 2);
      scanner.expect(" ");
      var month = _parseMonth(scanner);
      scanner.expect(" ");
      var year = _parseInt(scanner, 4);
      scanner.expect(" ");
      var time = _parseTime(scanner);
      scanner.expect(" GMT");
      scanner.expectDone();

      return _makeDateTime(year, month, day, time);
    }

    // asctime follows the weekday with a space.
    scanner.expect(" ");
    var month = _parseMonth(scanner);
    scanner.expect(" ");
    var day = scanner.scan(" ") ? _parseInt(scanner, 1) : _parseInt(scanner, 2);
    scanner.expect(" ");
    var time = _parseTime(scanner);
    scanner.expect(" ");
    var year = _parseInt(scanner, 4);
    scanner.expectDone();

    return _makeDateTime(year, month, day, time);
  }

  /// Return a HTTP-formatted string representation of [date].
  ///
  /// This follows [RFC 822](http://tools.ietf.org/html/rfc822) as updated by [RFC
  /// 1123](http://tools.ietf.org/html/rfc1123).
  String format(DateTime date) {
    date = date.toUtc();
    var buffer = StringBuffer()
      ..write(_weekdays[date.weekday - 1])
      ..write(", ")
      ..write(date.day <= 9 ? "0" : "")
      ..write(date.day.toString())
      ..write(" ")
      ..write(_months[date.month - 1])
      ..write(" ")
      ..write(date.year.toString())
      ..write(date.hour <= 9 ? " 0" : " ")
      ..write(date.hour.toString())
      ..write(date.minute <= 9 ? ":0" : ":")
      ..write(date.minute.toString())
      ..write(date.second <= 9 ? ":0" : ":")
      ..write(date.second.toString())
      ..write(" GMT");
    return buffer.toString();
  }

  /// Parses a short-form month name to a form accepted by [DateTime].
  static int _parseMonth(StringScanner scanner) {
    scanner.expect(_monthRegExp);
    // DateTime uses 1-indexed months.
    return _months.indexOf(scanner.lastMatch[0]) + 1;
  }

  /// Parses an int an enforces that it has exactly [digits] digits.
  static int _parseInt(StringScanner scanner, int digits) {
    scanner.expect(_digitRegExp);
    if (scanner.lastMatch[0].length != digits) {
      scanner.error("expected a $digits-digit number.");
    }

    return int.parse(scanner.lastMatch[0]);
  }

  /// Parses an timestamp of the form "HH:MM:SS" on a 24-hour clock.
  static DateTime _parseTime(StringScanner scanner) {
    var hours = _parseInt(scanner, 2);
    if (hours >= 24) scanner.error("hours may not be greater than 24.");
    scanner.expect(':');

    var minutes = _parseInt(scanner, 2);
    if (minutes >= 60) scanner.error("minutes may not be greater than 60.");
    scanner.expect(':');

    var seconds = _parseInt(scanner, 2);
    if (seconds >= 60) scanner.error("seconds may not be greater than 60.");

    return DateTime(1, 1, 1, hours, minutes, seconds);
  }

  /// Returns a UTC [DateTime] from the given components.
  ///
  /// Validates that [day] is a valid day for [month]. If it's not, throws a
  /// [FormatException].
  static DateTime _makeDateTime(int year, int month, int day, DateTime time) {
    var dateTime = DateTime.utc(year, month, day, time.hour, time.minute, time.second);

    // If [day] was too large, it will cause [month] to overflow.
    if (dateTime.month != month) {
      throw FormatException("invalid day '$day' for month '$month'.");
    }
    return dateTime;
  }
}
