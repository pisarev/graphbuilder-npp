{ ************************************************************************** }
{                                                                            }
{ uShare                                                                     }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit uShare;

{$MODE Delphi}

interface

const
  PluginVersion = '1.3.5';

type
  TClipboardKind = (ckShare, ckState, ckPlain, ckBroken);

type
  TTextWidth = function(const Text: string): Integer of object;

function FitTitle(const Base, OpenKeys, GrabKeys: string; const Room: Integer;
  const Measure: TTextWidth): string;

function ShareState(const Text: string): string;
function WithoutEditor(const Text: string): string;
function ClipboardKind(const Text: string): TClipboardKind;

implementation

uses SysUtils, base64, fpjson, jsonparser;

function FitTitle(const Base, OpenKeys, GrabKeys: string; const Room: Integer;
  const Measure: TTextWidth): string;
var
  Ladder: array[0..4] of string;
  I: Integer;
begin
  Ladder[0] := Base + '  (' + OpenKeys + ', grab ' + GrabKeys + ')';
  Ladder[1] := Base + '  (' + OpenKeys + ', ' + GrabKeys + ')';
  Ladder[2] := Base + '  (' + GrabKeys + ')';
  Ladder[3] := Base + '  (' + OpenKeys + ')';
  Ladder[4] := Base;
  for I := Low(Ladder) to High(Ladder) do
  begin
    if (Pos('()', Ladder[I]) > 0) or (Pos('(, ', Ladder[I]) > 0) or (Pos(', )', Ladder[I]) > 0) then
      Continue;
    if (Room <= 0) or not Assigned(Measure) then Exit(Ladder[I]);
    if Measure(Ladder[I]) <= Room then Exit(Ladder[I]);
  end;
  Result := Base;
end;

const
  ShareMark = '#s=1.';

function ShareState(const Text: string): string;
var
  Code: string;
  At, I: Integer;
begin
  Result := '';
  At := Pos(ShareMark, Text);
  if At = 0 then Exit;
  Code := Trim(Copy(Text, At + Length(ShareMark), MaxInt));
  for I := 1 to Length(Code) do
    case Code[I] of
      '-': Code[I] := '+';
      '_': Code[I] := '/';
    end;
  while Length(Code) mod 4 <> 0 do Code := Code + '=';
  try
    Result := DecodeStringBase64(Code);
  except
    Result := '';
  end;
  if Result <> '' then
    try
      with GetJSON(Result) do Free;
    except
      Result := '';
    end;
end;

procedure DropEditor(const Data: TJSONData);
var
  I: Integer;
  Obj: TJSONObject;
begin
  if Data is TJSONObject then
  begin
    Obj := TJSONObject(Data);
    I := Obj.IndexOfName('editor');
    if I >= 0 then Obj.Delete(I);
    for I := 0 to Obj.Count - 1 do
      DropEditor(Obj.Items[I]);
  end
  else if Data is TJSONArray then
    for I := 0 to TJSONArray(Data).Count - 1 do
      DropEditor(TJSONArray(Data).Items[I]);
end;

function WithoutEditor(const Text: string): string;
var
  Data: TJSONData;
begin
  Result := Text;
  Data := nil;
  try
    try
      Data := GetJSON(Text);
    except
      Exit;
    end;
    if not Assigned(Data) then Exit;
    DropEditor(Data);
    Result := Data.AsJSON;
  finally
    Data.Free;
  end;
end;

function ClipboardKind(const Text: string): TClipboardKind;
var
  Data: TJSONData;
  List: TJSONData;
begin
  if ShareState(Text) <> '' then Exit(ckShare);
  if Pos(ShareMark, Text) > 0 then Exit(ckBroken);
  Result := ckPlain;
  Data := nil;
  try
    try
      Data := GetJSON(Text);
    except
      Exit;
    end;
    if not (Data is TJSONObject) then Exit;
    List := TJSONObject(Data).Find('formulas');
    if List is TJSONArray then Result := ckState;
  finally
    Data.Free;
  end;
end;

end.
