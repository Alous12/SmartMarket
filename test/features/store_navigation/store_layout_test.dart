import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/data/datasources/glb_metadata_reader.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/domain/services/store_layout.dart';

StoreProduct _box(
  String slot, {
  required String node,
  String? shelf,
  String name = 'Producto',
  String category = '',
  int? dbId,
}) => StoreProduct(
  id: 'P_$slot',
  name: name,
  category: category,
  routeNode: node,
  slotId: slot,
  shelfId: shelf,
  dbId: dbId,
);

void main() {
  group('aisleOf', () {
    test('los nodos de pasillo dan un pasillo numerado', () {
      expect(
        aisleOf(routeNode: 'node_pasillo_02_04', shelf: 'E01_09'),
        ('pasillo-2', 'Pasillo 2', 2),
      );
      expect(
        aisleOf(routeNode: 'node_grid_pasillo11_fondo', shelf: 'G12_3'),
        ('pasillo-11', 'Pasillo 11', 11),
      );
    });

    test('las zonas tienen nombre legible', () {
      expect(
        aisleOf(routeNode: 'node_frutas_verduras', shelf: 'S03_05').$2,
        'Frutas y verduras',
      );
      expect(
        aisleOf(routeNode: 'node_frio_bebidas_12', shelf: 'DER_B4_1').$2,
        'Bebidas',
      );
      expect(
        aisleOf(routeNode: 'node_caja_02_fila', shelf: 'E04_60').$2,
        'Cajas',
      );
      expect(aisleOf(routeNode: 'node_lacteos', shelf: 'S04_03').$2, 'Lácteos');
    });

    test('el fondo y las cabeceras se agrupan por su mueble', () {
      expect(
        aisleOf(routeNode: 'node_grid_pasillo7_fondo', shelf: 'FONDO_F01_02').$2,
        'Fondo',
      );
      expect(
        aisleOf(routeNode: 'node_caliente_cabecera3_frente', shelf: 'CAB03_F')
            .$2,
        'Cabeceras',
      );
    });
  });

  group('buildStoreLayout', () {
    test('un estante va entero al pasillo al que dan más espacios', () {
      final layout = buildStoreLayout(
        products: [
          _box('S_1', node: 'node_pasillo_02_02', shelf: 'E1', dbId: 1),
          _box('S_2', node: 'node_frutas_verduras', shelf: 'E1', dbId: 2),
          _box('S_3', node: 'node_pasillo_02_02', shelf: 'E1', dbId: 3),
        ],
        emptySlots: [_box('S_4', node: 'node_pasillo_03_01', shelf: 'E2')],
      );

      expect([for (final a in layout.aisles) a.label], [
        'Pasillo 2',
        'Pasillo 3',
      ]);
      expect(layout.aisles.first.shelves.single.slots, hasLength(3));
      expect(layout.slotCount, 4);
      expect(layout.freeCount, 1);
      expect(layout.locate('S_4')!.$3.isFree, isTrue);
      expect(layout.locateDbProduct(2)!.$1.label, 'Pasillo 2');
      expect(layout.placeOf('S_3'), 'Pasillo 2 · Estante E1 · espacio 3');
    });

    test('en un empate la zona gana solo si vende lo que dice su nombre', () {
      StoreLayout counter(String category) => buildStoreLayout(
        products: [
          _box(
            'A_1',
            node: 'node_carniceria',
            shelf: 'S02',
            category: category,
            dbId: 1,
          ),
          _box(
            'A_2',
            node: 'node_pasillo_03_05',
            shelf: 'S02',
            category: category,
            dbId: 2,
          ),
        ],
        emptySlots: const [],
      );
      expect(counter('Carniceria').aisles.single.label, 'Carnicería');
      expect(counter('Cuidado personal').aisles.single.label, 'Pasillo 3');
    });

    test('cada cara de una góndola va al pasillo al que da', () {
      final layout = buildStoreLayout(
        products: [
          _box('G_1', node: 'node_grid_pasillo4_A', shelf: 'G05_1', dbId: 1),
          _box('G_2', node: 'node_grid_pasillo5_A', shelf: 'G05_1', dbId: 2),
        ],
        emptySlots: const [],
      );
      expect([for (final a in layout.aisles) a.label], [
        'Pasillo 4',
        'Pasillo 5',
      ]);
      expect(layout.locate('G_2')!.$2.code, 'G05_1');
    });

    test('las categorías del pasillo van de la más a la menos frecuente', () {
      final layout = buildStoreLayout(
        products: [
          _box('C_1', node: 'node_pasillo_1', category: 'Snacks', dbId: 1),
          _box('C_2', node: 'node_pasillo_1', category: 'Pastas', dbId: 2),
          _box('C_3', node: 'node_pasillo_1', category: 'Pastas', dbId: 3),
        ],
        emptySlots: const [],
      );
      expect(layout.aisles.single.categories(), ['Pastas', 'Snacks']);
    });

    test('los estantes y espacios siguen el orden natural', () {
      final layout = buildStoreLayout(
        products: [
          _box('SLOT_G10_1_10', node: 'node_pasillo_1', shelf: 'G10_1'),
          _box('SLOT_G2_1_2', node: 'node_pasillo_1', shelf: 'G2_1'),
          _box('SLOT_G2_1_10', node: 'node_pasillo_1', shelf: 'G2_1'),
        ],
        emptySlots: const [],
      );
      final shelves = layout.aisles.single.shelves;
      expect([for (final s in shelves) s.code], ['G2_1', 'G10_1']);
      expect([for (final s in shelves.first.slots) s.code], [
        'SLOT_G2_1_2',
        'SLOT_G2_1_10',
      ]);
    });
  });

  for (final (path, aisles) in [
    ('Modelos_3D/supermercado_1.glb', 7),
    ('Modelos_3D/supermercado_2.glb', 12),
  ]) {
    test('modelo real $path: cada espacio tiene pasillo y estante', () {
      final metadata = readGlbMetadata(File(path).readAsBytesSync());
      final boxes = metadata.products;
      expect(boxes.every((box) => box.shelfId != null), isTrue);

      final layout = buildStoreLayout(products: boxes, emptySlots: const []);
      expect(layout.slotCount, boxes.length);
      // Pasillos 1..N sin huecos, y cada espacio aparece una sola vez.
      expect(
        [
          for (final aisle in layout.aisles)
            if (aisle.number != null) aisle.number,
        ],
        [for (var n = 1; n <= aisles; n++) n],
      );
      final codes = [for (final aisle in layout.aisles) ...aisle.slots]
          .map((slot) => slot.code)
          .toList();
      expect(codes.toSet(), hasLength(boxes.length));
      expect(codes, hasLength(boxes.length));
    });
  }
}
