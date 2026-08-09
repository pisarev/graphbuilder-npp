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

function ShareState(const Text: string): string;
function WithoutEditor(const Text: string): string;

implementation

uses SysUtils, base64, fpjson, jsonparser;

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
    DropEditor(Data);
    Result := Data.AsJSON;
  finally
    Data.Free;
  end;
end;

end.
