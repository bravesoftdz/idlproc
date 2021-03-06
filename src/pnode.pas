unit pnode;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type                  
  TPNode = class;

  TNodeType = (
    ntDocument,                             // List of Extension, Include or definitions
    ntExtension,                            // %{ }% Extension as text
    ntLibrary,                              // library x {}
    ntInterface,                            // interface x {}
    ntIntfParents,                          // : a,b
    ntModule,

    ntTypeAlias,                            // typedef old new;
    ntEnum,                                 // typedef enum {} name;
    ntStruct,                               // typedef struct {} name;


    ntIdentifier,                           // Ident
    ntValueIID,                             //       
    ntValueNumber,                          //
    ntValueStr,                             //
    ntValueRef,                             //

    ntConst,
    ntProperty,
    ntMethod,
    ntField,

    ntParam,

    ntAttributes,                           // list of ntAttribute
    ntAttribute,                            // [a] or [a(b)]
    ntDirective,


    ntTemporary                             // used in parser, should never be in final result
  );

  TNodeList = specialize TFPGList<TPNode>;

  TPNode = class
  public
    nTyp: TNodeType;
    constructor Create(t: TNodeType);
    constructor CreateList(t: TNodeType);
    destructor Destroy; override;
  public
    // List-Type nodes
    Children: TNodeList;
    procedure Append(n: TPNode);
    procedure AppendList(n: TPNode);
  public
    // General
    Name: String;
    Attribs: TPNode;
  public
    // Interface
    Parent: TPNode;
  public
    // Const, Attribute
    Value: TPNode;
  public
    // Const, Property, Param
    Typ: TPNode;
    ReadOnly: boolean;
    Inoutspec: integer;
  public
    // Extension
    ExtCode: TStringList;
  public
    // Value
    GUID: TGuid;
  public
    // Attributes
    Attributes: TStringList;
    function AttrValue(const a: String): TPNode;
  public
    // typedef, struct member
    procedure SetArraySpec(Dimensions: TPNode);
  end;

const
  PARAM_IN       = 1;
  PARAM_OUT      = 2;
  PARAM_INOUT    = 3;
  PARAM_DEFAULT  = 0;

procedure WritePNodeTree(N:TPNode);
procedure ReleaseAllNodes;

implementation

var
  NodeGC: TNodeList;

procedure WriteTPNode(N: TPNode; Level: integer);
var
  nc: TPNode;
begin
  Write('':Level*2);
  if Assigned(N) then begin
    Write(N.nTyp);
    if Assigned(N.Attributes) then
      Write(' [',N.Attributes.CommaText,']');
    case N.nTyp of
      ntExtension: begin
        Write(' ', N.Name);
      end;
      ntConst: begin
        if Assigned(N.Typ) then
          Write(' ', N.Name, ': ', N.Typ.Name, ' = ', N.Value.Name)
        else
          Write(' ', N.Name);
      end;     
      ntProperty: begin
        Write(' ', N.Name, ': ', N.Typ.Name);
        if N.ReadOnly then
          Write(' RO');
      end;
      ntMethod: begin
        Write(' method ', N.Name, '()');
        if Assigned(N.Typ) then
          Write(': ',N.Typ.Name);
      end; 
      ntParam: begin
        WriteLn;
        Write('':Level*2, ' ', N.Name, ': ', N.Typ.Name);
      end;
      ntTypeAlias: begin      
        WriteLn;
        if N.Typ.nTyp = ntMethod then
          WriteTPNode(N.Typ, Level + 1);
      end;
    end;
    WriteLn();
    if Assigned(N.Children) then
      for nc in N.Children do
        WriteTPNode(nc, Level+1);
  end else
    WriteLn('<nil>');
end;

procedure WritePNodeTree(N: TPNode);
begin
  WriteTPNode(N, 0);
end;

procedure ReleaseAllNodes;
begin
  while NodeGC.Count > 0 do begin
    NodeGC.Last.Free;
  end;
end;

{ TPNode }

constructor TPNode.Create(t: TNodeType);
begin
  inherited Create;  
  nTyp:= t;
  NodeGC.Add(Self);
end;

constructor TPNode.CreateList(t: TNodeType);
begin
  Create(t);
  Children:= TNodeList.Create;
end;

destructor TPNode.Destroy;
begin
  NodeGC.Remove(Self);
  FreeAndNil(Children);
  FreeAndNil(ExtCode);
  FreeAndNil(Attributes);
  inherited Destroy;
end;

procedure TPNode.Append(n: TPNode);
begin
  Assert(Assigned(Children), 'Append called on non-list node');
  Children.Add(n);
end;

procedure TPNode.AppendList(n: TPNode);
var
  nc: TPNode;
begin
  Assert(Assigned(Children), 'AppendList called on non-list node');
  Assert(Assigned(n.Children), 'AppendList called on non-list other node');
  for nc in n.Children do
    Children.Add(nc);
end;

procedure TPNode.SetArraySpec(Dimensions: TPNode);
var
  adim: string;
  d: TPNode;
begin       
  Assert(Dimensions.nTyp = ntIdentifier, 'SetArraySpec called on non-ident node');
  if Assigned(Dimensions.Children) then begin
    adim:= '';
    for d in Dimensions.Children do begin;
      adim:= format('%s[%s]',[adim, d.Name])
    end;

    Name:= Name + ' ' + adim;
  end;
end;

function TPNode.AttrValue(const a: String): TPNode;
var
  i: Integer;
begin
  Result:= nil;
  i:= Attributes.IndexOfName(a);
  if i >= 0 then
    Result:= TPNode(Attributes.Objects[i]);
end;

initialization
  NodeGC:= TNodeList.Create;
finalization
  ReleaseAllNodes;
  FreeAndNil(NodeGC);
end.

