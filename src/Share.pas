{ ************************************************************************** }
{                                                                            }
{ Share                                                                      }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit Share;

interface

type
  TClipboardKind = (ckShare, ckState, ckPlain, ckBroken);

function ShareState(const Text: string): string;
function ClipboardKind(const Text: string): TClipboardKind;

implementation

uses System.SysUtils, System.NetEncoding, System.JSON;

const
  ShareMark = '#s=1.';

function ShareState(const Text: string): string;
var
  Code: string;
  At, I: Integer;
  Data: TJSONValue;
begin
  At := Pos(ShareMark, Text);
  if At = 0 then Exit('');
  Code := Trim(Copy(Text, At + Length(ShareMark), MaxInt));
  for I := 1 to Length(Code) do
    case Code[I] of
      '-': Code[I] := '+';
      '_': Code[I] := '/';
    end;
  while Length(Code) mod 4 <> 0 do Code := Code + '=';
  try
    Result := TNetEncoding.Base64.Decode(Code);
  except
    Result := '';
  end;
  if Result <> '' then
  begin
    Data := TJSONObject.ParseJSONValue(Result);
    if Data = nil then
      Result := ''
    else
      Data.Free;
  end;
end;

function ClipboardKind(const Text: string): TClipboardKind;
var
  Data: TJSONValue;
begin
  if ShareState(Text) <> '' then Exit(ckShare);
  if Pos(ShareMark, Text) > 0 then Exit(ckBroken);
  Result := ckPlain;
  Data := TJSONObject.ParseJSONValue(Text);
  if Data = nil then Exit;
  try
    if not (Data is TJSONObject) then Exit;
    if TJSONObject(Data).GetValue('formulas') is TJSONArray then Result := ckState;
  finally
    Data.Free;
  end;
end;

end.
