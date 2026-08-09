unit uCircuit;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, Generics.Collections, utypes, uErrors, ulineq, uComponents;

type
  { Main Circuit class }
  TCircuit = class
  private
    FComponents: TObjectList<TComponent>;
    FNodes: TList<string>;
    FNodeMap: TDictionary<string, Integer>;
    FVSourceCount: Integer;
    FTStep: Double;
    FTStop: Double;
    FTStart: Double;
    FHasTran: Boolean;
    FHasOp: Boolean;
    FHasAc: Boolean;

    procedure RegisterNode(const ANode: string);
    procedure BuildNodeMap;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddComponent(AComp: TComponent);
    procedure Solve(out NodeVoltages: TDictionary<string, Double>;
                    out ComponentCurrents: TDictionary<string, Double>;
                    out Success: Boolean;
                    AShowMatrix: Boolean = False);
    procedure SolveTransient(const ACsvFilename: string; out Success: Boolean; AShowMatrix: Boolean = False);
    
    property Components: TObjectList<TComponent> read FComponents;
    property TStep: Double read FTStep write FTStep;
    property TStop: Double read FTStop write FTStop;
    property TStart: Double read FTStart write FTStart;
    property HasTran: Boolean read FHasTran write FHasTran;
    property HasOp: Boolean read FHasOp write FHasOp;
    property HasAc: Boolean read FHasAc write FHasAc;
  end;

implementation

{ TCircuit }

constructor TCircuit.Create;
begin
  FComponents := TObjectList<TComponent>.Create(True);
  FNodes := TList<string>.Create;
  FNodeMap := TDictionary<string, Integer>.Create;
  FVSourceCount := 0;
  FTStep := 0.0;
  FTStop := 0.0;
  FTStart := 0.0;
  FHasTran := False;
  FHasOp := False;
  FHasAc := False;
end;

destructor TCircuit.Destroy;
begin
  FComponents.Free;
  FNodes.Free;
  FNodeMap.Free;
  inherited Destroy;
end;

procedure TCircuit.AddComponent(AComp: TComponent);
begin
  FComponents.Add(AComp);
end;

procedure TCircuit.RegisterNode(const ANode: string);
begin
  if (ANode = '0') or (ANode = 'GND') then
    Exit;
  if not FNodeMap.ContainsKey(ANode) then
  begin
    FNodes.Add(ANode);
    FNodeMap.Add(ANode, FNodes.Count);
  end;
end;

procedure TCircuit.BuildNodeMap;
var
  Comp: TComponent;
begin
  FNodes.Clear;
  FNodeMap.Clear;
  FVSourceCount := 0;

  FNodeMap.Add('0', 0);
  FNodeMap.Add('GND', 0);

  for Comp in FComponents do
  begin
    RegisterNode(Comp.Node1);
    RegisterNode(Comp.Node2);
    if (Comp is TVoltageSource) or (Comp is TInductor) then
      Inc(FVSourceCount);
  end;
end;

procedure TCircuit.Solve(out NodeVoltages: TDictionary<string, Double>;
                         out ComponentCurrents: TDictionary<string, Double>;
                         out Success: Boolean;
                         AShowMatrix: Boolean = False);
var
  NActiveNodes, Dim: Integer;
  A: TMatrix;
  B: TVector;
  Det: Float;
  i, VIdx: Integer;
  Comp: TComponent;
  NodeName: string;
  VarNames, EqNames: array of string;
begin
  Success := False;
  NodeVoltages := TDictionary<string, Double>.Create;
  ComponentCurrents := TDictionary<string, Double>.Create;

  BuildNodeMap;

  NActiveNodes := FNodes.Count;

  Dim := NActiveNodes + FVSourceCount;
  if Dim = 0 then
  begin
    Success := True;
    Exit;
  end;

  // Allocate matrix A and vector B (0-based arrays up to index Dim)
  DimMatrix(A, Dim, Dim);
  DimVector(B, Dim);

  // Initialize with zeros
  for i := 0 to Dim do B[i] := 0.0;
  for i := 0 to Dim do
    for VIdx := 0 to Dim do
      A[i, VIdx] := 0.0;

  // 3. Stamp components
  VIdx := NActiveNodes; // Row index for voltage sources starts after active nodes
  for Comp in FComponents do
  begin
    if (Comp is TVoltageSource) or (Comp is TInductor) then
    begin
      Inc(VIdx);
      Comp.Stamp(A, B, FNodeMap, VIdx, 0.0, 0.0);
    end
    else
    begin
      Comp.Stamp(A, B, FNodeMap, 0, 0.0, 0.0);
    end;
  end;

  if AShowMatrix then
  begin
    Writeln;
    Writeln('--- Systemgleichungen (MNA-Matrix) ---');
    
    SetLength(VarNames, Dim + 1);
    SetLength(EqNames, Dim + 1);
    for i := 1 to NActiveNodes do
    begin
      VarNames[i] := 'V(' + FNodes[i-1] + ')';
      EqNames[i] := 'KCL(' + FNodes[i-1] + ')';
    end;
    
    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if (Comp is TVoltageSource) or (Comp is TInductor) then
      begin
        Inc(VIdx);
        VarNames[VIdx] := 'I(' + Comp.Name + ')';
        EqNames[VIdx] := 'Eq(' + Comp.Name + ')';
      end;
    end;

    // Print column headers
    Write(''.PadRight(12));
    for VIdx := 1 to Dim do
      Write(VarNames[VIdx].PadLeft(14));
    Writeln('       B-Vektor');

    // Print rows
    for i := 1 to Dim do
    begin
      Write(EqNames[i].PadRight(12));
      Write('[ ');
      for VIdx := 1 to Dim do
      begin
        Write(Format('%12.6f', [A[i, VIdx]]));
        if VIdx < Dim then
          Write(', ');
      end;
      Writeln(' ] = [ ', Format('%12.6f', [B[i]]), ' ]');
    end;
    Writeln;
  end;

  // 4. Solve the system LinEq(A, B, Lb, Ub, Det)
  LinEq(A, B, 1, Dim, Det);

  if MathErr = MatOk then
  begin
    Success := True;

    // Fill output node voltages (ground is always 0.0)
    NodeVoltages.Add('0', 0.0);
    NodeVoltages.Add('GND', 0.0);
    for NodeName in FNodeMap.Keys do
    begin
      i := FNodeMap[NodeName];
      if i > 0 then
      begin
        if not NodeVoltages.ContainsKey(NodeName) then
          NodeVoltages.Add(NodeName, B[i]);
      end;
    end;

    // Fill output component currents
    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if (Comp is TVoltageSource) or (Comp is TInductor) then
      begin
        Inc(VIdx);
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, B[VIdx]));
      end
      else
      begin
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, 0.0));
      end;
    end;
  end;
end;

procedure TCircuit.SolveTransient(const ACsvFilename: string; out Success: Boolean; AShowMatrix: Boolean = False);
var
  NActiveNodes, Dim: Integer;
  A: TMatrix;
  B: TVector;
  Det: Float;
  i, VIdx: Integer;
  Comp: TComponent;
  NodeName: string;
  t, h: Double;
  fs: TFormatSettings;
  CsvFile: TextFile;
  NodeVoltages: TDictionary<string, Double>;
  ComponentCurrents: TDictionary<string, Double>;
  KeysList: TStringList;
  HeaderStr, DataStr: string;
begin
  Success := False;
  BuildNodeMap;

  NActiveNodes := FNodes.Count;
  Dim := NActiveNodes + FVSourceCount;
  if Dim = 0 then
  begin
    Success := True;
    Exit;
  end;

  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';

  // 1. Run DC Operating Point at t = 0 to find initial conditions
  DimMatrix(A, Dim, Dim);
  DimVector(B, Dim);
  
  // Clear matrix and vector
  for i := 0 to Dim do B[i] := 0.0;
  for i := 0 to Dim do
    for VIdx := 0 to Dim do
      A[i, VIdx] := 0.0;
      
  // Stamp all components at t = 0, h = 0
  VIdx := NActiveNodes;
  for Comp in FComponents do
  begin
    // Initialize default values for source functions if any
    if Comp is TVoltageSource then
    begin
      if TVoltageSource(Comp).SourceFunc <> nil then
        TVoltageSource(Comp).SourceFunc.InitializeDefaults(FTStop);
    end
    else if Comp is TCurrentSource then
    begin
      if TCurrentSource(Comp).SourceFunc <> nil then
        TCurrentSource(Comp).SourceFunc.InitializeDefaults(FTStop);
    end;

    if (Comp is TVoltageSource) or (Comp is TInductor) then
    begin
      Inc(VIdx);
      Comp.Stamp(A, B, FNodeMap, VIdx, 0.0, 0.0);
    end
    else
    begin
      Comp.Stamp(A, B, FNodeMap, 0, 0.0, 0.0);
    end;
  end;

  // Solve the DC operating point
  if AShowMatrix then
  begin
    Writeln;
    Writeln('--- Systemgleichungen (DC-Arbeitspunkt t=0) ---');
    for i := 1 to Dim do
    begin
      Write('[ ');
      for VIdx := 1 to Dim do
        Write(Format('%12.6f', [A[i, VIdx]]), ' ');
      Writeln(' ] = [ ', Format('%12.6f', [B[i]]), ' ]');
    end;
  end;

  LinEq(A, B, 1, Dim, Det);

  if AShowMatrix then
  begin
    Writeln('--- Loesungsvektor (DC-Arbeitspunkt t=0) ---');
    for i := 1 to Dim do
      Writeln(Format('X[%d] = %12.6f', [i, B[i]]));
  end;

  if MathErr <> MatOk then
  begin
    Writeln('Fehler: DC-Arbeitspunkt fuer Transientenanalyse konnte nicht berechnet werden (Matrix singulaer?).');
    Exit;
  end;

  // Store the DC results in NodeVoltages dictionary to initialize L/C states
  NodeVoltages := TDictionary<string, Double>.Create;
  ComponentCurrents := TDictionary<string, Double>.Create;
  try
    NodeVoltages.Add('0', 0.0);
    NodeVoltages.Add('GND', 0.0);
    for NodeName in FNodeMap.Keys do
    begin
      i := FNodeMap[NodeName];
      if i > 0 then
        NodeVoltages.Add(NodeName, B[i]);
    end;

    // Retrieve branch currents from DC solution to initialize L/C states
    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if (Comp is TVoltageSource) or (Comp is TInductor) then
      begin
        Inc(VIdx);
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, B[VIdx]));
      end
      else
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, 0.0));
    end;

    // Initialize capacitor voltages and inductor currents
    for Comp in FComponents do
    begin
      if Comp is TCapacitor then
        TCapacitor(Comp).VC := NodeVoltages[Comp.Node1] - NodeVoltages[Comp.Node2]
      else if Comp is TInductor then
        TInductor(Comp).IL := ComponentCurrents[Comp.Name];
    end;
  finally
    NodeVoltages.Free;
    ComponentCurrents.Free;
  end;

  // 2. Open CSV file for writing
  try
    AssignFile(CsvFile, ACsvFilename);
    Rewrite(CsvFile);
  except
    on E: Exception do
    begin
      Writeln('Fehler: Kann CSV-Datei nicht oeffnen: ', E.Message);
      Exit;
    end;
  end;

  // 3. Write CSV Header
  // The header lists: Time, V(node1), V(node2), ..., I(comp1), I(comp2), ...
  HeaderStr := 'Time';
  
  // Sort node names to make column order predictable
  KeysList := TStringList.Create;
  try
    for NodeName in FNodes do
      KeysList.Add(NodeName);
    KeysList.Sort;
    for i := 0 to KeysList.Count - 1 do
      HeaderStr := HeaderStr + ',' + 'V(' + KeysList[i] + ')';
      
    // Sort component names
    KeysList.Clear;
    for Comp in FComponents do
      KeysList.Add(Comp.Name);
    KeysList.Sort;
    for i := 0 to KeysList.Count - 1 do
      HeaderStr := HeaderStr + ',' + 'I(' + KeysList[i] + ')';
      
    Writeln(CsvFile, HeaderStr);
  finally
    KeysList.Free;
  end;

  // 4. Write initial state (t = 0) to CSV
  // We re-evaluate all voltages and currents from the DC solution
  NodeVoltages := TDictionary<string, Double>.Create;
  ComponentCurrents := TDictionary<string, Double>.Create;
  try
    NodeVoltages.Add('0', 0.0);
    NodeVoltages.Add('GND', 0.0);
    for NodeName in FNodeMap.Keys do
    begin
      i := FNodeMap[NodeName];
      if i > 0 then
        NodeVoltages.Add(NodeName, B[i]);
    end;

    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if (Comp is TVoltageSource) or (Comp is TInductor) then
      begin
        Inc(VIdx);
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, B[VIdx]));
      end
      else
        ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, 0.0));
    end;

    // Construct data string
    DataStr := FloatToStr(0.0, fs);
    
    // Node voltages in sorted order
    KeysList := TStringList.Create;
    try
      for NodeName in FNodes do
        KeysList.Add(NodeName);
      KeysList.Sort;
      for i := 0 to KeysList.Count - 1 do
        DataStr := DataStr + ',' + FloatToStr(NodeVoltages[KeysList[i]], fs);
        
      // Component currents in sorted order
      KeysList.Clear;
      for Comp in FComponents do
        KeysList.Add(Comp.Name);
      KeysList.Sort;
      for i := 0 to KeysList.Count - 1 do
        DataStr := DataStr + ',' + FloatToStr(ComponentCurrents[KeysList[i]], fs);
        
      Writeln(CsvFile, DataStr);
    finally
      KeysList.Free;
    end;
  finally
    NodeVoltages.Free;
    ComponentCurrents.Free;
  end;

  // 5. Time Stepping Loop
  t := FTStart;
  h := FTStep;
  
  while t < FTStop - 1e-15 do
  begin
    t := t + h;
    
    // Clear matrix and vector for current time step
    for i := 0 to Dim do B[i] := 0.0;
    for i := 0 to Dim do
      for VIdx := 0 to Dim do
        A[i, VIdx] := 0.0;
        
    // Stamp all components at time t and step h
    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if (Comp is TVoltageSource) or (Comp is TInductor) then
      begin
        Inc(VIdx);
        Comp.Stamp(A, B, FNodeMap, VIdx, t, h);
      end
      else
      begin
        Comp.Stamp(A, B, FNodeMap, 0, t, h);
      end;
    end;

    // Solve for current time step
    if AShowMatrix then
    begin
      Writeln;
      Writeln(Format('--- Systemgleichungen (t=%g h=%g) ---', [t, h]));
      for i := 1 to Dim do
      begin
        Write('[ ');
        for VIdx := 1 to Dim do
          Write(Format('%12.6f', [A[i, VIdx]]), ' ');
        Writeln(' ] = [ ', Format('%12.6f', [B[i]]), ' ]');
      end;
    end;

    LinEq(A, B, 1, Dim, Det);

    if AShowMatrix then
    begin
      Writeln(Format('--- Loesungsvektor (t=%g h=%g) ---', [t, h]));
      for i := 1 to Dim do
        Writeln(Format('X[%d] = %12.6f', [i, B[i]]));
    end;

    if MathErr <> MatOk then
    begin
      Writeln(Format('Fehler: Transientenanalyse konnte bei t = %g s nicht geloest werden (singulaere Matrix?).', [t]));
      CloseFile(CsvFile);
      Exit;
    end;

    // Retrieve new node voltages and component currents
    NodeVoltages := TDictionary<string, Double>.Create;
    ComponentCurrents := TDictionary<string, Double>.Create;
    try
      NodeVoltages.Add('0', 0.0);
      NodeVoltages.Add('GND', 0.0);
      for NodeName in FNodeMap.Keys do
      begin
        i := FNodeMap[NodeName];
        if i > 0 then
          NodeVoltages.Add(NodeName, B[i]);
      end;

      // Update states of capacitors and inductors for the next step!
      for Comp in FComponents do
      begin
        if Comp is TCapacitor then
        begin
          TCapacitor(Comp).IC := (TCapacitor(Comp).Value / h) * ((NodeVoltages[Comp.Node1] - NodeVoltages[Comp.Node2]) - TCapacitor(Comp).VC);
        end;
      end;

      VIdx := NActiveNodes;
      for Comp in FComponents do
      begin
        if (Comp is TVoltageSource) or (Comp is TInductor) then
        begin
          Inc(VIdx);
          ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, B[VIdx]));
        end
        else
          ComponentCurrents.Add(Comp.Name, Comp.GetCurrent(NodeVoltages, 0.0));
      end;

      // Now update the states VC and IL
      for Comp in FComponents do
      begin
        if Comp is TCapacitor then
          TCapacitor(Comp).VC := NodeVoltages[Comp.Node1] - NodeVoltages[Comp.Node2]
        else if Comp is TInductor then
          TInductor(Comp).IL := ComponentCurrents[Comp.Name];
      end;

      // Write time step results to CSV file
      DataStr := FloatToStr(t, fs);
      
      // Node voltages in sorted order
      KeysList := TStringList.Create;
      try
        for NodeName in FNodes do
          KeysList.Add(NodeName);
        KeysList.Sort;
        for i := 0 to KeysList.Count - 1 do
          DataStr := DataStr + ',' + FloatToStr(NodeVoltages[KeysList[i]], fs);
          
        // Component currents in sorted order
        KeysList.Clear;
        for Comp in FComponents do
          KeysList.Add(Comp.Name);
        KeysList.Sort;
        for i := 0 to KeysList.Count - 1 do
          DataStr := DataStr + ',' + FloatToStr(ComponentCurrents[KeysList[i]], fs);
          
        Writeln(CsvFile, DataStr);
      finally
        KeysList.Free;
      end;
    finally
      NodeVoltages.Free;
      ComponentCurrents.Free;
    end;
  end;

  CloseFile(CsvFile);
  Success := True;
end;

end.
