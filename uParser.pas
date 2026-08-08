unit uParser;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, uComponents, uCircuit;

{ Parses a SPICE netlist file and returns a TCircuit object }
function ParseNetlist(const AFilename: string): TCircuit;

{ Helper function to parse SPICE-style values (e.g. 1k, 2.5mA, 1e-3) }
function ParseSpiceValue(const S: string): Double;

implementation

{ Helper to split a string by whitespace (spaces and tabs) }
type
  TStringArray = array of string;

function SplitWhitespace(const S: string): TStringArray;
var
  i, len: Integer;
  WordStart: Integer;
  InWord: Boolean;
begin
  Result := nil;
  len := Length(S);
  InWord := False;
  WordStart := 1;

  for i := 1 to len do
  begin
    if (S[i] = ' ') or (S[i] = #9) then
    begin
      if InWord then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result) - 1] := Copy(S, WordStart, i - WordStart);
        InWord := False;
      end;
    end
    else
    begin
      if not InWord then
      begin
        WordStart := i;
        InWord := True;
      end;
    end;
  end;

  if InWord then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[Length(Result) - 1] := Copy(S, WordStart, len - WordStart + 1);
  end;
end;

function ParseSpiceValue(const S: string): Double;
var
  CleanS, NumPart, SufPart: string;
  i, len: Integer;
  ValDouble: Double;
  Scale: Double;
  fs: TFormatSettings;
begin
  CleanS := Trim(S);
  if CleanS = '' then Exit(0.0);

  // Use standard English format settings (decimal point is '.')
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';

  len := Length(CleanS);
  
  // Find where the numeric part ends.
  // A number can contain digits, '.', 'e', 'E', '+' and '-'.
  // But '+' and '-' are only valid at the start or immediately after 'e'/'E'.
  i := 1;
  while i <= len do
  begin
    if (CleanS[i] in ['0'..'9', '.', 'e', 'E', '+', '-']) then
    begin
      // Basic sanity check to avoid treating 'm' after 'e' as something else
      Inc(i);
    end
    else
    begin
      Break;
    end;
  end;

  NumPart := Copy(CleanS, 1, i - 1);
  SufPart := UpperCase(Copy(CleanS, i, len - i + 1));

  // Try to parse the numeric part.
  // If it's empty, or fails, we try parsing the whole string.
  if not TryStrToFloat(NumPart, ValDouble, fs) then
  begin
    if not TryStrToFloat(CleanS, ValDouble, fs) then
      raise EConvertError.CreateFmt('Invalid SPICE value: "%s"', [S]);
    Exit(ValDouble);
  end;

  Scale := 1.0;
  if SufPart <> '' then
  begin
    if StartsText('MEG', SufPart) then
      Scale := 1.0E6
    else if StartsText('T', SufPart) then
      Scale := 1.0E12
    else if StartsText('G', SufPart) then
      Scale := 1.0E9
    else if StartsText('K', SufPart) then
      Scale := 1.0E3
    // Note: 'M' or 'm' is milli (1e-3) in SPICE. 'MEG' is mega (1e6).
    else if StartsText('M', SufPart) then
      Scale := 1.0E-3
    else if StartsText('U', SufPart) then
      Scale := 1.0E-6
    else if StartsText('N', SufPart) then
      Scale := 1.0E-9
    else if StartsText('P', SufPart) then
      Scale := 1.0E-12
    else if StartsText('F', SufPart) then
      Scale := 1.0E-15;
  end;

  Result := ValDouble * Scale;
end;

function ParseNetlist(const AFilename: string): TCircuit;
var
  Circuit: TCircuit;
  Lines: TStringList;
  Line: string;
  Parts: TStringArray;
  CompName, Node1, Node2, ValStr: string;
  Val: Double;
  i: Integer;
begin
  Circuit := TCircuit.Create;
  Lines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(AFilename);
    except
      on E: Exception do
      begin
        Circuit.Free;
        raise Exception.CreateFmt('Could not read file "%s": %s', [AFilename, E.Message]);
      end;
    end;

    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      
      // Skip empty lines and comment lines (starting with '*')
      if (Line = '') or (Line[1] = '*') then
        Continue;

      // Also skip control cards starting with '.' for now (like .op, .tran etc.)
      if Line[1] = '.' then
        Continue;

      Parts := SplitWhitespace(Line);
      if Length(Parts) < 4 then
        Continue; // Invalid line or incomplete component line

      CompName := Parts[0];
      Node1 := Parts[1];
      Node2 := Parts[2];
      ValStr := Parts[3];

      try
        Val := ParseSpiceValue(ValStr);
      except
        on E: Exception do
        begin
          Circuit.Free;
          raise Exception.CreateFmt('Error on line %d: %s', [i + 1, E.Message]);
        end;
      end;

      case UpCase(CompName[1]) of
        'R': Circuit.AddComponent(TResistor.Create(CompName, Node1, Node2, Val));
        'V': Circuit.AddComponent(TVoltageSource.Create(CompName, Node1, Node2, Val));
        'I': Circuit.AddComponent(TCurrentSource.Create(CompName, Node1, Node2, Val));
        else
          // Ignore other components for now (e.g. C, L, D, Q etc. in Phase 1)
          Writeln('Warning: Component ', CompName, ' ignored (Phase 1 supports R, V, I).');
      end;
    end;
  finally
    Lines.Free;
  end;

  Result := Circuit;
end;

end.
