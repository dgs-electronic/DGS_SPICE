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

--- Stroeme durch alle Komponenten ---
  I(R1)      =     0.005000 A
  I(R2)      =     0.005000 A
  I(V1)      =    -0.005000 A
========================================
```
* **Verifikation:**
  - Die Spannung an Knoten `2` beträgt exakt $5\text{V}$ (Spannungsteiler-Formel: $10\text{V} \cdot \frac{1\text{k}}{1\text{k}+1\text{k}} = 5\text{V}$).
  - Der Strom durch $R_1$ und $R_2$ beträgt $5\text{mA}$.
  - Der Strom aus der Quelle $V_1$ beträgt $-5\text{mA}$ (das negative Vorzeichen folgt dem Verbraucher-Zählpfeilsystem).
  - Alle Werte stimmen physikalisch überein. **Erfolg.**

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

--- Stroeme durch alle Komponenten ---
  I(R1)      =     0.003273 A
  I(R2)      =     0.005455 A
  I(R3)      =     0.005455 A
  I(R4)      =     0.003273 A
  I(R5)      =    -0.002182 A
  I(V1)      =    -0.008727 A
========================================
```
* **Verifikation:**
  - Die analytisch berechneten Spannungen liegen bei $v_2 = 60/11\text{V} \approx 5{,}454545\text{V}$ und $v_3 = 72/11\text{V} \approx 6{,}545455\text{V}$.
  - Der Strom durch $R_5$ (von Knoten 2 nach 3) beträgt: $I(R_5) = \frac{5{,}454545 - 6{,}545455}{500} \approx -0{,}002182\text{ A}$ (fließt also von 3 nach 2).
  - Der Strom durch $V_1$ beträgt $-8{,}727\text{ mA}$ und gleicht der Summe der Ströme in $R_1$ und $R_2$ ($3{,}273\text{ mA} + 5{,}455\text{ mA} = 8{,}728\text{ mA}$).
  - Kirchhoffsches Knotengesetz (KCL) an Knoten 2: $-I(R_1) + I(R_3) + I(R_5) = -3{,}273\text{ mA} + 5{,}455\text{ mA} - 2{,}182\text{ mA} = 0$.
  - Alle Werte sind konsistent und korrekt. **Erfolg.**

---

### Test 3: Spulen- und Kondensatortest (`lc_test.cir`)
Netzliste:
```spice
* LC Test Circuit
V1 1 0 10
R1 1 2 1k
C1 2 0 10u
L1 2 3 10m
R2 3 0 1k
```

Ausgabe des Simulators (mit `--show-matrix`):
```text
Lese Netzliste ein: lc_test.cir
Berechne Arbeitspunkt...

--- Systemgleichungen (MNA-Matrix) ---
                      V(1)          V(2)          V(3)         I(V1)         I(L1)       B-Vektor
KCL(1)      [     0.001000,    -0.001000,     0.000000,     1.000000,     0.000000 ] = [     0.000000 ]
KCL(2)      [    -0.001000,     0.001000,     0.000000,     0.000000,     1.000000 ] = [     0.000000 ]
KCL(3)      [     0.000000,     0.000000,     0.001000,     0.000000,    -1.000000 ] = [     0.000000 ]
Eq(V1)      [     1.000000,     0.000000,     0.000000,     0.000000,     0.000000 ] = [    10.000000 ]
Eq(L1)      [     0.000000,     1.000000,    -1.000000,     0.000000,     0.000000 ] = [     0.000000 ]


========================================
          SIMULATIONSERGEBNISSE
========================================
--- Knotenspannungen ---
  V(0)    =     0.000000 V
  V(1)    =    10.000000 V
  V(2)    =     5.000000 V
  V(3)    =     5.000000 V
  V(GND)    =     0.000000 V

--- Stroeme durch alle Komponenten ---
  I(C1)    =     0.000000 A
  I(L1)    =     0.005000 A
  I(R1)    =     0.005000 A
  I(R2)    =     0.005000 A
  I(V1)    =    -0.005000 A
========================================
```
* **Verifikation:**
  - Im DC-Zustand verhält sich der Kondensator $C_1$ als Leerlauf (offene Verbindung), daher fließt durch $C_1$ kein Strom ($I(C_1) = 0\text{ A}$).
  - Die Spule $L_1$ verhält sich als Kurzschluss (Widerstand $0\ \Omega$), wodurch $V(2) = V(3) = 5\text{ V}$ erzwungen wird.
  - Das verbleibende System entspricht einem einfachen Spannungsteiler aus $R_1$ ($1\text{k}$) und $R_2$ ($1\text{k}$) in Serie an der $10\text{V}$-Spannungsquelle. Der Strom beträgt $I = \frac{10\text{V}}{1\text{k} + 1\text{k}} = 5\text{ mA}$.
  - Alle Ströme und Knotenspannungen sind mathematisch und physikalisch korrekt. **Erfolg.**
