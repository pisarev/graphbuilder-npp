{ ************************************************************************** }
{                                                                            }
{ NotepadPP.Types                                                            }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit NotepadPP.Types;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}
{$MINENUMSIZE 4}
{$ALIGN ON}
{$IFDEF FPC}
  {$PACKRECORDS C}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Windows, Messages;
  {$ELSE}
  Winapi.Windows, Winapi.Messages;
  {$ENDIF}

const
  MenuItemNameLength = 64;

type
  TSciPosition = NativeInt;
  TSciUPtr = NativeUInt;
  TSciSPtr = NativeInt;

  TSciFunction = function(Pointer: Pointer; Message: Cardinal; WParam: TSciUPtr;
    LParam: TSciSPtr): TSciSPtr; cdecl;

  PNppData = ^TNppData;
  TNppData = record
    NppHandle: HWND;
    ScintillaMainHandle: HWND;
    ScintillaSecondHandle: HWND;
  end;

  PShortcutKey = ^TShortcutKey;
  TShortcutKey = record
    IsCtrl: ByteBool;
    IsAlt: ByteBool;
    IsShift: ByteBool;
    Key: AnsiChar;
  end;

  TPluginCommand = procedure; cdecl;

  PFuncItem = ^TFuncItem;
  TFuncItem = record
    ItemName: array[0..MenuItemNameLength - 1] of WideChar;
    Func: TPluginCommand;
    CmdID: Integer;
    Init2Check: ByteBool;
    ShortcutKey: PShortcutKey;
  end;
  TFuncItemArray = array of TFuncItem;

  TSciNotifyHeader = record
    HwndFrom: Pointer;
    IdFrom: TSciUPtr;
    Code: Cardinal;
  end;

  PSciNotification = ^TSciNotification;
  TSciNotification = record
    NotifyHeader: TSciNotifyHeader;
    Position: TSciPosition;
    Ch: Integer;
    Modifiers: Integer;
    ModificationType: Integer;
    Text: PAnsiChar;
    Length: TSciPosition;
    LinesAdded: TSciPosition;
    Message: Integer;
    WParam: TSciUPtr;
    LParam: TSciSPtr;
    Line: TSciPosition;
    FoldLevelNow: Integer;
    FoldLevelPrev: Integer;
    Margin: Integer;
    ListType: Integer;
    X: Integer;
    Y: Integer;
    Token: Integer;
    AnnotationLinesAdded: TSciPosition;
    Updated: Integer;
    ListCompletionMethod: Integer;
    CharacterSource: Integer;
    property Nmhdr: TSciNotifyHeader read NotifyHeader;
  end;

  PToolbarData = ^TToolbarData;
  TToolbarData = record
    Client: HWND;
    Name: PWideChar;
    DlgID: Integer;
    Mask: Cardinal;
    IconTab: HICON;
    AddInfo: PWideChar;
    RectFloat: TRect;
    PrevCont: Integer;
    ModuleName: PWideChar;
  end;

  PToolbarIcons = ^TToolbarIcons;
  TToolbarIcons = record
    ToolbarBmp: HBITMAP;
    ToolbarIcon: HICON;
    ToolbarIconDarkMode: HICON;
  end;

const
  NPPMSG = WM_USER + 1000;
  NPPM_GETCURRENTSCINTILLA = NPPMSG + 4;
  NPPM_MODELESSDIALOG = NPPMSG + 12;
  NPPM_DMMSHOW = NPPMSG + 30;
  NPPM_DMMHIDE = NPPMSG + 31;
  NPPM_DMMUPDATEDISPINFO = NPPMSG + 32;
  NPPM_DMMREGASDCKDLG = NPPMSG + 33;
  NPPM_SETMENUITEMCHECK = NPPMSG + 40;
  NPPM_GETPLUGINSCONFIGDIR = NPPMSG + 46;
  NPPM_GETSHORTCUTBYCMDID = NPPMSG + 76;
  NPPM_GETPLUGINHOMEPATH = NPPMSG + 97;
  NPPM_ADDTOOLBARICON_FORDARKMODE = NPPMSG + 101;
  NPPM_ISDARKMODEENABLED = NPPMSG + 107;
  NPPM_DARKMODESUBCLASSANDTHEME = NPPMSG + 112;
  NPPM_MENUCOMMAND = NPPMSG + 48;
  IDM_FILE_NEW = 41001;
  IDM_LANG = 46000;
  MODELESSDIALOGADD = 0;
  MODELESSDIALOGREMOVE = 1;
  NPPN_FIRST = 1000;
  NPPN_READY = NPPN_FIRST + 1;
  NPPN_TBMODIFICATION = NPPN_FIRST + 2;
  NPPN_SHUTDOWN = NPPN_FIRST + 9;
  NPPN_DARKMODECHANGED = NPPN_FIRST + 27;
  DMN_FIRST = 1050;
  DMN_CLOSE = DMN_FIRST + 1;
  DMN_DOCK = DMN_FIRST + 2;
  DMN_FLOAT = DMN_FIRST + 3;
  DMN_SWITCHIN = DMN_FIRST + 4;
  DMN_SWITCHOFF = DMN_FIRST + 5;
  DMN_FLOATDROPPED = DMN_FIRST + 6;
  DWS_ICONTAB = $00000001;
  DWS_ICONBAR = $00000002;
  DWS_ADDINFO = $00000004;
  DWS_USEOWNDARKMODE = $00000008;
  DWS_PARAMSALL = DWS_ICONTAB or DWS_ICONBAR or DWS_ADDINFO;
  CONT_LEFT = 0;
  CONT_RIGHT = 1;
  CONT_TOP = 2;
  CONT_BOTTOM = 3;
  DWS_DF_CONT_LEFT = CONT_LEFT shl 28;
  DWS_DF_CONT_RIGHT = CONT_RIGHT shl 28;
  DWS_DF_CONT_TOP = CONT_TOP shl 28;
  DWS_DF_CONT_BOTTOM = CONT_BOTTOM shl 28;
  DWS_DF_FLOATING = $80000000;
  dmfInit = $0000000B;
  dmfHandleChange = $0000000C;

implementation

end.
