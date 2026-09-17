import 'package:flutter/material.dart';

import '../../core/ui/colores.dart';
import '../catalogo/catalogo_screen.dart';
import '../cuenta/cuenta_screen.dart';
import '../historial/historial_screen.dart';
import '../reservas/bolsa_screen.dart';
import '../reservas/bolsa_store.dart';
import '../reservas/reservas_screen.dart';

/// Navegación principal por pestañas (sesión persistente).
class HomeScreen extends StatefulWidget {
  final VoidCallback onSesionCerrada;
  const HomeScreen({super.key, required this.onSesionCerrada});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final paginas = [
      const CatalogoScreen(),
      BolsaScreen(
        onReservaCreada: () => setState(() => _indice = 2),
      ),
      const ReservasScreen(),
      const HistorialScreen(),
      CuentaScreen(onSesionCerrada: widget.onSesionCerrada),
    ];
    const titulos = [
      'Catálogo',
      'Bolsa de reserva',
      'Mis reservas',
      'Mis compras',
      'Mi cuenta',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulos[_indice],
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const Text(
              'FashionStore · Recoge en tienda',
              style: TextStyle(fontSize: 12, color: ColoresFS.textMuted),
            ),
          ],
        ),
        actions: [
          if (_indice == 0)
            AnimatedBuilder(
              animation: BolsaStore.instancia,
              builder: (_, __) {
                final n = BolsaStore.instancia.totalPrendas;
                return Stack(
                  children: [
                    IconButton(
                      tooltip: 'Abrir bolsa',
                      icon: const Icon(Icons.shopping_bag_outlined),
                      onPressed: () => setState(() => _indice = 1),
                    ),
                    if (n > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ColoresFS.danger,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: IndexedStack(index: _indice, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: BolsaStore.instancia.totalPrendas > 0,
              label: Text('${BolsaStore.instancia.totalPrendas}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            label: 'Bolsa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Reservas',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket),
            label: 'Compras',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
