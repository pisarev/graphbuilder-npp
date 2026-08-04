{ ************************************************************************** }
{                                                                            }
{ NotepadPP.Scintilla                                                        }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit NotepadPP.Scintilla;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  SCI_GETTEXT = 2182;
  SCI_GETTEXTLENGTH = 2183;
  SCI_GETSELTEXT = 2161;
  SCI_REPLACESEL = 2170;
  SCI_GETSELECTIONEMPTY = 2650;
  SCI_GETTEXTRANGE = 2162;
  SCI_GETSELECTIONSTART = 2143;
  SCI_GETSELECTIONEND = 2145;
  SCI_SETSEL = 2160;

  SCI_GETLINECOUNT = 2154;
  SCI_GETLINE = 2153;
  SCI_LINELENGTH = 2350;
  SCI_GETCURLINE = 2027;
  SCI_LINEFROMPOSITION = 2166;
  SCI_POSITIONFROMLINE = 2167;
  SCI_GETCURRENTPOS = 2008;

  SCI_POSITIONFROMPOINT = 2022;
  SCI_POSITIONFROMPOINTCLOSE = 2023;
  SCI_WORDSTARTPOSITION = 2266;
  SCI_WORDENDPOSITION = 2267;

  SCI_SETCODEPAGE = 2037;
  SCI_GETCODEPAGE = 2137;
  SC_CP_UTF8 = 65001;

  SCN_STYLENEEDED = 2000;
  SCN_CHARADDED = 2001;
  SCN_SAVEPOINTREACHED = 2002;
  SCN_SAVEPOINTLEFT = 2003;
  SCN_MODIFYATTEMPTRO = 2004;
  SCN_KEY = 2005;
  SCN_DOUBLECLICK = 2006;
  SCN_UPDATEUI = 2007;
  SCN_MODIFIED = 2008;
  SCN_MACRORECORD = 2009;
  SCN_MARGINCLICK = 2010;
  SCN_NEEDSHOWN = 2011;
  SCN_PAINTED = 2013;
  SCN_USERLISTSELECTION = 2014;
  SCN_URIDROPPED = 2015;
  SCN_DWELLSTART = 2016;
  SCN_DWELLEND = 2017;
  SCN_ZOOM = 2018;
  SCN_HOTSPOTCLICK = 2019;
  SCN_HOTSPOTDOUBLECLICK = 2020;
  SCN_CALLTIPCLICK = 2021;
  SCN_AUTOCSELECTION = 2022;
  SCN_INDICATORCLICK = 2023;
  SCN_INDICATORRELEASE = 2024;
  SCN_AUTOCCANCELLED = 2025;
  SCN_AUTOCCHARDELETED = 2026;
  SCN_FOCUSIN = 2028;
  SCN_FOCUSOUT = 2029;

implementation

end.
