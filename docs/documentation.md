# Technische Dokumentation: DGS-SPICE Phase 2 (Transientenanalyse & DC-Arbeitspunkt)

DGS-SPICE ist ein in Free Pascal geschriebener SPICE-Simulator. Diese Dokumentation beschreibt die Architektur, die mathematischen Grundlagen und die konkrete Implementierung von **Phase 2** (Transientenanalyse und linearer Gleichstrom-Arbeitspunkt).

---

## 1. Projektstruktur und Komponenten

Das Projekt besteht aus folgenden Hauptdateien im Verzeichnis `DGS-SPICE`:

* **`DGS_SPICE.lpr`**: Der Einstiegspunkt (Hauptprogramm). Übernimmt die Argumentenverarbeitung, steuert den Ablauf (Parsen -> Berechnen -> Ausgeben) und formatiert die Terminalausgabe. Schaltet automatisch auf Transientenanalyse um, wenn eine `.tran`-Anweisung in der Netzliste enthalten ist.
* **`uCircuit.pas`**: Der mathematische Kern. Verwaltet die Schaltungstopologie, die MNA-Matrix-Assemblierung, den Gleichstrom-Arbeitspunkt und die Zeitintegrationsschleife.
* **`uComponents.pas`**: Die Bauelemente-Unit. Definiert die Basisklasse `TComponent`, die konkreten Bauelemente (`TResistor`, `TVoltageSource`, `TCurrentSource`, `TCapacitor`, `TInductor`) und die LTSpice-kompatiblen Quellenfunktionen (`TSourceFunction`).
* **`uParser.pas`**: Der Netzlisten-Parser. Übersetzt Textdateien in die internen Objektstrukturen, liest Steuerkarten wie `.tran` und parst komplexe transiente Quellenbeschreibungen wie `PULSE(...)`, `SINE(...)`, `PWL(...)` und `PWL FILE ...`.

---

## 2. Mathematische Grundlagen: Modifizierte Knotenpotentialanalyse (MNA)

Der Simulator stellt für eine Schaltung ein lineares Gleichungssystem der Form:

```text
A * x = B
```

auf. Die Dimension `D` dieses Systems berechnet sich aus:

```text
D = N_active + N_sources
```

wobei:
* `N_active` die Anzahl der Knoten ohne Bezugspotential (Masse `0` / `GND`) ist.
* `N_sources` die Anzahl der unabhängigen Spannungsquellen (inkl. Spulen, da diese im DC-Fall als Kurzschlüsse mit Zweigströmen modelliert werden) ist.

---

## 3. Diskrete Zeitintegration (Backward-Euler-Verfahren)

Für die Transientenanalyse (`-TRAN`) wird das kontinuierliche Verhalten von Kapazitäten (`C`) und Spulen (`L`) über das **implizite Euler-Verfahren (Backward Euler)** in diskrete Stempel überführt. Dies geschieht in jedem Zeitschritt `t` mit Schrittweite `h`.

### 3.1 Kapazität (`TCapacitor`)
Das kontinuierliche Gesetz lautet:
```text
i_C(t) = C * d(v_C(t)) / dt
```

Die Diskretisierung nach dem Backward-Euler-Verfahren im Schritt `t_n+1` ergibt:
```text
i_C(t_n+1) = C * (v_C(t_n+1) - v_C(t_n)) / h = Geq * v_C(t_n+1) - Ieq
```

Hierbei ist:
* **Ersatzleitwert**: `Geq = C / h`
* **Ersatzstromquelle**: `Ieq = (C / h) * v_C(t_n)` (parallel zu `Geq` geschaltet, fließt von Knoten `n1` zu `n2`)

**MNA-Stempel im Transientenschritt**:
* `A[n1, n1] += Geq`
* `A[n1, n2] -= Geq`
* `A[n2, n1] -= Geq`
* `A[n2, n2] += Geq`
* `B[n1] += Ieq`
* `B[n2] -= Ieq`

### 3.2 Spule (`TInductor`)
Das kontinuierliche Gesetz lautet:
```text
v_L(t) = L * d(i_L(t)) / dt
```

Die Diskretisierung nach dem Backward-Euler-Verfahren ergibt:
```text
v_L(t_n+1) = L * (i_L(t_n+1) - i_L(t_n)) / h
=> v_L(t_n+1) - (L / h) * i_L(t_n+1) = -(L / h) * i_L(t_n)
```

Dies führt zu einer zusätzlichen Gleichung für den Zweigstrom `i_L` (Spalten- und Zeilenindex `V_idx`):
* **Ersatzwiderstand**: `Req = L / h`
* **Ersatzspannungsquelle**: `Veq = -(L / h) * i_L(t_n)`

**MNA-Stempel im Transientenschritt**:
* `A[n1, V_idx] += 1.0`
* `A[n2, V_idx] -= 1.0`
* `A[V_idx, n1] += 1.0`
* `A[V_idx, n2] -= 1.0`
* `A[V_idx, V_idx] -= Req`
* `B[V_idx] += Veq`

---

## 4. Transiente Quellenfunktionen (`TSourceFunction`)

Spannungs- und Stromquellen können transiente Funktionen zur zeitabhängigen Signalgenerierung verwenden:

### 4.1 PULSE(V1 V2 TD TR TF PW PER [Ncycles])
Generiert eine periodische Pulsfolge.
* `V1`: Anfangswert
* `V2`: Pulswert
* `TD`: Verzögerungszeit (Delay)
* `TR` / `TF`: Anstiegs- und Abfallzeit (Standard: `1e-12` s falls `0.0`)
* `PW`: Pulsbreite
* `PER`: Periode
* `Ncycles`: Anzahl der Zyklen (Standard: unendlich)

### 4.2 SINE(VO VA FREQ TD THETA PHI Ncycles) or SIN(...)
Generiert eine gedämpfte Sinusschwingung.
* `VO`: DC-Offset
* `VA`: Amplitude
* `FREQ`: Frequenz
* `TD`: Verzögerungszeit (Delay)
* `THETA`: Dämpfungsfaktor
* `PHI`: Phasenwinkel in Grad
* `Ncycles`: Anzahl der Zyklen

### 4.3 PWL(t1 v1 t2 v2 ...)
Stückweise linearer Verlauf (Piece-Wise Linear). Zwischen den angegebenen Stützstellen `(t_i, v_i)` wird linear interpoliert. Außerhalb des Intervalls wird der erste bzw. letzte Wert gehalten.

### 4.4 PWL FILE "filename"
Liest den stückweise linearen Verlauf aus einer externen Textdatei aus. Unterstützt Kommentare (`*`, `;`, `#`) sowie standardmäßige SPICE-Einheiten-Suffixe.

---

## 5. Solver & Simulationsablauf

### 5.1 DC-Arbeitspunkt (`-OP`)
Für den DC-Arbeitspunkt gilt `h = 0.0`. Kondensatoren werden als offene Leitungen (`Geq = 1e-12` S) und Spulen als Kurzschlüsse (`Req = 0.0` Ohm) modelliert. Die MNA-Gleichung wird einmalig gelöst.

### 5.2 Transientenanalyse (`-TRAN`)
1. **Initialisierung**: Zuerst wird der DC-Arbeitspunkt bei `t = 0` gelöst. Aus dieser Lösung werden die Anfangszustände `v_C(0)` und `i_L(0)` für alle Kondensatoren und Spulen extrahiert.
2. **Kopfzeile schreiben**: Die CSV-Datei wird geöffnet und die Kopfzeilen (`Time`, Knotenspannungen, Bauelementeströme) sortiert geschrieben.
3. **Anfangszustand schreiben**: Die berechneten DC-Werte bei `t = 0` werden in die CSV eingetragen.
4. **Zeitschleife**: Von `t = TStart + TStep` bis `TStop` wird in Schritten von `h = TStep` berechnet:
   * Die Systemmatrix `A` und der Vektor `B` werden vollständig geleert und neu gestempelt (unter Einbeziehung der aktuellen Zeit `t` für transiente Quellen und der Schrittweite `h` für `C` und `L`).
   * Das System wird gelöst mit `LinEq(A, B, 1, Dim, Det)`.
   * Die neuen Kondensatorspannungen und Spulenströme werden für den nächsten Schritt gespeichert.
   * Der Zeitschritt wird als Datenzeile in die CSV geschrieben.

---

## 6. CSV-Exportformat (Transient)

Die transiente CSV-Datei enthält eine Kopfzeile mit allen Knotenspannungen (alphabetisch sortiert) und allen Zweigströmen durch sämtliche Bauelemente (ebenfalls alphabetisch sortiert):

```csv
Time,V(1),V(2),V(3),I(C1),I(L1),I(R1),I(V1)
0,0,0,0,0,0,0,0
0.00001,0.31395,0.31084,0.00031,0.00031,0.00031,0.00031,-0.00031
0.00002,0.62666,0.61739,0.00123,0.00092,0.00092,0.00092,-0.00092
```

---

## 7. Kompilierung und Ausführung

### Kompilieren via Lazarus CLI
Da das Projekt eine Lazarus-Projektdatei besitzt, kann es plattformunabhängig und ohne manuelle Pfadkonfiguration compiliert werden:
```bash
lazbuild DGS_SPICE.lpi
```

### Ausführen einer Simulation
Die Ausführung erfolgt unter Angabe der Netzlistendatei. Die Art der Simulation wird über Steuerbefehle (.op, .tran, .ac) am Ende der Netzliste bestimmt:
```bash
./DGS_SPICE rc_pulse.cir
```

#### Unterstützte Analyse-Steuerbefehle:
* **`.op`**: Führt eine DC-Arbeitspunkt-Analyse (Operational Point) durch. Dies ist der Standardmodus, falls kein Steuerbefehl angegeben wird.
* **`.tran <Tstep> <Tstop> [<Tstart>]`**: Führt eine Transientenanalyse (Zeitbereichssimulation) durch. Die Ergebnisse werden standardmäßig in eine CSV-Datei exportiert (z. B. `rc_pulse.csv`).
  * **`Tstep`**: Die Zeitschrittweite der transienten Simulation (z. B. `10u` = $10\,\mu\text{s}$). Dieser Wert bestimmt das Intervall `h` zwischen aufeinanderfolgenden Berechnungen und somit die Genauigkeit der Ergebnisse.
  * **`Tstop`**: Die Simulationsendzeit (z. B. `5m` = $5\,\text{ms}$). Die Zeitintegrationsschleife stoppt, sobald dieser Wert erreicht ist.
  * **`Tstart`** *(optional)*: Die Zeit, ab der die Simulationsergebnisse in die CSV-Datei exportiert werden sollen. Die Berechnung startet immer ab $t=0$ (um Einschwingvorgänge zu berücksichtigen), aber das Schreiben der Zeilen in die CSV-Datei beginnt erst ab `Tstart` (Standardwert: `0.0`).
* **`.ac`**: Führt eine AC-Wechselstromanalyse durch (derzeit noch nicht implementiert; gibt Fehlermeldung und Exit-Code `3` aus).

