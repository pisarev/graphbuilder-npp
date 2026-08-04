{ ************************************************************************** }
{                                                                            }
{ GraphBuilderLaz                                                            }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }
library GraphBuilderLaz;

{$MODE Delphi}

uses
  Interfaces, Forms,
  Windows,
  NotepadPP.Types,
  uLazPlugin, uLazPanel;

procedure setInfo(Data: TNppData); cdecl;
begin
  Npp.SetInfo(Data);
end;

function getName: PWideChar; cdecl;
begin
  Result := Npp.NameForNpp;
end;

function getFuncsArray(Count: PInteger): PFuncItem; cdecl;
begin
  Count^ := Npp.FuncCount;
  Result := Npp.FuncItem[0];
end;

procedure beNotified(Notification: PSciNotification); cdecl;
begin
  Npp.BeNotified(Notification);
end;

function messageProc(Message: Cardinal; WParam: WPARAM; LParam: LPARAM): LRESULT; cdecl;
begin
  Result := Npp.MessageProc(Message, WParam, LParam);
end;

function isUnicode: BOOL; cdecl;
begin
  Result := True;
end;

exports
  setInfo,
  getName,
  getFuncsArray,
  beNotified,
  messageProc,
  isUnicode;

begin
  Application.Initialize;
end.
