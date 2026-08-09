unit uComponents;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections, utypes;

type
  { Base class for all components }
  TComponent = class
  public
    Name: string;
    Node1: string; // Positive node / Node 1
    Node2: string; // Negative node / Node 2
    Value: Double;
    constructor Create(const AName, ANode1, ANode2: string; AValue: Double);
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); virtual; abstract;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; virtual; abstract;
  end;

  { Resistor component }
  TResistor = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

  { DC Voltage Source component }
  TVoltageSource = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

  { DC Current Source component }
  TCurrentSource = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

  { Capacitor component }
  TCapacitor = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

  { Inductor component }
  TInductor = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

implementation

{ Helper to add to 2D matrix with 1-based coordinates }
procedure AddToMatrix(var A: TMatrix; Row, Col: Integer; Value: Double);
begin
  if (Row <= 0) or (Col <= 0) then Exit; // Ignore ground node '0'
  A[Row, Col] := A[Row, Col] + Value;
end;

{ Helper to add to vector with 1-based coordinates }
procedure AddToVector(var B: TVector; Row: Integer; Value: Double);
begin
  if Row <= 0 then Exit; // Ignore ground node '0'
  B[Row] := B[Row] + Value;
end;

{ TComponent }

constructor TComponent.Create(const AName, ANode1, ANode2: string; AValue: Double);
begin
  Name := UpperCase(AName);
  Node1 := UpperCase(ANode1);
  Node2 := UpperCase(ANode2);
  Value := AValue;
end;

{ TResistor }

procedure TResistor.Stamp(var A: TMatrix; var B: TVector;
                          NodeMap: TDictionary<string, Integer>;
                          VSourceIdx: Integer);
var
  n1, n2: Integer;
  g: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];
  if Value <> 0 then
    g := 1.0 / Value
  else
    g := 1.0E12; // Extremely large conductance for 0 Ohm to avoid singularity

  AddToMatrix(A, n1, n1,  g);
  AddToMatrix(A, n1, n2, -g);
  AddToMatrix(A, n2, n1, -g);
  AddToMatrix(A, n2, n2,  g);
end;

{ TVoltageSource }

procedure TVoltageSource.Stamp(var A: TMatrix; var B: TVector;
                                NodeMap: TDictionary<string, Integer>;
                                VSourceIdx: Integer);
var
  n1, n2: Integer;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];

  AddToMatrix(A, n1, VSourceIdx,  1.0);
  AddToMatrix(A, n2, VSourceIdx, -1.0);
  AddToMatrix(A, VSourceIdx, n1,  1.0);
  AddToMatrix(A, VSourceIdx, n2, -1.0);

  AddToVector(B, VSourceIdx, Value);
end;

{ TCurrentSource }

procedure TCurrentSource.Stamp(var A: TMatrix; var B: TVector;
                                NodeMap: TDictionary<string, Integer>;
                                VSourceIdx: Integer);
var
  n1, n2: Integer;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];

  // Current flows from Node1 to Node2
  AddToVector(B, n1, -Value);
  AddToVector(B, n2,  Value);
end;

function TResistor.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                              VSourceCurrent: Double): Double;
var
  v1, v2: Double;
begin
  if not NodeVoltages.TryGetValue(Node1, v1) then v1 := 0.0;
  if not NodeVoltages.TryGetValue(Node2, v2) then v2 := 0.0;
  if Value <> 0 then
    Result := (v1 - v2) / Value
  else
    Result := (v1 - v2) * 1.0E12;
end;

function TVoltageSource.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                                   VSourceCurrent: Double): Double;
begin
  Result := VSourceCurrent;
end;

function TCurrentSource.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                                   VSourceCurrent: Double): Double;
begin
  Result := Value;
end;

{ TCapacitor }

procedure TCapacitor.Stamp(var A: TMatrix; var B: TVector;
                            NodeMap: TDictionary<string, Integer>;
                            VSourceIdx: Integer);
var
  n1, n2: Integer;
  g: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];
  g := 1.0E-12; // 1 pS conductance for open circuit in DC

  AddToMatrix(A, n1, n1,  g);
  AddToMatrix(A, n1, n2, -g);
  AddToMatrix(A, n2, n1, -g);
  AddToMatrix(A, n2, n2,  g);
end;

function TCapacitor.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                               VSourceCurrent: Double): Double;
begin
  Result := 0.0;
end;

{ TInductor }

procedure TInductor.Stamp(var A: TMatrix; var B: TVector;
                           NodeMap: TDictionary<string, Integer>;
                           VSourceIdx: Integer);
var
  n1, n2: Integer;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];

  AddToMatrix(A, n1, VSourceIdx,  1.0);
  AddToMatrix(A, n2, VSourceIdx, -1.0);
  AddToMatrix(A, VSourceIdx, n1,  1.0);
  AddToMatrix(A, VSourceIdx, n2, -1.0);

  AddToVector(B, VSourceIdx, 0.0); // 0V constraint for short circuit
end;

function TInductor.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                              VSourceCurrent: Double): Double;
begin
  Result := VSourceCurrent;
end;

end.
