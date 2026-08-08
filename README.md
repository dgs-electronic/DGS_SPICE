# DGS-SPICE Simulator

Ein modularer SPICE-Simulator, der Schritt für Schritt in Free Pascal (Object Pascal) entwickelt wird.

## Status: Phase 1 (Erfolgreich abgeschlossen)
Der Simulator unterstützt in dieser Phase die **lineare DC-Analyse (Gleichstrom-Arbeitspunkt)** für Schaltungen aus:
* Widerständen (`R`)
* Unabhängigen Spannungsquellen (`V`)
* Unabhängigen Stromquellen (`I`)

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

Um die Simulationsergebnisse als CSV-Datei zu exportieren, kann der optionale Parameter `--csv` verwendet werden:

```bash
./DGS_SPICE bridge.cir --csv ergebnisse.csv
```

Um die Matrizen des aufgestellten Gleichungssystems ($A$ und $B$) anzuzeigen, kann die Option `--show-matrix` angegeben werden:

```bash
./DGS_SPICE bridge.cir --show-matrix
```
