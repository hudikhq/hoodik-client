import 'package:flutter_test/flutter_test.dart';
import 'package:hoodik_app/core/search/search_rank.dart';

/// Golden ranking cases, mirrored in the web's `rank.test.ts` the same way
/// the cross-client tag vector is. A deliberate change to the tiers
/// regenerates both together.
void main() {
  test('tokenizes queries like the index does', () {
    expect(queryWords('IMG_0179.mov'), ['img', '0179', 'mov']);
    expect(queryWords('a b! š-9'), isEmpty);
  });

  test('exact filename beats every text-rich note', () {
    const video = RankableRow(
      id: 'v',
      name: 'IMG_0179.mov',
      searchHits: 3,
      searchNameHits: 3,
    );
    const note = RankableRow(
      id: 'n',
      name: 'todo.md',
      searchHits: 40,
      searchNameHits: 0,
    );

    final order = rankSearchResults('IMG_0179.mov', [note, video]);
    expect(order, [1, 0]);
  });

  test('name prefix beats a big document with many tag hits', () {
    const todo = RankableRow(
      id: 't',
      name: 'todo.md',
      searchHits: 2,
      searchNameHits: 2,
    );
    const handoff = RankableRow(
      id: 'h',
      name: 'handoff.md',
      searchHits: 99,
      searchNameHits: 0,
    );

    final order = rankSearchResults('todo', [handoff, todo]);
    expect(order, [1, 0]);
  });

  test('a hydrated body phrase beats a partial name match', () {
    const config = RankableRow(
      id: 'c',
      name: 'duzluk.md',
      searchHits: 2,
      searchNameHits: 0,
      body: 'notes on the solar inverter wiring and limits',
    );
    const panels = RankableRow(
      id: 'p',
      name: 'solar-panels.md',
      searchHits: 2,
      searchNameHits: 1,
    );

    final order = rankSearchResults('solar inverter', [panels, config]);
    expect(order, [1, 0]);
  });

  test('newer row wins a score tie', () {
    const older = RankableRow(id: 'o', name: 'plan.md', recency: 100);
    const newer = RankableRow(id: 'n', name: 'plan.md', recency: 200);

    final order = rankSearchResults('plan', [older, newer]);
    expect(order, [1, 0]);
  });

  test('pinned score values shared with the web suite', () {
    // The exact numbers the tiers produce, pinned so a drift between the
    // web and app implementations fails a test instead of splitting the
    // ranking between clients.
    expect(
      scoreRow(
        'todo',
        const RankableRow(
          id: 'a',
          name: 'todo.md',
          searchHits: 2,
          searchNameHits: 2,
        ),
      ),
      612020,
    );
    expect(
      scoreRow(
        'solar inverter',
        const RankableRow(
          id: 'b',
          name: 'duzluk.md',
          searchHits: 2,
          searchNameHits: 0,
          body: 'notes on the solar inverter wiring and limits',
        ),
      ),
      80020,
    );
  });
}
