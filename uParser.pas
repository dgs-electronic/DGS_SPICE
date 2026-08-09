unit uParser;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Generics.Collections, uComponents, uCircuit;

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

function ParseSourceFunction(const AFuncStr: string): TSourceFunction;
var
  FuncStr, UpperStr, ArgsStr: string;
  OpenParen, CloseParen: Integer;
  Args: TStringArray;
  i, count: Integer;
  Filename: string;
  FileLines: TStringList;
  LineParts: TStringArray;
  LineIdx: Integer;
  PairList: TList<TPwlPoint>;
  Point: TPwlPoint;
begin
  Result := TSourceFunction.Create;
  FuncStr := Trim(AFuncStr);
  UpperStr := UpperCase(FuncStr);
  
  if StartsText('PULSE', UpperStr) then
  begin
    Result.FuncType := ftPulse;
    OpenParen := Pos('(', FuncStr);
    CloseParen := LastDelimiter(')', FuncStr);
    if (OpenParen > 0) and (CloseParen > OpenParen) then
      ArgsStr := Copy(FuncStr, OpenParen + 1, CloseParen - OpenParen - 1)
    else
      ArgsStr := '';
      
    ArgsStr := ReplaceStr(ArgsStr, ',', ' ');
    Args := SplitWhitespace(ArgsStr);
    
    count := Length(Args);
    if count >= 1 then Result.V1 := ParseSpiceValue(Args[0]);
    if count >= 2 then Result.V2 := ParseSpiceValue(Args[1]);
    if count >= 3 then Result.TD := ParseSpiceValue(Args[2]);
    if count >= 4 then Result.TR := ParseSpiceValue(Args[3]);
    if count >= 5 then Result.TF := ParseSpiceValue(Args[4]);
    if count >= 6 then Result.PW := ParseSpiceValue(Args[5]);
    if count >= 7 then Result.PER := ParseSpiceValue(Args[6]);
    if count >= 8 then Result.Ncycles := ParseSpiceValue(Args[7]);
  end
  else if StartsText('SINE', UpperStr) or StartsText('SIN', UpperStr) then
  begin
    Result.FuncType := ftSine;
    OpenParen := Pos('(', FuncStr);
    CloseParen := LastDelimiter(')', FuncStr);
    if (OpenParen > 0) and (CloseParen > OpenParen) then
      ArgsStr := Copy(FuncStr, OpenParen + 1, CloseParen - OpenParen - 1)
    else
      ArgsStr := '';
      
    ArgsStr := ReplaceStr(ArgsStr, ',', ' ');
    Args := SplitWhitespace(ArgsStr);
    
    count := Length(Args);
    if count >= 1 then Result.VO := ParseSpiceValue(Args[0]);
    if count >= 2 then Result.VA := ParseSpiceValue(Args[1]);
    if count >= 3 then Result.FREQ := ParseSpiceValue(Args[2]);
    if count >= 4 then Result.TD := ParseSpiceValue(Args[3]);
    if count >= 5 then Result.THETA := ParseSpiceValue(Args[4]);
    if count >= 6 then Result.PHI := ParseSpiceValue(Args[5]);
    if count >= 7 then Result.Ncycles := ParseSpiceValue(Args[6]);
  end
  else if StartsText('PWL', UpperStr) then
  begin
    Result.FuncType := ftPwl;
    
    if ContainsText(UpperStr, 'FILE') then
    begin
      Filename := FuncStr;
      Filename := ReplaceText(Filename, 'PWL', '');
      Filename := ReplaceText(Filename, 'pwl', '');
      Filename := ReplaceText(Filename, 'FILE', '');
      Filename := ReplaceText(Filename, 'file', '');
      Filename := ReplaceText(Filename, '(', '');
      Filename := ReplaceText(Filename, ')', '');
      Filename := ReplaceText(Filename, '=', '');
      Filename := ReplaceText(Filename, '"', '');
      Filename := ReplaceText(Filename, '''', '');
      Filename := Trim(Filename);
      
      if not FileExists(Filename) then
        raise Exception.CreateFmt('PWL file "%s" not found.', [Filename]);
        
      FileLines := TStringList.Create;
      PairList := TList<TPwlPoint>.Create;
      try
        FileLines.LoadFromFile(Filename);
        for LineIdx := 0 to FileLines.Count - 1 do
        begin
          ArgsStr := Trim(FileLines[LineIdx]);
          if (ArgsStr = '') or (ArgsStr[1] = ';') or (ArgsStr[1] = '*') or (ArgsStr[1] = '#') then
            Continue;
            
          ArgsStr := ReplaceStr(ArgsStr, ',', ' ');
          ArgsStr := ReplaceStr(ArgsStr, ':', ' ');
          LineParts := SplitWhitespace(ArgsStr);
          if Length(LineParts) >= 2 then
          begin
            Point.Time := ParseSpiceValue(LineParts[0]);
            Point.Value := ParseSpiceValue(LineParts[1]);
            PairList.Add(Point);
          end;
        end;
        
        SetLength(Result.PwlPoints, PairList.Count);
        for i := 0 to PairList.Count - 1 do
          Result.PwlPoints[i] := PairList[i];
      finally
        PairList.Free;
        FileLines.Free;
      end;
    end
    else
    begin
      OpenParen := Pos('(', FuncStr);
      CloseParen := LastDelimiter(')', FuncStr);
      if (OpenParen > 0) and (CloseParen > OpenParen) then
        ArgsStr := Copy(FuncStr, OpenParen + 1, CloseParen - OpenParen - 1)
      else
        ArgsStr := Copy(FuncStr, 4, Length(FuncStr) - 3);
        
      ArgsStr := ReplaceStr(ArgsStr, ',', ' ');
      Args := SplitWhitespace(ArgsStr);
      
      count := Length(Args) div 2;
      if count = 0 then
        raise Exception.Create('PWL function has no time-value pairs.');
        
      SetLength(Result.PwlPoints, count);
      for i := 0 to count - 1 do
      begin
        Result.PwlPoints[i].Time := ParseSpiceValue(Args[2 * i]);
        Result.PwlPoints[i].Value := ParseSpiceValue(Args[2 * i + 1]);
      end;
    end;
  end
  else
  begin
    raise Exception.CreateFmt('Unknown source function: "%s"', [FuncStr]);
  end;
end;

function ParseNetlist(const AFilename: string): TCircuit;
var
  Circuit: TCircuit;
  Lines: TStringList;
  Line: string;
  Parts: TStringArray;
  CompName, Node1, Node2, FuncStr: string;
  Val, Val2, Val3: Double;
  i, j: Integer;
  SourceFunc: TSourceFunction;
  HasFunc: Boolean;
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

      // Parse control cards
      if Line[1] = '.' then
      begin
        if StartsText('.TRAN', Line) then
        begin
          Parts := SplitWhitespace(Line);
          if Length(Parts) < 3 then
          begin
            Circuit.Free;
            raise Exception.CreateFmt('Error on line %d: Invalid .tran command. Expected: .tran <Tstep> <Tstop> [<Tstart>]', [i + 1]);
          end;
          try
            Val := ParseSpiceValue(Parts[1]); // TStep
            Val2 := ParseSpiceValue(Parts[2]); // TStop
            if Length(Parts) >= 4 then
              Val3 := ParseSpiceValue(Parts[3])
            else
              Val3 := 0.0;
            Circuit.TStep := Val;
            Circuit.TStop := Val2;
            Circuit.TStart := Val3;
            Circuit.HasTran := True;
          except
            on E: Exception do
            begin
              Circuit.Free;
              raise Exception.CreateFmt('Error parsing .tran on line %d: %s', [i + 1, E.Message]);
            end;
          end;
        end
        else if StartsText('.OP', Line) then
        begin
          Circuit.HasOp := True;
        end
        else if StartsText('.AC', Line) then
        begin
          Circuit.HasAc := True;
        end;
        Continue;
      end;

      Parts := SplitWhitespace(Line);
      if Length(Parts) < 4 then
        Continue; // Invalid line or incomplete component line

      CompName := Parts[0];
      Node1 := Parts[1];
      Node2 := Parts[2];
      
      Val := 0.0;
      SourceFunc := nil;
      HasFunc := False;

      // Special parsing for V and I sources which can have transient functions
      if (UpCase(CompName[1]) = 'V') or (UpCase(CompName[1]) = 'I') then
      begin
        FuncStr := '';
        for j := 3 to Length(Parts) - 1 do
        begin
          if j > 3 then FuncStr := FuncStr + ' ';
          FuncStr := FuncStr + Parts[j];
        end;
        FuncStr := Trim(FuncStr);

        try
          Val := ParseSpiceValue(Parts[3]);
          if Length(Parts) > 4 then
          begin
            FuncStr := '';
            for j := 4 to Length(Parts) - 1 do
            begin
              if j > 4 then FuncStr := FuncStr + ' ';
              FuncStr := FuncStr + Parts[j];
            end;
            FuncStr := Trim(FuncStr);
            HasFunc := (FuncStr <> '');
          end;
        except
          HasFunc := (FuncStr <> '');
          Val := 0.0;
        end;

        if HasFunc then
        begin
          try
            SourceFunc := ParseSourceFunction(FuncStr);
            if Val = 0.0 then
              Val := SourceFunc.Evaluate(0.0);
          except
            on E: Exception do
            begin
              Circuit.Free;
              raise Exception.CreateFmt('Error parsing function on line %d: %s', [i + 1, E.Message]);
            end;
          end;
        end;
      end
      else
      begin
        try
          Val := ParseSpiceValue(Parts[3]);
        except
          on E: Exception do
          begin
            Circuit.Free;
            raise Exception.CreateFmt('Error on line %d: %s', [i + 1, E.Message]);
          end;
        end;
      end;

      case UpCase(CompName[1]) of
        'R': Circuit.AddComponent(TResistor.Create(CompName, Node1, Node2, Val));
        'V': Circuit.AddComponent(TVoltageSource.Create(CompName, Node1, Node2, Val, SourceFunc));
        'I': Circuit.AddComponent(TCurrentSource.Create(CompName, Node1, Node2, Val, SourceFunc));
        'C': Circuit.AddComponent(TCapacitor.Create(CompName, Node1, Node2, Val));
        'L': Circuit.AddComponent(TInductor.Create(CompName, Node1, Node2, Val));
        else
          Writeln('Warning: Component ', CompName, ' ignored.');
      end;
    end;
  finally
    Lines.Free;
  end;

  Result := Circuit;
end;

end.
