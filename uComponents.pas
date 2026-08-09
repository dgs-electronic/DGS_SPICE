unit uComponents;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Generics.Collections, utypes;

type
  TFunctionType = (ftNone, ftPulse, ftSine, ftPwl);

  TPwlPoint = record
    Time: Double;
    Value: Double;
  end;

  TSourceFunction = class
  private
    FFuncType: TFunctionType;
  public
    V1, V2, TD, TR, TF, PW, PER, Ncycles: Double; // Pulse
    VO, VA, FREQ, THETA, PHI: Double; // Sine
    PwlPoints: array of TPwlPoint; // PWL
    
    constructor Create;
    procedure InitializeDefaults(TStop: Double);
    function Evaluate(t: Double): Double;
    property FuncType: TFunctionType read FFuncType write FFuncType;
  end;

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
                    VSourceIdx: Integer; t: Double; h: Double); virtual; abstract;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; virtual; abstract;
  end;

  { Resistor component }
  TResistor = class(TComponent)
  public
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer; t: Double; h: Double); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
  end;

  { DC Voltage Source component }
  TVoltageSource = class(TComponent)
  private
    FSourceFunc: TSourceFunction;
  public
    constructor Create(const AName, ANode1, ANode2: string; AValue: Double; ASourceFunc: TSourceFunction = nil);
    destructor Destroy; override;
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer; t: Double; h: Double); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
    function GetSourceValue(t, h: Double): Double;
    property SourceFunc: TSourceFunction read FSourceFunc write FSourceFunc;
  end;

  { DC Current Source component }
  TCurrentSource = class(TComponent)
  private
    FSourceFunc: TSourceFunction;
    FIC: Double;
  public
    constructor Create(const AName, ANode1, ANode2: string; AValue: Double; ASourceFunc: TSourceFunction = nil);
    destructor Destroy; override;
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer; t: Double; h: Double); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
    function GetSourceValue(t, h: Double): Double;
    property SourceFunc: TSourceFunction read FSourceFunc write FSourceFunc;
  end;

  { Capacitor component }
  TCapacitor = class(TComponent)
  private
    FVC: Double;
    FIC: Double;
  public
    constructor Create(const AName, ANode1, ANode2: string; AValue: Double);
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer; t: Double; h: Double); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
    property VC: Double read FVC write FVC;
    property IC: Double read FIC write FIC;
  end;

  { Inductor component }
  TInductor = class(TComponent)
  private
    FIL: Double;
  public
    constructor Create(const AName, ANode1, ANode2: string; AValue: Double);
    procedure Stamp(var A: TMatrix; var B: TVector;
                    NodeMap: TDictionary<string, Integer>;
                    VSourceIdx: Integer; t: Double; h: Double); override;
    function GetCurrent(NodeVoltages: TDictionary<string, Double>;
                        VSourceCurrent: Double): Double; override;
    property IL: Double read FIL write FIL;
  end;

implementation

{ TSourceFunction }

constructor TSourceFunction.Create;
begin
  inherited Create;
  FFuncType := ftNone;
  V1 := 0.0; V2 := 0.0; TD := 0.0; TR := 0.0; TF := 0.0; PW := -1.0; PER := -1.0; Ncycles := 0.0;
  VO := 0.0; VA := 0.0; FREQ := 0.0; THETA := 0.0; PHI := 0.0;
  PwlPoints := nil;
end;

procedure TSourceFunction.InitializeDefaults(TStop: Double);
begin
  if FFuncType = ftPulse then
  begin
    if PW < 0.0 then PW := TStop;
    if PER < 0.0 then PER := TStop;
  end
  else if FFuncType = ftSine then
  begin
    if FREQ <= 0.0 then
    begin
      if TStop > 0.0 then
        FREQ := 1.0 / TStop
      else
        FREQ := 1.0;
    end;
  end;
end;

function TSourceFunction.Evaluate(t: Double): Double;
var
  tLocal: Double;
  Cycle: Int64;
  PhaseRad: Double;
  i: Integer;
  t1, t2, val1, val2: Double;
begin
  case FFuncType of
    ftNone:
      Result := 0.0;
      
    ftPulse:
      begin
        if t < TD then
          Exit(V1);

        tLocal := t - TD;
        
        if PER > 0.0 then
        begin
          Cycle := Trunc(tLocal / PER);
          if (Ncycles > 0.0) and (Cycle >= Ncycles) then
            Exit(V1);
          tLocal := tLocal - Cycle * PER;
        end;

        t1 := TR; if t1 <= 0.0 then t1 := 1.0E-12;
        t2 := TF; if t2 <= 0.0 then t2 := 1.0E-12;

        if tLocal < t1 then
          Result := V1 + (V2 - V1) * (tLocal / t1)
        else if tLocal < t1 + PW then
          Result := V2
        else if tLocal < t1 + PW + t2 then
          Result := V2 - (V2 - V1) * ((tLocal - t1 - PW) / t2)
        else
          Result := V1;
      end;
      
    ftSine:
      begin
        PhaseRad := PHI * Pi / 180.0;
        if t < TD then
          Exit(VO + VA * Sin(PhaseRad));

        tLocal := t - TD;
        if (Ncycles > 0.0) and (tLocal * FREQ >= Ncycles) then
          Exit(VO + VA * Sin(PhaseRad));

        Result := VO + VA * Exp(-THETA * tLocal) * Sin(2.0 * Pi * FREQ * tLocal + PhaseRad);
      end;
      
    ftPwl:
      begin
        if Length(PwlPoints) = 0 then
          Exit(0.0);
          
        if t <= PwlPoints[0].Time then
          Exit(PwlPoints[0].Value);
          
        if t >= PwlPoints[Length(PwlPoints) - 1].Time then
          Exit(PwlPoints[Length(PwlPoints) - 1].Value);
          
        for i := 0 to Length(PwlPoints) - 2 do
        begin
          if (t >= PwlPoints[i].Time) and (t < PwlPoints[i+1].Time) then
          begin
            t1 := PwlPoints[i].Time;
            t2 := PwlPoints[i+1].Time;
            val1 := PwlPoints[i].Value;
            val2 := PwlPoints[i+1].Value;
            if t2 - t1 <> 0.0 then
              Result := val1 + (val2 - val1) * ((t - t1) / (t2 - t1))
            else
              Result := val1;
            Exit;
          end;
        end;
        Result := PwlPoints[Length(PwlPoints) - 1].Value;
      end;
  else
    Result := 0.0;
  end;
end;

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
                          VSourceIdx: Integer; t: Double; h: Double);
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

{ TVoltageSource }

constructor TVoltageSource.Create(const AName, ANode1, ANode2: string; AValue: Double; ASourceFunc: TSourceFunction = nil);
begin
  inherited Create(AName, ANode1, ANode2, AValue);
  FSourceFunc := ASourceFunc;
end;

destructor TVoltageSource.Destroy;
begin
  if FSourceFunc <> nil then
    FSourceFunc.Free;
  inherited Destroy;
end;

function TVoltageSource.GetSourceValue(t, h: Double): Double;
begin
  if h = 0.0 then
    Result := Value
  else
  begin
    if (FSourceFunc <> nil) and (FSourceFunc.FuncType <> ftNone) then
      Result := FSourceFunc.Evaluate(t)
    else
      Result := Value;
  end;
end;

procedure TVoltageSource.Stamp(var A: TMatrix; var B: TVector;
                                NodeMap: TDictionary<string, Integer>;
                                VSourceIdx: Integer; t: Double; h: Double);
var
  n1, n2: Integer;
  valToStamp: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];
  valToStamp := GetSourceValue(t, h);

  AddToMatrix(A, n1, VSourceIdx,  1.0);
  AddToMatrix(A, n2, VSourceIdx, -1.0);
  AddToMatrix(A, VSourceIdx, n1,  1.0);
  AddToMatrix(A, VSourceIdx, n2, -1.0);

  AddToVector(B, VSourceIdx, valToStamp);
end;

function TVoltageSource.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                                   VSourceCurrent: Double): Double;
begin
  Result := VSourceCurrent;
end;

{ TCurrentSource }

constructor TCurrentSource.Create(const AName, ANode1, ANode2: string; AValue: Double; ASourceFunc: TSourceFunction = nil);
begin
  inherited Create(AName, ANode1, ANode2, AValue);
  FSourceFunc := ASourceFunc;
  FIC := 0.0;
end;

destructor TCurrentSource.Destroy;
begin
  if FSourceFunc <> nil then
    FSourceFunc.Free;
  inherited Destroy;
end;

function TCurrentSource.GetSourceValue(t, h: Double): Double;
begin
  if h = 0.0 then
    Result := Value
  else
  begin
    if (FSourceFunc <> nil) and (FSourceFunc.FuncType <> ftNone) then
      Result := FSourceFunc.Evaluate(t)
    else
      Result := Value;
  end;
end;

procedure TCurrentSource.Stamp(var A: TMatrix; var B: TVector;
                                NodeMap: TDictionary<string, Integer>;
                                VSourceIdx: Integer; t: Double; h: Double);
var
  n1, n2: Integer;
  valToStamp: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];
  valToStamp := GetSourceValue(t, h);
  FIC := valToStamp; // Save the evaluated current for GetCurrent

  // Current flows from Node1 to Node2
  AddToVector(B, n1, -valToStamp);
  AddToVector(B, n2,  valToStamp);
end;

function TCurrentSource.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                                   VSourceCurrent: Double): Double;
begin
  Result := FIC;
end;

{ TCapacitor }

constructor TCapacitor.Create(const AName, ANode1, ANode2: string; AValue: Double);
begin
  inherited Create(AName, ANode1, ANode2, AValue);
  FVC := 0.0;
  FIC := 0.0;
end;

procedure TCapacitor.Stamp(var A: TMatrix; var B: TVector;
                            NodeMap: TDictionary<string, Integer>;
                            VSourceIdx: Integer; t: Double; h: Double);
var
  n1, n2: Integer;
  Geq, Ieq: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];

  if h = 0.0 then
  begin
    Geq := 1.0E-12; // 1 pS conductance for open circuit in DC
    AddToMatrix(A, n1, n1,  Geq);
    AddToMatrix(A, n1, n2, -Geq);
    AddToMatrix(A, n2, n1, -Geq);
    AddToMatrix(A, n2, n2,  Geq);
  end
  else
  begin
    // Transient using Backward Euler
    Geq := Value / h;
    Ieq := (Value / h) * FVC;

    AddToMatrix(A, n1, n1,  Geq);
    AddToMatrix(A, n1, n2, -Geq);
    AddToMatrix(A, n2, n1, -Geq);
    AddToMatrix(A, n2, n2,  Geq);

    AddToVector(B, n1,  Ieq);
    AddToVector(B, n2, -Ieq);
  end;
end;

function TCapacitor.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                               VSourceCurrent: Double): Double;
begin
  Result := FIC;
end;

{ TInductor }

constructor TInductor.Create(const AName, ANode1, ANode2: string; AValue: Double);
begin
  inherited Create(AName, ANode1, ANode2, AValue);
  FIL := 0.0;
end;

procedure TInductor.Stamp(var A: TMatrix; var B: TVector;
                           NodeMap: TDictionary<string, Integer>;
                           VSourceIdx: Integer; t: Double; h: Double);
var
  n1, n2: Integer;
  Req, Veq: Double;
begin
  n1 := NodeMap[Node1];
  n2 := NodeMap[Node2];

  if h = 0.0 then
  begin
    // DC short circuit
    AddToMatrix(A, n1, VSourceIdx,  1.0);
    AddToMatrix(A, n2, VSourceIdx, -1.0);
    AddToMatrix(A, VSourceIdx, n1,  1.0);
    AddToMatrix(A, VSourceIdx, n2, -1.0);

    AddToVector(B, VSourceIdx, 0.0);
  end
  else
  begin
    // Transient using Backward Euler
    Req := Value / h;
    Veq := - (Value / h) * FIL;

    AddToMatrix(A, n1, VSourceIdx,  1.0);
    AddToMatrix(A, n2, VSourceIdx, -1.0);
    AddToMatrix(A, VSourceIdx, n1,  1.0);
    AddToMatrix(A, VSourceIdx, n2, -1.0);
    AddToMatrix(A, VSourceIdx, VSourceIdx, -Req);

    AddToVector(B, VSourceIdx, Veq);
  end;
end;

function TInductor.GetCurrent(NodeVoltages: TDictionary<string, Double>;
                              VSourceCurrent: Double): Double;
begin
  Result := VSourceCurrent;
end;

end.
