# DGS-SPICE Simulator

Ein modularer SPICE-Simulator, der Schritt für Schritt in Free Pascal (Object Pascal) entwickelt wird.

## Status: Phase 2 (Transientenanalyse & DC-Arbeitspunkt)
Der Simulator unterstützt:
* **DC-Arbeitspunkt-Analyse (`-OP`)** für R, L, C, V, I.
* **Transientenanalyse (`-TRAN`)** mit implizitem **Backward-Euler-Verfahren** zur stabilen Zeitintegration von Kondensatoren (`C`) und Spulen (`L`).
* **LTSpice-kompatible transiente Quellenfunktionen** für Spannungs- und Stromquellen:
  * `PULSE(...)`
  * `SINE(...)` / `SIN(...)`
  * `PWL(...)`
  * `PWL FILE "filepath"`
* **CSV-Datenexport**: Ergebnisse einer Transientenanalyse werden spaltenweise (Zeit, Knotenspannungen und alle Zweigströme) in eine CSV-Datei exportiert.
* **MNA-Matrix-Visualisierung**: Die Option `--show-matrix` zeigt das aufgestellte Gleichungssystem ($A \cdot x = B$) für jeden Zeitschritt an.

Die mathematische Formulierung erfolgt über die **Modifizierte Knotenpotentialanalyse (MNA)**. Das Gleichungssystem wird mit der mathematischen Bibliothek `LMATH` gelöst.

## Dokumentation

Ausführliche Details findest du im Ordner [docs/](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/docs):
* **[Grundlegende Recherche](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/docs/spice_research.md)**: Recherche über die allgemeine Funktionsweise eines SPICE-Simulators (MNA, Newton-Raphson, Zeitbereichs-Integration).
* **[Technische Dokumentation](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/docs/documentation.md)**: Details zur MNA-Matrix-Assemblierung, dem Stempel-Verfahren und der Integration von `LMATH` in Phase 1.
* **[Implementierungsplan](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/docs/implementation_plan.md)**: Der ursprünglich genehmigte Fahrplan für Phase 1.
* **[Walkthrough & Testergebnisse](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/docs/walkthrough.md)**: Testergebnisse und Verifikationsrechnungen für Spannungsteiler und Brückenschaltungen.

## Projektstruktur

* `DGS_SPICE.lpr`: Hauptprogramm (Konsolenanwendung).
* `uCircuit.pas`: Der mathematische Kern (MNA-Matrix-Aufbau und Solver-Aufruf).
* `uComponents.pas`: Definition der Bauelemente (`TComponent`, `TResistor`, `TVoltageSource`, `TCurrentSource`).
* `uParser.pas`: Parser für SPICE-Netzlisten (inkl. Einheiten-Suffixe).
* `divider.cir`: Testschaltung für einen einfachen Spannungsteiler.
* `bridge.cir`: Testschaltung für eine Wheatstone-Brücke.

## Build-Anleitung

Stelle sicher, dass der Free Pascal Compiler (`fpc`) auf deinem System installiert ist. Compiliere das Projekt unter Einbindung des lokalen LMath-Suchpfades mit:

```bash
fpc -Mdelphi -Fulmath/lmGenMath -Fulmath/lmLinearAlgebra -O2 DGS_SPICE.lpr
```

Führe die Simulation einer Netzliste aus:

```bash
./DGS_SPICE bridge.cir
```

Die Auswahl des Analysetyps erfolgt ausschließlich über entsprechende Steuerbefehle am Ende der Netzliste:
* **`.op`**: Führt eine DC-Arbeitspunkt-Analyse (Operational Point) durch. Dies ist das Standardverhalten, falls kein anderer Steuerbefehl angegeben wird.
* **`.tran <Tstep> <Tstop> [<Tstart>]`**: Startet eine Transientenanalyse (Zeitbereichssimulation).
  * **`Tstep`**: Die Zeitschrittweite der transienten Simulation (z. B. `10u` für $10\,\mu\text{s}$). Bestimmt die Auflösung der Berechnungen.
  * **`Tstop`**: Die Simulationsendzeit (z. B. `5m` für $5\,\text{ms}$).
  * **`Tstart`** *(optional)*: Die Zeit, ab der die Simulationsergebnisse in die CSV exportiert werden sollen. Die Berechnung startet immer ab $t=0$, aber das Schreiben der Ergebnisse erfolgt erst ab `Tstart` (Standard: `0.0`).
* **`.ac`**: AC-Wechselstromanalyse (derzeit noch nicht implementiert).


Um die Simulationsergebnisse als CSV-Datei zu exportieren, kann der optionale Parameter `--csv` verwendet werden:

```bash
./DGS_SPICE bridge.cir --csv ergebnisse.csv
```

Um die Matrizen des aufgestellten Gleichungssystems ($A$ und $B$) anzuzeigen, kann die Option `--show-matrix` angegeben werden:

```bash
./DGS_SPICE bridge.cir --show-matrix
```

## Entwicklungsunterstützung (KI)

Dieses Projekt wurde mit Unterstützung der folgenden künstlichen Intelligenz(en) entwickelt:
* **Antigravity (Google DeepMind)**: Assistenz bei Konzeptionierung, Implementierung der MNA-Matrixstempel, CLI-Parameter-Erweiterungen, Zeitbereichsintegration mit Backward Euler, LTSpice-Source-Funktionen (Pulse, Sine, PWL), CSV-Export, Verifikation und Dokumentation.
