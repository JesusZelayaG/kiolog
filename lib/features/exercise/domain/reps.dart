/// Lee las repeticiones tal como las escribe el plan.
///
/// "8" queda como número sin etiqueta. "6-8", "12 y 15" o "Las que salgan"
/// guardan el texto y usan el número más alto para prellenar la sesión
/// (o 0 si no hay ninguno). Vacío devuelve null.
(int, String?)? parseReps(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final plain = int.tryParse(text);
  if (plain != null) return (plain, null);
  final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m[0]!));
  final top = numbers.isEmpty ? 0 : numbers.reduce((a, b) => a > b ? a : b);
  return (top, text);
}
