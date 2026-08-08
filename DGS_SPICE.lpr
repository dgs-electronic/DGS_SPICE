program DGS_SPICE;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, Generics.Collections, uCircuit, uParser;

procedure ShowUsage;
begin
  Writeln('DGS-SPICE Simulator - Phase 1 (Gleichstrom-Arbeitspunkt)');
  Writeln('Usage: DGS_SPICE <Netzliste.cir>');
  Writeln;
end;

procedure PrintResults(NodeVoltages: TDictionary<string, Double>;
                       SourceCurrents: TDictionary<string, Double>);
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
  Writeln('--- Stroeme durch Spannungsquellen ---');
  KeysList := TStringList.Create;
  try
    for Key in SourceCurrents.Keys do
      KeysList.Add(Key);
    KeysList.Sort;

    for i := 0 to KeysList.Count - 1 do
    begin
      Key := KeysList[i];
      Writeln(Format('  I(%s)'.PadRight(10) + ' = %12.6f A', [Key, SourceCurrents[Key]]));
    end;
  finally
    KeysList.Free;
  end;

  Writeln('========================================');
end;

var
  Filename: string;
  Circuit: TCircuit;
  NodeVoltages: TDictionary<string, Double>;
  SourceCurrents: TDictionary<string, Double>;
  Success: Boolean;
begin
  if ParamCount < 1 then
  begin
    ShowUsage;
    ExitCode := 1;
    Exit;
  end;

  Filename := ParamStr(1);
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

  Writeln('Berechne Arbeitspunkt...');
  try
    Circuit.Solve(NodeVoltages, SourceCurrents, Success);
    if Success then
    begin
      PrintResults(NodeVoltages, SourceCurrents);
      NodeVoltages.Free;
      SourceCurrents.Free;
    end
    else
    begin
      Writeln('Fehler: Schaltung konnte nicht geloest werden (Matrix singulaer?).');
      ExitCode := 2;
    end;
  finally
    Circuit.Free;
  end;
end.
