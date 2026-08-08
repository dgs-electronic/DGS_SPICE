unit uCircuit;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections, utypes, uErrors, ulineq, uComponents;

type
  { Main Circuit class }
  TCircuit = class
  private
    FComponents: TObjectList<TComponent>;
    FNodes: TList<string>;
    FNodeMap: TDictionary<string, Integer>;
    FVSourceCount: Integer;

    procedure RegisterNode(const ANode: string);
    procedure BuildNodeMap;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddComponent(AComp: TComponent);
    procedure Solve(out NodeVoltages: TDictionary<string, Double>;
                    out SourceCurrents: TDictionary<string, Double>;
                    out Success: Boolean);
    
    property Components: TObjectList<TComponent> read FComponents;
  end;

implementation

{ TCircuit }

constructor TCircuit.Create;
begin
  FComponents := TObjectList<TComponent>.Create(True);
  FNodes := TList<string>.Create;
  FNodeMap := TDictionary<string, Integer>.Create;
  FVSourceCount := 0;
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
    if Comp is TVoltageSource then
      Inc(FVSourceCount);
  end;
end;

procedure TCircuit.Solve(out NodeVoltages: TDictionary<string, Double>;
                         out SourceCurrents: TDictionary<string, Double>;
                         out Success: Boolean);
var
  NActiveNodes, Dim: Integer;
  A: TMatrix;
  B: TVector;
  Det: Float;
  i, VIdx: Integer;
  Comp: TComponent;
  NodeName: string;
begin
  Success := False;
  NodeVoltages := TDictionary<string, Double>.Create;
  SourceCurrents := TDictionary<string, Double>.Create;

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
    if Comp is TVoltageSource then
    begin
      Inc(VIdx);
      Comp.Stamp(A, B, FNodeMap, VIdx);
    end
    else
    begin
      Comp.Stamp(A, B, FNodeMap, 0);
    end;
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

    // Fill output source currents
    VIdx := NActiveNodes;
    for Comp in FComponents do
    begin
      if Comp is TVoltageSource then
      begin
        Inc(VIdx);
        SourceCurrents.Add(Comp.Name, B[VIdx]);
      end;
    end;
  end;
end;

end.
