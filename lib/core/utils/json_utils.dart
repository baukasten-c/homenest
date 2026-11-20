DateTime? asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

int? asInt(dynamic v) => v == null ? null : (v as num).toInt();

double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();