{ ************************************************************************** }
{                                                                            }
{ NotepadPP.Forms                                                            }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit NotepadPP.Forms;

interface

uses
  {$IFDEF FPC}
  Windows, Messages, LMessages, Classes, SysUtils, Controls, Forms,
  {$ELSE}
  Winapi.Windows, Winapi.Messages, System.Classes, System.SysUtils, Vcl.Controls,
  Vcl.Forms,
  {$ENDIF}
  NotepadPP.Plugin;

type
  {$IFDEF FPC}
  TNppMessage = LMessages.TLMessage;
  {$ELSE}
  TNppMessage = Winapi.Messages.TMessage;
  {$ENDIF}

  TNppForm = class(TForm)
  private
    FNpp: TNppPlugin;
    FDefaultCloseAction: TCloseAction;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure DoClose(var Action: TCloseAction); override;
  public
    constructor Create(NppParent: TNppPlugin); reintroduce; overload; virtual;
    constructor Create(AOwner: TNppForm); reintroduce; overload; virtual;
    function WantChildKey(Child: TControl; var Message: TNppMessage): Boolean; override;
    property Npp: TNppPlugin read FNpp;
    property DefaultCloseAction: TCloseAction read FDefaultCloseAction
      write FDefaultCloseAction;
  end;

implementation

resourcestring
  SNoPlugin = 'A plugin window is created with a reference to the plugin';
  SNoOwner = 'A plugin window is created with a reference to its owner window';

constructor TNppForm.Create(NppParent: TNppPlugin);
begin
  if not Assigned(NppParent) then raise EInvalidOperation.Create(SNoPlugin);
  FNpp := NppParent;
  FDefaultCloseAction := caNone;
  inherited Create(nil);
end;

constructor TNppForm.Create(AOwner: TNppForm);
begin
  if not Assigned(AOwner) then raise EInvalidOperation.Create(SNoOwner);
  FNpp := AOwner.Npp;
  FDefaultCloseAction := caNone;
  inherited Create(AOwner);
end;

procedure TNppForm.CreateWnd;
begin
  inherited;
  if Assigned(FNpp) then FNpp.RegisterModeless(Handle);
end;

procedure TNppForm.DestroyWnd;
begin
  if Assigned(FNpp) and HandleAllocated then FNpp.UnregisterModeless(Handle);
  inherited;
end;

procedure TNppForm.DoClose(var Action: TCloseAction);
begin
  if FDefaultCloseAction <> caNone then Action := FDefaultCloseAction;
  inherited;
end;

function TNppForm.WantChildKey(Child: TControl; var Message: TNppMessage): Boolean;
begin
  if not Assigned(Child) then Exit(False);
  Result := Child.Perform(CN_BASE + Message.Msg, Message.WParam, Message.LParam) <> 0;
end;

end.
