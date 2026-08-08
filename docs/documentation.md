# Technische Dokumentation: DGS-SPICE Phase 1

DGS-SPICE ist ein in Free Pascal geschriebener SPICE-Simulator. Diese Dokumentation beschreibt die Architektur, die mathematischen Grundlagen und die konkrete Implementierung von **Phase 1** (linearer Gleichstrom-Arbeitspunkt).

---

## 1. Projektstruktur und Komponenten

Das Projekt ist modular aufgebaut und besteht aus vier Hauptdateien im Verzeichnis `DGS-SPICE`:

* **`DGS_SPICE.lpr`**: Der Einstiegspunkt (Hauptprogramm). Übernimmt die Argumentenverarbeitung, steuert den Ablauf (Parsen -> Berechnen -> Ausgeben) und formatiert die Terminalausgabe.
* **`uCircuit.pas`**: Der mathematische Kern. Verwaltet die Schaltungstopologie, die MNA-Matrix-Assemblierung und den Aufruf des Solvers.
* **`uComponents.pas`**: Die Bauelemente-Unit. Definiert die Basisklasse `TComponent` sowie deren konkrete Nachkommen (`TResistor`, `TVoltageSource`, `TCurrentSource`) und deren Stempel-Methoden.
* **`uParser.pas`**: Der Netzlisten-Parser. Übersetzt Textdateien in die internen Objektstrukturen und berechnet Skalierungsfaktoren für physikalische Einheiten.

---

## 2. Mathematische Grundlagen: Modifizierte Knotenpotentialanalyse (MNA)

Der Simulator stellt für eine Schaltung ein lineares Gleichungssystem der Form:

$$A \cdot x = B$$

auf. Die Dimension $D$ dieses Systems berechnet sich aus:

$$D = N_{active} + N_{sources}$$

wobei:
* $N_{active}$ die Anzahl der Knoten ohne Bezugspotential (Masse `0` / `GND`) ist.
* $N_{sources}$ die Anzahl der unabhängigen Spannungsquellen ist.

### Matrix-Layout im Speicher
Unter Verwendung der `LMATH`-Bibliothek wird die Matrix $A$ als zweidimensionales dynamisches Array `TMatrix` (`array of array of Float`) angelegt und über die Prozedur `DimMatrix(A, D, D)` initialisiert. Dies ermöglicht eine intuitive 2D-Indexierung `A[Row, Col]` direkt mit den 1-basierten Knotenindizes, ohne flache Indexberechnungen.

### Stempel-Verfahren (Stamping) in Pascal
Jedes Bauelement erbt von der Klasse `TComponent` und implementiert die Methode `Stamp`:

```pascal
procedure Stamp(var A: TMatrix; var B: TVector;
                NodeMap: TDictionary<string, Integer>;
                VSourceIdx: Integer); virtual; abstract;
```

#### 1. Widerstand (`TResistor`)
Ein Widerstand mit Wert $R$ (Leitwert $g = 1/R$) zwischen Knoten $n_1$ und $n_2$ addiert Leitwerte an den Kreuzungspunkten der Knoten:
* $A[n_1, n_1] \mathrel{+}= g$
* $A[n_1, n_2] \mathrel{-}= g$
* $A[n_2, n_1] \mathrel{-}= g$
* $A[n_2, n_2] \mathrel{+}= g$

#### 2. Unabhängige Stromquelle (`TCurrentSource`)
Eine Stromquelle mit Strom $I$ von Knoten $n_1$ nach $n_2$ speist Strom aus $n_1$ aus und in $n_2$ ein:
* $B[n_1] \mathrel{-}= I$
* $B[n_2] \mathrel{+}= I$

#### 3. Unabhängige Spannungsquelle (`TVoltageSource`)
Eine Spannungsquelle mit Spannung $V$ zwischen Knoten $n_1$ (positiv) und $n_2$ (negativ) führt eine zusätzliche Unbekannte ein (den Strom $I_{src}$ durch die Quelle). Dieser bekommt den Spalten- und Zeilenindex $V_{idx} = N_{active} + \text{Quellen-Index}$:
* $A[n_1, V_{idx}] \mathrel{+}= 1.0$
* $A[n_2, V_{idx}] \mathrel{-}= 1.0$
* $A[V_{idx}, n_1] \mathrel{+}= 1.0$
* $A[V_{idx}, n_2] \mathrel{-}= 1.0$
* $B[V_{idx}] \mathrel{+}= V$

*Hinweis: Stempel-Operationen, die sich auf den Masse-Knoten (`0` oder `GND`) beziehen, werden in der Matrix ignorert (da das Massepotential als bekannt vorausgesetzt und zu $0\text{V}$ definiert ist).*

---

## 3. Solver-Integration (`LMATH`)

Die Lösung des Gleichungssystems erfolgt über die LMath-Unit `ulineq` mittels des Gauss-Jordan-Algorithmus:

```pascal
LinEq(A, B, 1, Dim, Det);
```

* **`A`**: Systemkoeffizienten-Matrix (Typ `TMatrix`), wird während der Berechnung überschrieben.
* **`B`**: RHS-Eingangsvektor (Typ `TVector`), wird nach erfolgreichem Berechnen direkt mit dem Lösungsvektor überschrieben (Knotenspannungen $1 \dots N_{active}$, gefolgt von den Strömen der Spannungsquellen).
* **`1`**: Untere Indexgrenze des zu lösenden Systems.
* **`Dim`**: Obere Indexgrenze des Systems.
* **`Det`**: Rückgabewert für die Determinante der Matrix (Typ `Float`).

Nach dem Aufruf wird über die Funktion `MathErr` geprüft, ob die Berechnung erfolgreich war (Rückgabewert `MatOk` oder `0`). Ist die Matrix singulär, wird der Fehlercode `MatSing` (`8`) zurückgegeben.

---

## 4. Parser & Einheiten-Verarbeitung

Der Parser in `uParser.pas` liest die Netzliste zeilenweise ein, ignoriert Kommentare (`*`) und Steuerbefehle (`.`).
Die Skalierung physikalischer Werte erfolgt über reguläre Suffixe (case-insensitive):

| Suffix | Name | Faktor | Beispiel in Netzliste |
|---|---|---|---|
| **T** | Tera | $10^{12}$ | `1T` |
| **G** | Giga | $10^9$ | `2.5G` |
| **MEG** | Mega | $10^6$ | `10Meg` |
| **K** | Kilo | $10^3$ | `1k` |
| **M** | Milli | $10^{-3}$ | `10m` / `10M` *(SPICE-Standard!)* |
| **U** | Mikro | $10^{-6}$ | `1u` |
| **N** | Nano | $10^{-9}$ | `4.7n` |
| **P** | Piko | $10^{-12}$ | `10p` |
| **F** | Femto | $10^{-15}$ | `1f` |

---

## 5. Kompilierung und Ausführung

### Voraussetzungen
* Installierter Free Pascal Compiler (`fpc`), Version 3.0+. Die `LMATH`-Bibliotheksdateien müssen im lokalen Projektverzeichnis unter `lmath/` liegen.

### Kompilieren
Im Projektverzeichnis ausführen (unter Einbindung des LMATH-Suchpfads und Aktivierung des Delphi-Kompatibilitätsmodus):
```bash
fpc -vm4046 -Mdelphi -Fulmath/lmGenMath -Fulmath/lmLinearAlgebra -O2 DGS_SPICE.lpr
```

### Ausführen
```bash
./DGS_SPICE divider.cir
```
