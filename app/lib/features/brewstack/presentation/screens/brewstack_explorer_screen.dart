import 'package:flutter/material.dart';

import '../../../../core/exploration/explorable_collection.dart';

class BrewStackExplorerScreen extends StatelessWidget {
  const BrewStackExplorerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ExplorableCollection<BrewStackObject>(
          title: 'BrewStack v2',
          subtitle:
              'Operations table and venue-place discovery over one dataset',
          listLabel: 'Ops View',
          spatialLabel: 'Venue View',
          searchHint: 'Search tables, menu, events, routines',
          randomLabel: 'Surprise',
          listHelpText:
              'Scan status, ownership, and service context without leaving the shared filters.',
          spatialHelpText:
              'Browse adjacent service objects by venue zone and open what catches your eye.',
          loadingLabel: 'Opening the kitchen...',
          emptyTitle: 'Nothing in this service lane',
          emptyMessage: 'Clear search or pick another operating category.',
          randomSeed: 7,
          items: brewStackExplorerItems,
        ),
      ),
    );
  }
}

enum BrewStackObjectKind { table, menu, event, routine }

class BrewStackObject {
  const BrewStackObject({
    required this.kind,
    required this.owner,
    required this.priority,
  });

  final BrewStackObjectKind kind;
  final String owner;
  final String priority;
}

const brewStackExplorerItems = [
  ExplorableCollectionItem<BrewStackObject>(
    id: 'taproom-table-12',
    title: 'Table 12',
    subtitle: 'Four-top by the west windows',
    category: 'Floor',
    group: 'Taproom',
    details:
        'Live service object for seating, QR ordering, tab handoff, and server coverage.',
    tags: ['QR active', 'Window', 'High turn'],
    metrics: {'Status': 'Open', 'Covers': '4', 'Server': 'Maya'},
    icon: Icons.table_restaurant_outlined,
    color: Color(0xFF2E7D32),
    semanticLabel: 'Table 12, four top by the west windows',
    payload: BrewStackObject(
      kind: BrewStackObjectKind.table,
      owner: 'Floor team',
      priority: 'High',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'bar-counter',
    title: 'Counter',
    subtitle: 'Eight bar seats with tasting flights',
    category: 'Floor',
    group: 'Bar',
    details:
        'Fast-turn seats that can switch between open tabs, sampler flights, and walk-up orders.',
    tags: ['Flights', 'Walk-up', 'Tap list'],
    metrics: {'Status': 'Busy', 'Seats': '8', 'Avg turn': '31m'},
    icon: Icons.local_bar_outlined,
    color: Color(0xFF1565C0),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.table,
      owner: 'Bar team',
      priority: 'High',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'seasonal-ipa',
    title: 'Monsoon IPA',
    subtitle: 'Limited release with citrus pairing prompts',
    category: 'Menu',
    group: 'Draft Wall',
    details:
        'Customer-facing preview can sit beside inventory, margin, and pairing notes in Ops View.',
    tags: ['Limited', 'Citrus', 'Pairing'],
    metrics: {'ABV': '6.4%', 'Margin': '68%', 'Keg': '42%'},
    icon: Icons.sports_bar_outlined,
    color: Color(0xFFC62828),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.menu,
      owner: 'Menu team',
      priority: 'Medium',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'guest-preview',
    title: 'Guest Preview',
    subtitle: 'Customer menu state for QR ordering',
    category: 'Menu',
    group: 'Draft Wall',
    details:
        'A visual preview catches mismatched descriptions, sold-out badges, and missing pairings.',
    tags: ['QR menu', 'Preview', 'Accessibility'],
    metrics: {'Visible items': '36', 'Sold out': '3'},
    icon: Icons.phone_iphone_outlined,
    color: Color(0xFF6A1B9A),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.menu,
      owner: 'Guest experience',
      priority: 'Medium',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'trivia-night',
    title: 'Trivia Night',
    subtitle: 'Thursday event with reserved high-tops',
    category: 'Events',
    group: 'Stage',
    details:
        'Event object connects calendar, seating holds, promo copy, and staffing requirements.',
    tags: ['Calendar', 'Reservations', 'Promo'],
    metrics: {'Starts': '7 PM', 'Holds': '6 tables'},
    icon: Icons.event_outlined,
    color: Color(0xFFEF6C00),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.event,
      owner: 'Events team',
      priority: 'High',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'brewery-tour',
    title: 'Brewery Tour',
    subtitle: 'Saturday walkthrough with tasting close',
    category: 'Events',
    group: 'Back House',
    details:
        'Spatial adjacency makes the tour route inspectable beside safety checks and sample pours.',
    tags: ['Tour', 'Samples', 'Waiver'],
    metrics: {'Capacity': '18', 'Guide': 'Ravi'},
    icon: Icons.route_outlined,
    color: Color(0xFF00838F),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.event,
      owner: 'Hospitality',
      priority: 'Medium',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'last-call-routine',
    title: 'Last Call',
    subtitle: 'Closing automation checklist',
    category: 'Routines',
    group: 'Bar',
    details:
        'Routine card keeps automation visible next to the physical area where work happens.',
    tags: ['Checklist', 'Cash-out', 'Cleaning'],
    metrics: {'Steps': '9', 'Owner': 'Shift lead'},
    icon: Icons.task_alt_outlined,
    color: Color(0xFF455A64),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.routine,
      owner: 'Shift lead',
      priority: 'High',
    ),
  ),
  ExplorableCollectionItem<BrewStackObject>(
    id: 'keg-change',
    title: 'Keg Change',
    subtitle: 'Draft-line maintenance routine',
    category: 'Routines',
    group: 'Back House',
    details:
        'Connects inventory state, staff assignment, and customer menu availability.',
    tags: ['Inventory', 'Maintenance', 'Menu sync'],
    metrics: {'Due': 'Now', 'Line': '4'},
    icon: Icons.build_outlined,
    color: Color(0xFF5D4037),
    payload: BrewStackObject(
      kind: BrewStackObjectKind.routine,
      owner: 'Brew team',
      priority: 'High',
    ),
  ),
];
