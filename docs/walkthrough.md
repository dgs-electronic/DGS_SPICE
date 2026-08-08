# Walkthrough: DGS-SPICE Phase 1 (Linearer DC-Simulator)

Phase 1 des SPICE-Simulators für lineare Gleichstromschaltungen wurde erfolgreich implementiert und verifiziert. Der Simulator liest Netzlistendateien ein, stellt die MNA-Matrix auf, löst das Gleichungssystem unter Verwendung der mathematischen Bibliothek `LMATH` und gibt die Knotenspannungen sowie Quellströme formatiert aus.

---

## Erstellte Dateien und Module

1. **[uCircuit.pas](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/uCircuit.pas):**
   * Definiert die Komponentenklassen `TComponent`, `TResistor`, `TVoltageSource` und `TCurrentSource`.
   * Implementiert die `Stamp`-Methoden zur Platzierung der Leitwerte und Quellströme/spannungen in der MNA-Matrix.
   * `TCircuit` übernimmt das Zuweisen eindeutiger Knotenindizes (mit automatischer Erkennung von Masse-Knoten `0` und `GND` als `0`) und ruft `LinEq` aus `LMATH` (`ulineq`) auf.
2. **[uParser.pas](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/uParser.pas):**
   * Ein SPICE-Netzlisten-Parser, der Zeilen zerlegt und die Suffixe (`k`, `M` für milli, `MEG` für mega, `u`, `n`, `p` usw.) korrekt in numerische Fließkommazahlen konvertiert.
3. **[DGS_SPICE.lpr](file:///home/dominik/Lazarus%20Projekte/DGS-SPICE/DGS_SPICE.lpr):**
   * Die ausführbare Konsolenanwendung. Sie nimmt eine Datei als Kommandozeilenargument, stößt das Parsen und Lösen an und gibt die Ergebnisse in einer sauberen Tabellenform aus.

---

## Testergebnisse und Verifikation

### Test 1: Einfacher Spannungsteiler (`divider.cir`)
Netzliste:
```spice
* Einfacher Spannungsteiler
V1 1 0 10
R1 1 2 1k
R2 2 0 1k
```

Ausgabe des Simulators:
```text
========================================
          SIMULATIONSERGEBNISSE         
========================================
--- Knotenspannungen ---
  V(0)       =     0.000000 V
  V(1)       =    10.000000 V
  V(2)       =     5.000000 V
  V(GND)     =     0.000000 V

--- Stroeme durch Spannungsquellen ---
  I(V1)      =    -0.005000 A
========================================
```
* **Verifikation:** Die Spannung an Knoten `2` beträgt exakt $5\text{V}$, der Strom aus der Quelle beträgt $5\text{mA}$ (das negative Vorzeichen folgt dem Verbraucher-Zählpfeilsystem). **Erfolg.**

---

### Test 2: Wheatstone-Brückenschaltung (`bridge.cir`)
Netzliste:
```spice
* Wheatstone-Bruecke mit Spannungsquelle
V1 1 0 12
R1 1 2 2k
R2 1 3 1k
R3 2 0 1k
R4 3 0 2k
R5 2 3 500
```

Ausgabe des Simulators:
```text
========================================
          SIMULATIONSERGEBNISSE         
========================================
--- Knotenspannungen ---
  V(0)       =     0.000000 V
  V(1)       =    12.000000 V
  V(2)       =     5.454545 V
  V(3)       =     6.545455 V
  V(GND)     =     0.000000 V

--- Stroeme durch Spannungsquellen ---
  I(V1)      =    -0.008727 A
========================================
```
* **Verifikation:** Die analytisch berechneten Spannungen liegen bei $v_2 = 60/11\text{V} \approx 5{,}454545\text{V}$ und $v_3 = 72/11\text{V} \approx 6{,}545455\text{V}$, der Gesamtstrom bei $96/11\text{mA} \approx 8{,}72727\text{mA}$. Die Simulationsergebnisse stimmen exakt damit überein. **Erfolg.**
