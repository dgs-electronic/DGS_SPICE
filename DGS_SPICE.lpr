program DGS_SPICE;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, Generics.Collections, uCircuit, uParser;

type
  TAnalysisMode = (amOP, amTRAN, amAC);

procedure ShowUsage;
begin
  Writeln('DGS-SPICE Simulator');
  Writeln('Usage: DGS_SPICE <Netzliste.cir> [--csv <Output-Datei>] [--show-matrix]');
  Writeln('Die Art der Simulation wird ueber Steuerbefehle am Ende der Netzliste bestimmt:');
  Writeln('  .op                    DC-Arbeitspunkt-Analyse (Standard)');
  Writeln('  .tran <step> <stop>    Transientenanalyse');
  Writeln('  .ac                    AC-Wechselstromanalyse (noch nicht implementiert)');
  Writeln('Optionen:');
  Writeln('  --csv <Output-Datei>   Speichert die Simulationsergebnisse als CSV-Datei ab.');
  Writeln('  --show-matrix          Zeigt die Systemmatrizen des Gleichungssystems an.');
  Writeln;
end;

procedure SaveResultsToCsv(const AFilename: string;
                           NodeVoltages: TDictionary<string, Double>;
                           ComponentCurrents: TDictionary<string, Double>);
var
  Lines: TStringList;
  KeysList: TStringList;
  Key: string;
  i: Integer;
  fs: TFormatSettings;
begin
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';

  Lines := TStringList.Create;
  KeysList := TStringList.Create;
  try
    Lines.Add('Type,Name,Value,Unit');

    // 1. Sort and add node voltages
    for Key in NodeVoltages.Keys do
      KeysList.Add(Key);
    KeysList.Sort;

    for i := 0 to KeysList.Count - 1 do
    begin
      Key := KeysList[i];
      Lines.Add(Format('Voltage,%s,%s,V', [Key, FloatToStr(NodeVoltages[Key], fs)]));
    end;

    KeysList.Clear;

    // 2. Sort and add currents
    for Key in ComponentCurrents.Keys do
      KeysList.Add(Key);
    KeysList.Sort;

    for i := 0 to KeysList.Count - 1 do
    begin
      Key := KeysList[i];
      Lines.Add(Format('Current,%s,%s,A', [Key, FloatToStr(ComponentCurrents[Key], fs)]));
    end;

    try
      Lines.SaveToFile(AFilename);
      Writeln('Ergebnisse erfolgreich in CSV-Datei gespeichert: ', AFilename);
    except
      on E: Exception do
        Writeln('Fehler beim Speichern der CSV-Datei: ', E.Message);
    end;
  finally
    KeysList.Free;
    Lines.Free;
  end;
end;

procedure PrintResults(NodeVoltages: TDictionary<string, Double>;
                       ComponentCurrents: TDictionary<string, Double>);
var
  KeysList: TStringList;
  Key: string;
  i: Integer;
begin
  Writeln;
  Writeln('========================================');
  Writeln('          SIMULATIONSERGEBNISSE         ');
  Writeln('========================================');

  // 1. Sort and print node voltages
  Writeln('--- Knotenspannungen ---');
  KeysList := TStringList.Create;
  try
    for Key in NodeVoltages.Keys do
      KeysList.Add(Key);
    KeysList.Sort;

    for i := 0 to KeysList.Count - 1 do
    begin
      Key := KeysList[i];
      Writeln(Format('  V(%s)'.PadRight(10) + ' = %12.6f V', [Key, NodeVoltages[Key]]));
    end;
  finally
    KeysList.Free;
  end;

  Writeln;

  // 2. Sort and print currents
  Writeln('--- Stroeme durch alle Komponenten ---');
  KeysList := TStringList.Create;
  try
    for Key in ComponentCurrents.Keys do
      KeysList.Add(Key);
    KeysList.Sort;

    for i := 0 to KeysList.Count - 1 do
    begin
      Key := KeysList[i];
      Writeln(Format('  I(%s)'.PadRight(10) + ' = %12.6f A', [Key, ComponentCurrents[Key]]));
    end;
  finally
    KeysList.Free;
  end;

  Writeln('========================================');
end;

var
  Filename: string;
  CsvFilename: string;
  Circuit: TCircuit;
  NodeVoltages: TDictionary<string, Double>;
  ComponentCurrents: TDictionary<string, Double>;
  Success: Boolean;
  ArgIdx: Integer;
  ShowMatrix: Boolean;
  AnalysisMode: TAnalysisMode;
begin
  if ParamCount < 1 then
  begin
    ShowUsage;
    ExitCode := 1;
    Exit;
  end;

  Filename := '';
  CsvFilename := '';
  ShowMatrix := False;
  AnalysisMode := amOP; // Default to OP

  ArgIdx := 1;
  while ArgIdx <= ParamCount do
  begin
    if (ParamStr(ArgIdx) = '--csv') then
    begin
      if ArgIdx + 1 <= ParamCount then
      begin
        CsvFilename := ParamStr(ArgIdx + 1);
        Inc(ArgIdx, 2);
      end
      else
      begin
        Writeln('Fehler: Dateiname fuer CSV-Export fehlt.');
        ShowUsage;
        ExitCode := 1;
        Exit;
      end;
    end
    else if (ParamStr(ArgIdx) = '--show-matrix') then
    begin
      ShowMatrix := True;
      Inc(ArgIdx);
    end
    else
    begin
      if Filename = '' then
        Filename := ParamStr(ArgIdx)
      else
      begin
        Writeln('Fehler: Unbekannter Parameter "', ParamStr(ArgIdx), '".');
        ShowUsage;
        ExitCode := 1;
        Exit;
      end;
      Inc(ArgIdx);
    end;
  end;

  if Filename = '' then
  begin
    Writeln('Fehler: Keine Netzliste angegeben.');
    ShowUsage;
    ExitCode := 1;
    Exit;
  end;

  if not FileExists(Filename) then
  begin
    Writeln('Fehler: Datei "', Filename, '" existiert nicht.');
    ExitCode := 1;
    Exit;
  end;

  Writeln('Lese Netzliste ein: ', Filename);
  try
    Circuit := ParseNetlist(Filename);
  except
    on E: Exception do
    begin
      Writeln('Fehler beim Parsen: ', E.Message);
      ExitCode := 1;
      Exit;
    end;
  end;

  // Determine final analysis mode based on netlist control cards
  if Circuit.HasAc then
  begin
    Writeln('Fehler: AC-Analyse (.ac) ist noch nicht implementiert.');
    ExitCode := 3;
    Circuit.Free;
    Exit;
  end
  else if Circuit.HasTran then
  begin
    AnalysisMode := amTRAN;
  end
  else
  begin
    AnalysisMode := amOP;
  end;

  if AnalysisMode = amTRAN then
  begin
    if CsvFilename = '' then
      CsvFilename := ChangeFileExt(Filename, '.csv');

    Writeln('Starte Transientenanalyse...');
    Writeln(Format('Tstep = %g, Tstop = %g, Tstart = %g', [Circuit.TStep, Circuit.TStop, Circuit.TStart]));
    try
      Circuit.SolveTransient(CsvFilename, Success, ShowMatrix);
      if Success then
      begin
        Writeln('Transientenanalyse erfolgreich beendet.');
        Writeln('Ergebnisse gespeichert in: ', CsvFilename);
      end
      else
      begin
        Writeln('Fehler: Transientenanalyse abgebrochen.');
        ExitCode := 2;
      end;
    finally
      Circuit.Free;
    end;
  end
  else
  begin
    Writeln('Berechne Arbeitspunkt...');
    try
      Circuit.Solve(NodeVoltages, ComponentCurrents, Success, ShowMatrix);
      if Success then
      begin
        PrintResults(NodeVoltages, ComponentCurrents);
        
        if CsvFilename <> '' then
          SaveResultsToCsv(CsvFilename, NodeVoltages, ComponentCurrents);

        NodeVoltages.Free;
        ComponentCurrents.Free;
      end
      else
      begin
        Writeln('Fehler: Schaltung konnte nicht geloest werden (Matrix singulaer?).');
        ExitCode := 2;
      end;
    finally
      Circuit.Free;
    end;
  end;
end.
