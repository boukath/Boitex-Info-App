// lib/utils/search_utils.dart

/// Generates a list of all possible search prefixes for a given list of terms.
///
/// Example:
/// Input: ["Azadea", "Zara"]
/// Output: ["a", "az", "aza", "azad", "azade", "azadea", "z", "za", "zar", "zara"]
List<String> generateSearchKeywords(List<String> terms) {
  Set<String> keywords = {}; // Using a Set to avoid duplicates automatically

  for (String term in terms) {
    // 1. Clean the term: Lowercase and trim spaces
    String cleanTerm = term.trim().toLowerCase();

    // 2. Generate prefixes
    // "Zara" -> "z", "za", "zar", "zara"
    String temp = "";
    for (int i = 0; i < cleanTerm.length; i++) {
      temp += cleanTerm[i];
      keywords.add(temp);
    }

    // 3. (Optional) Handle multi-word terms separately
    // If term is "Pull & Bear", we also want "bear" to work
    List<String> subWords = cleanTerm.split(' ');
    if (subWords.length > 1) {
      for (String subWord in subWords) {
        String subTemp = "";
        for (int i = 0; i < subWord.length; i++) {
          subTemp += subWord[i];
          keywords.add(subTemp);
        }
      }
    }
  }

  return keywords.toList();
}