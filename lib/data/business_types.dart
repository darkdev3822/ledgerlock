// Onboarding "What kind of work do you do?" (SPEC §5). Only reorders categories so the likely ones come first;
// nothing is hidden and no tax treatment changes.
import 'tax_rules.dart';

/// id -> (label, one-line description, category ids most likely used, in order).
const businessTypes = <String, (String, String, List<String>)>{
  'products': (
    'Selling products',
    'Etsy, eBay, crafts, resale',
    ['product_sales', 'supplies', 'platform_fees', 'advertising', 'equipment', 'refunds_given'],
  ),
  'services': (
    'Services or freelance',
    'Design, writing, coding, consulting',
    ['services', 'software', 'contract_labor', 'legal_professional', 'office', 'education'],
  ),
  'driving': (
    'Rideshare or delivery',
    'Uber, Lyft, DoorDash, Instacart',
    ['services', 'tips', 'platform_fees', 'utilities', 'insurance', 'equipment'],
  ),
  'creator': (
    'Content creator',
    'YouTube, Twitch, Patreon, sponsorships',
    ['services', 'tips', 'equipment', 'software', 'advertising', 'education'],
  ),
};

/// Categories with the chosen types' likely ones first (in the order of the first type that lists them), then the
/// rest in their usual order. With no types chosen the list is unchanged.
List<Category> orderCategories(List<Category> cats, Set<String> types) {
  if (types.isEmpty) return cats;
  final rank = <String, int>{};
  var i = 0;
  for (final t in businessTypes.keys.where(types.contains)) {
    for (final id in businessTypes[t]!.$3) {
      rank.putIfAbsent(id, () => i++);
    }
  }
  final first = cats.where((c) => rank.containsKey(c.id)).toList()..sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
  return [...first, ...cats.where((c) => !rank.containsKey(c.id))];
}
