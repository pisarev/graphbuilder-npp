{ ************************************************************************** }
{                                                                            }
{ ClipboardMonitor                                                           }
{                                                                            }
{ Copyright © 2025 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit ClipboardMonitor;

{$B-}
{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Windows, Messages, SysUtils, Classes, Graphics, Controls;
  {$ELSE}
  {$IFDEF DELPHI_XE7}
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls;
  {$ELSE}
  Windows, Messages, SysUtils, Classes, Graphics, Controls;
  {$ENDIF}
  {$ENDIF}

type
  TClipboardMonitor = class
  private
    FHandle: THandle;
    FOnChange: TNotifyEvent;
    FNextChain: THandle;
    FUpdateCount: Integer;
  protected
    procedure WindowMethod(var Message: TMessage); virtual;
    property NextChain: THandle read FNextChain write FNextChain;
    property Handle: THandle read FHandle write FHandle;
    property UpdateCount: Integer read FUpdateCount write FUpdateCount;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure BeginUpdate; virtual;
    procedure EndUpdate; virtual;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

function CopyToClipboard(const Handle: THandle; const S: string; const AttemptCount: Integer = 4): Boolean;
function PasteFromClipboard(const Handle: THandle; out S: string; const AttemptCount: Integer = 4): Boolean;

implementation

function CopyToClipboard(const Handle: THandle; const S: string; const AttemptCount: Integer): Boolean;
const
  IdleTime = 100;
var
  I, J: Integer;
  hData: HGlobal;
  pData: Pointer;
begin
  for I := 0 to AttemptCount - 1 do
    try
      if OpenClipboard(Handle) then
        try
          J := (Length(S) + 1) * SizeOf(Char);
          hData := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, J);
          try
            pData := GlobalLock(hData);
            try
              Move(PChar(S)^, pData^, J);
              EmptyClipboard;
              {$IFDEF UNICODE}
              SetClipboardData(CF_UNICODETEXT, hData);
              {$ELSE}
              SetClipboardData(CF_TEXT, hData);
              {$ENDIF}
              Result := True;
              Exit;
            finally
              GlobalUnlock(hData);
            end;
          except
            GlobalFree(hData);
            raise;
          end;
        finally
          CloseClipboard;
        end;
      Sleep(IdleTime);
    except
      Sleep(IdleTime);
    end;
  Result := False;
end;

function PasteFromClipboard(const Handle: THandle; out S: string; const AttemptCount: Integer): Boolean;
const
  IdleTime = 100;
var
  I: Integer;
  hData: HGlobal;
begin
  for I := 0 to AttemptCount - 1 do
    try
      if OpenClipboard(Handle) then
        try
          {$IFDEF UNICODE}
          hData := GetClipboardData(CF_UNICODETEXT);
          {$ELSE}
          hData := GetClipboardData(CF_TEXT);
          {$ENDIF}
          S := PChar(GlobalLock(hData));
          GlobalUnlock(hData);
        finally
          CloseClipboard;
        end;
      Result := True;
      Exit;
    except
      Sleep(IdleTime);
    end;
  Result := False;
end;

{ TClipboardMonitor }

procedure TClipboardMonitor.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

constructor TClipboardMonitor.Create;
begin
  inherited;
  FHandle := AllocateHWnd(WindowMethod);
  FNextChain := SetClipboardViewer(FHandle);
end;

destructor TClipboardMonitor.Destroy;
begin
  ChangeClipboardChain(FHandle, FNextChain);
  DeallocateHWnd(FHandle);
  inherited;
end;

procedure TClipboardMonitor.EndUpdate;
begin
  Dec(FUpdateCount);
end;

procedure TClipboardMonitor.WindowMethod(var Message: TMessage);
begin
  case Message.Msg of
    WM_DRAWCLIPBOARD:
      begin
        if Assigned(FOnChange) and (FUpdateCount = 0) then FOnChange(Self);
        Message.Result := 0;
      end;
    WM_CHANGECBCHAIN:
      begin
        if NativeUInt(Message.wParam) = FNextChain then
          FNextChain := Message.lParam
        else
          if FNextChain <> 0 then
            SendMessage(FNextChain, Message.Msg, Message.wParam, Message.lParam);
        Message.Result := 0;
      end;
  else
    Message.Result := DefWindowProc(FHandle, Message.Msg, Message.wParam, Message.lParam);
  end;
end;

end.
