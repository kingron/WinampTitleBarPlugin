{------------------------------------------------------------------------------}
{                  Winamp config dialog unit                                   }
{------------------------------------------------------------------------------}
{  Date:2003.04.13                                                             }
{  implementation winamp interface:config dialog                               }
{------------------------------------------------------------------------------}
unit Configdialog;

interface

uses Windows, Messages, Commctrl, ShellAPI, WinampInterface;

const
  IDD_CONFIG_DIALOG = 101;
  IDC_APPLY = 1000;
  IDC_ALPHA = 1001;
  IDC_WWW = 1002;
  IDC_DOCK = 1003;
  IDC_POS = 1007;
  IDC_ICON = 1011;
  IDC_HELP = 1015;
  IDC_NEXT = 1016;
  IDC_VOLUP = 1017;
  IDC_VOLDOWN = 1018;
  IDC_PREV = 1019;
  IDC_SHUFFLE = 1020;
  IDC_REPEAT = 1021;
  IDC_PAUSE = 1022;
  IDC_SHOW = 1023;
  IDC_DELCURR = 1024;
  IDC_ADDFAV = 1025;
  IDC_ID3 = 1026;
  IDC_FWD5S = 1027;

const
  IDCs: array[THotKey] of integer = (IDC_PREV, IDC_NEXT, IDC_VOLUP, IDC_VOLDOWN,
    IDC_SHUFFLE, IDC_REPEAT, IDC_PAUSE, IDC_SHOW, IDC_DELCURR, IDC_ADDFAV,
    IDC_ID3, IDC_FWD5S);

  STR_EGG = 'Fuck M$,GCD,USA and all....';

function ConfigProc(hDlg: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): Boolean; stdcall;
procedure UnregisterHotKeys;
procedure RegisterHotKeys;
procedure InitGlobalAtom;
procedure UnInitGlobalAtom;

implementation

uses HookUnit;

const
  AtomNames: array[THotKey] of string = ('Prev', 'Next', 'Volup', 'VolDown', 'Shuffle',
    'Repeat', 'Pause', 'Show', 'Delete', 'AddFav', 'ID3', 'Fwd5s');
var
  HandCursor: HCursor;
  Font: HFont;

procedure OpenURL(URL: pchar);
begin
  ShellExecute(plugin.hwndParent, 'open', URL, nil, nil, SW_SHOW);
end; { OpenURL }

function MakeFont(FontName: string): integer;
begin
  Result := CreateFont(-14, 0, 0, 0, 700, 0, 1, 0, DEFAULT_CHARSET,
    OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY,
    DEFAULT_PITCH or FF_DONTCARE, PChar(FontName));
end; { MakeFont }

procedure SetFont(hWnd: HWND; Font: HFONT);
begin
  PostMessage(hWnd, WM_SETFONT, Font, 0);
end; { SetFont }

function GetHelpText: string;
var
  F: Cardinal;
  L: Cardinal;
  Buff: Pchar;
begin
  F := CreateFile(pchar(GetDllPath + 'Gen_titlebar.txt'), GENERIC_READ,
    0, nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if F = INVALID_HANDLE_VALUE then
  begin
    Result := 'Readme & Help File not found';
    Exit;
  end;
  L := GetFileSize(F, nil);
  if L <> INVALID_FILE_SIZE then
  begin
    SetLength(Result, L + 1);
    Buff := @Result[1];
    ReadFile(F, Buff^, L, L, nil);
  end;
  CloseHandle(F);
end;

function StrToInt(str: string; out int: integer): Boolean;
var
  i: integer;
begin
  Result := False;
  Int := Ord(Str[Length(Str)]) - 30;
  if not (Int in [0..9]) then exit;
  for i := Length(Str) - 1 downto 1 do
    if Str[i] in ['0'..'9'] then
      Int := Int + (Ord(Str[i]) - 30) * 10
    else
      Exit;
  Result := True;
end; { StrToInt }

procedure UnregisterHotKeys;
var
  i: THotKey;
begin
  for i := Low(KeyIDs) to High(KeyIDs) do
    UnregisterHotKey(plugin.hwndParent, KeyIDs[i]);
end;

procedure InitGlobalAtom;
var
  i: THotKey;
begin
  for i := Low(KeyIDs) to High(KeyIDs) do
    KeyIds[i] := GlobalAddAtom(pchar('Kingron & ' + AtomNames[i]));
end;

procedure UnInitGlobalAtom;
var
  i: THotKey;
begin
  for i := Low(KeyIDs) to High(KeyIDs) do
    GlobalDeleteAtom(KeyIDs[i]);
end;

function GetModifiers(Key: Word): Byte;
{ Error:
     in hot Key Control,Display SHIFT, actual key is ALT
     and Display ALT,actual Key is SHIFT
     So we need swap SHIFT & ALT bit of HOTKEY value
}
begin
  Key := Hi(Key);
  Result := Key and $FA;
  if Key and 1 = 1 then Result := Result or 4;
  if Key and 4 = 4 then Result := Result or 1;
end;

procedure RegisterHotKeys;
var
  i: THotKey;
begin
  with Configuration do
    for i := Low(HotKeys) to High(HotKeys) do
      if HotKeys[i] <> 0 then
        RegisterHotKey(plugin.hwndParent, KeyIds[i], GetModifiers(HotKeys[i]), Lo(HotKeys[i]))
      else
        UnregisterHotKey(plugin.hwndParent, KeyIds[i]);
end;

function GetKeyLock(VK: word): Boolean;
var
  KeyS: TKeyboardState;
begin
  Result := GetKeyboardState(KeyS) and (KeyS[VK] = 1);
end;

procedure TagNumLock;
begin
  keybd_event(VK_NUMLOCK, $45, KEYEVENTF_EXTENDEDKEY or 0, 0);
  keybd_event(VK_NUMLOCK, $45, KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP, 0);
end;

var
  OldLock: Boolean;

function ConfigProc(hDlg: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): Boolean; stdcall;

  procedure DoApply;
  var
    OldConfig: TConfigRec;
    i: THotKey;
  begin
    OldConfig := Configuration;
    Configuration.Enable := IsDlgButtonChecked(hDlg, IDC_DOCK) = BST_CHECKED;
    Configuration.Alpha := SendMessage(GetDlgItem(hDlg, IDC_ALPHA), TBM_GETPOS, 0, 0);

    UnregisterHotKeys;
    for i := Low(i) to High(i) do
      Configuration.HotKeys[i] := SendMessage(GetDlgItem(hDlg, IDCs[i]), HKM_GETHOTKEY, 0, 0);
    RegisterHotKeys;

    SetWindowBlend(Configuration.Alpha);
    if OldConfig.Enable then UnHook;
    if Configuration.Enable then
      Hook
    else
      UnHook;
    EnableWindow(GetDlgItem(hDlg, IDC_APPLY), False);
  end; { DoApply }

const
  RULE1 = HKCOMB_NONE;
  RULE2 = HOTKEYF_CONTROL;
var
  wnd: THandle;
  P: TPoint;
  R: TRect;
  Old: string[255];
  i: THotKey;
begin
  Result := False;
  case uMsg of
    WM_INITDIALOG:
      begin
        OldLock := GetKeyLock(VK_NUMLOCK);
        if not OldLock then TagNumLock;
        HandCursor := LoadCursor(0, IDC_HAND);
        CheckDlgButton(hDlg, IDC_DOCK, integer(Configuration.Enable));
        wnd := GetDlgItem(hDlg, IDC_ALPHA);
        PostMessage(wnd, TBM_SETRANGE, integer(True), MAKELONG(0, 255));
        PostMessage(wnd, TBM_SETPOS, integer(True), Configuration.Alpha);
        PostMessage(wnd, TBM_SETPAGESIZE, 0, 10);
        PostMessage(wnd, TBM_SETTICFREQ, 10, 0);

        for i := Low(i) to High(i) do
        begin
          PostMessage(GetDlgItem(hDlg, IDCs[i]), HKM_SETHOTKEY, Configuration.HotKeys[i], 0);
          PostMessage(GetDlgItem(hDlg, IDCs[i]), HKM_SETRULES, RULE1, RULE2);
        end;

        SetWindowText(GetDlgItem(hDlg, IDC_POS), pchar(IntToStr(Configuration.Alpha)));
        SetWindowText(GetDlgItem(hDlg, IDC_HELP), pchar(GetHelpText));
        Font := MakeFont('Times New Roman');
        SetFont(GetDlgItem(hDlg, IDC_WWW), Font);
        Result := True;
      end;
    WM_COMMAND:
      case GetDlgCtrlID(lParam) of
        IDC_APPLY: { Apply }
          begin
            DoApply;
            Result := True;
          end;
        IDOK:
          begin
            DoApply;
            EndDialog(hDlg, IDOK);
            Result := True;
            DeleteObject(Font);
            if OldLock <> GetKeyLock(VK_NUMLOCK) then TagNumLock;
          end;
        IDCANCEL:
          begin
            EndDialog(hDlg, IDCANCEL);
            DeleteObject(Font);
            if OldLock <> GetKeyLock(VK_NUMLOCK) then TagNumLock;
          end;
        IDC_DOCK: { Check Box, IDC_DOCK }
          begin
            EnableWindow(GetDlgItem(hDlg, IDOK), True);
            EnableWindow(GetDlgItem(hDlg, IDC_APPLY), True);
            Result := True;
          end;
        IDC_PREV, IDC_NEXT, IDC_VOLUP, IDC_VOLDOWN, IDC_PAUSE, IDC_SHUFFLE,
        IDC_SHOW, IDC_REPEAT, IDC_POS, IDC_DELCURR, IDC_ADDFAV, IDC_ID3,
        IDC_FWD5S:
          begin
            EnableWindow(GetDlgItem(hDlg, IDOK), True);
            EnableWindow(GetDlgItem(hDlg, IDC_APPLY), True);
            Result := True;
         end;
      end;
    WM_HSCROLL:
      if LOWORD(wParam) = TB_ENDTRACK then
      begin
        EnableWindow(GetDlgItem(hDlg, IDOK), True);
        EnableWindow(GetDlgItem(hDlg, IDC_APPLY), True);
        SetWindowText(GetDlgItem(hDlg, IDC_POS),
          pchar(IntToStr(SendMessage(GetDlgItem(hDlg, IDC_ALPHA), TBM_GETPOS, 0, 0))));
        Result := True;
      end;
    WM_LBUTTONDBLCLK:
      begin
        { Press Ctrl + Shift + Mouse Right Button + Mouse Middle Button + Doubli Click Left Mouse Boutton }
        if not (wParam = (MK_CONTROL or MK_SHIFT or MK_LBUTTON or MK_RBUTTON or MK_MBUTTON)) then Exit;
        GetCursorPos(P);
        GetWindowRect(GetDlgItem(hDlg, IDC_ICON), R);
        if not PtInRect(R, P) then Exit;
        wnd := GetDlgItem(hDlg, IDC_WWW);
        GetWindowText(wnd, @Old[1], SizeOf(Old));
        SetWindowText(wnd, STR_EGG);
        Sleep(2000);
        SetWindowText(wnd, @Old[1]);
        Result := False;
      end;
    WM_LBUTTONDOWN:
      begin
        GetCursorPos(P);
        GetWindowRect(GetDlgItem(hDlg, IDC_WWW), R);
        if PtInRect(R, P) then OpenURL('http://kingron.delphibbs.com');
      end;
    WM_SETCURSOR:
      begin
        GetCursorPos(P);
        GetWindowRect(GetDlgItem(hDlg, IDC_WWW), R);
        if PtInRect(R, P) then
        begin
          SetCursor(HandCursor);
          Result := True;
        end;
      end;
  end;
end; { ConfigProc }

end.

