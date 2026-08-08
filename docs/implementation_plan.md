# Implementierungsplan: DGS-SPICE Phase 1 (Linearer DC-Simulator)

Dieser Plan beschreibt die Erstellung des ersten lauffähigen Meilensteins: Eine Konsolenanwendung in Free Pascal, die einfache Gleichstromschaltungen (bestehend aus Widerständen, unabhängigen Spannungsquellen und unabhängigen Stromquellen) einliest, mittels MNA-Matrix aufstellt, über `LMATH` löst und die Ergebnisse ausgibt.

## Architekturübersicht

Wir teilen das Projekt in drei Hauptbestandteile auf:
1. **Datenstrukturen & MNA (`uCircuit.pas`):** Definiert die Klassen für Komponenten (`TComponent`, `TResistor`, `TVoltageSource`, `TCurrentSource`) und die Schaltung (`TCircuit`). Diese Unit enthält auch den Code zur MNA-Matrix-Assemblierung und den Aufruf von `LMATH.ulineq.LinEq`.
2. **Parser (`uParser.pas`):** Liest eine standardnahe Netzlistendatei (z. B. `.cir`) ein, konvertiert Werte mit Einheiten (wie `1k` -> `1000.0`, `10u` -> `1E-5`) und baut das `TCircuit`-Objekt auf.
3. **Hauptprogramm (`DGS_SPICE.lpr`):** Die ausführbare Konsolenanwendung, die Dateipfade verarbeitet und die Ausführung steuert.

---

## Vorgeschlagene Änderungen

### [NEW] [uCircuit.pas](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/uCircuit.pas)
Diese Unit enthält das mathematische und strukturelle Herzstück von Phase 1.

* **Datenstrukturen:**
  ```pascal
  type
    TComponent = class
      Name: string;
      Node1, Node2: string; // Knotennamen aus der Netzliste
      Value: Double;
      procedure Stamp(var A: TMatrix; var B: TVector; 
                      NodeMap: TDictionary; var VSourceCount: Integer); virtual; abstract;
    end;
  ```
* **MNA Matrix-Befüllung (Stamping):**
  * `TCircuit` sammelt alle eindeutigen Knotennamen und weist ihnen fortlaufende Indizes zu (Masse-Knoten `0` oder `GND` bekommt immer Index `0`).
  * Jede Spannungsquelle erhöht die Matrix-Dimension um $1$ (für ihren Strom).
  * Die Matrix-Dimension ist somit $N_{Knoten} + N_{Spannungsquellen} - 1$.
  * Wir befüllen die Matrix $A$ und den Vektor $b$ über die `Stamp`-Methoden der Komponenten.
* **Lösung:**
  * Aufruf von `LinEq` aus der LMath-Unit `ulineq`.

### [NEW] [uParser.pas](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/uParser.pas)
Verantwortlich für das Einlesen von SPICE-Netzlisten.
* Unterstützt Zeilen der Form:
  * `R<Name> <Knoten1> <Knoten2> <Wert>` (z. B. `R1 1 2 1k`)
  * `V<Name> <Knoten1> <Knoten2> <Wert>` (z. B. `V1 1 0 5V`)
  * `I<Name> <Knoten1> <Knoten2> <Wert>` (z. B. `I1 2 0 2mA`)
* Konvertiert Einheiten-Suffixe (`k`, `M`, `m`, `u`, `n`, `p`).
* Ignoriert Kommentarzeilen (beginnend mit `*`).

### [NEW] [DGS_SPICE.lpr](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/DGS_SPICE.lpr)
Die Hauptdatei der Konsolenanwendung.
* Verarbeitet Kommandozeilenargumente (Netzlistendatei).
* Ruft Parser und Solver auf.
* Gibt die Knotenspannungen und Ströme sauber formatiert auf der Konsole aus.

---

## Verifikationsplan

### Automatisierte Tests / Testschaltungen
Wir werden Testnetzlisten erstellen und das Ergebnis mit analytisch berechneten Werten vergleichen.

#### Test 1: Einfacher Spannungsteiler (`divider.cir`)
```spice
* Spannungsteiler
V1 1 0 10
R1 1 2 1k
R2 2 0 1k
```
* **Erwartetes Ergebnis:** 
  * Spannung an Knoten `1` = `10.0 V`
  * Spannung an Knoten `2` = `5.0 V`
  * Strom durch `V1` = `-0.005 A` (Verbraucher-Zählpfeilsystem)

#### Test 2: Brückenschaltung mit Stromquelle (`bridge.cir`)
```spice
* Wheatstone-Brücke mit Stromquelle
V1 1 0 12
R1 1 2 2k
R2 1 3 1k
R3 2 0 1k
R4 3 0 2k
R5 2 3 500
```
* **Erwartetes Ergebnis:** Rechnerische Überprüfung der Brückenspannung $V(2) - V(3)$.

### Manuelle Verifikation
* Ausführen des Simulators über die Kommandozeile und Überprüfung der Terminal-Ausgabe.
