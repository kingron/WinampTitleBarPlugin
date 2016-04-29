{------------------------------------------------------------------------------}
{                  Windows HOOK Unit                                           }
{------------------------------------------------------------------------------}
{  Date:2003.04.13                                                             }
{  HOOK: Set CBT Hook for Window Active,Min or Max window,Move Window          }
{------------------------------------------------------------------------------}
unit HookUnit;

interface

uses Windows, Messages;

procedure Hook;
procedure UnHook;
procedure HookWinampWindowProc;
procedure UnHookWinampWindowProc;
procedure SetWindowBlend(Alpha: Byte);

implementation

uses WinampInterface, Configdialog;

var
  CBTProc: HHOOK;
  WinampProc: Pointer;

type
  TSetLayeredWindowAttributes = function(hwnd: HWND; crKey: COLORREF; bAlpha: Byte;
    dwFlags: DWORD): Boolean; stdcall;

function MyWinampWindowProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  i: THotKey;
begin
  Result := 0;
  if uMsg = WM_HOTKEY then
    for i := Low(KeyIds) to High(KeyIds) do
      if wParam = KeyIds[i] then
      begin
        WProcs[i];
        Exit;
      end;
  Result := CallWindowProc(WinampProc, hWnd, uMsg, wParam, lParam);
end;

procedure HookWinampWindowProc;
begin
  WinampProc := Pointer(SetWindowLong(plugin.hwndParent,
    GWL_WNDPROC, integer(@MyWinampWindowProc)));
  RegisterHotKeys;
end;

procedure UnHookWinampWindowProc;
begin
  UnregisterHotKeys;
  SetWindowLong(plugin.hwndParent, GWL_WNDPROC, integer(WinampProc));
end;

procedure SetWindowBlend(Alpha: Byte);
var
  WinampPE, WinampEQ, WinampMB: HWND;
begin
  WinampPE := FindWindow('Winamp PE', nil);
  WinampEQ := FindWindow('Winamp EQ', nil);
  WinampMB := FindWindow('Winamp MB', nil);
  if Alpha = 255 then
  begin
    SetWindowLong(WinampPE, GWL_EXSTYLE,
      GetWindowLong(WinampPE, GWL_EXSTYLE) and not WS_EX_LAYERED);
    SetWindowLong(WinampEQ, GWL_EXSTYLE,
      GetWindowLong(WinampEQ, GWL_EXSTYLE) and not WS_EX_LAYERED);
    SetWindowLong(WinampMB, GWL_EXSTYLE,
      GetWindowLong(WinampMB, GWL_EXSTYLE) and not WS_EX_LAYERED);
    SetWindowLong(plugin.hwndParent, GWL_EXSTYLE,
      GetWindowLong(plugin.hwndParent, GWL_EXSTYLE) and not WS_EX_LAYERED)
  end
  else
  begin
    SetWindowLong(WinampPE, GWL_EXSTYLE,
      GetWindowLong(WinampPE, GWL_EXSTYLE) or WS_EX_LAYERED);
    SetWindowLong(WinampEQ, GWL_EXSTYLE,
      GetWindowLong(WinampEQ, GWL_EXSTYLE) or WS_EX_LAYERED);
    SetWindowLong(WinampMB, GWL_EXSTYLE,
      GetWindowLong(WinampMB, GWL_EXSTYLE) or WS_EX_LAYERED);
    SetWindowLong(plugin.hwndParent, GWL_EXSTYLE,
      GetWindowLong(plugin.hwndParent, GWL_EXSTYLE) or WS_EX_LAYERED);
    SetLayeredWindowAttributes(plugin.hwndParent, 0, Alpha, LWA_ALPHA);
    SetLayeredWindowAttributes(WinampPE, 0, Alpha, LWA_ALPHA);
    SetLayeredWindowAttributes(WinampEQ, 0, Alpha, LWA_ALPHA);
    SetLayeredWindowAttributes(WinampMB, 0, Alpha, LWA_ALPHA);
  end;
end;

{ Dynamic load for Win9x }

procedure SetLayeredWindowAttributes(hWnd: HWND; crKey: COLORREF; bAlpha: Byte; dwFlags: LongInt);
var
  hDLL: THandle;
  Proc: TSetLayeredWindowAttributes;
begin
  hDLL := LoadLibrary('user32.dll');
  if hDLL = 0 then Exit;
  Proc := GetProcAddress(hDLL, 'SetLayeredWindowAttributes');
  if @Proc <> nil then Proc(hWnd, crKey, bAlpha, dwFlags);
  FreeLibrary(hDLL);
end; { SetLayeredWindowAttributes }

{ GetTitleInfo API can't static invoke in this DLL,dynamic load }

function GetTitleInfo(hWnd: HWND; var TitleInfo: tagTITLEBARINFO): Boolean;
type
  TGetTitleBarInfo = function(hWnd: THandle; var TitleInfo: tagTITLEBARINFO): Boolean; stdcall;
var
  hDLL: THandle;
  Proc: TGetTitleBarInfo;
begin
  Result := False;
  hDLL := LoadLibrary('user32.dll');
  if hDLL = 0 then Exit;
  Proc := GetProcAddress(hDll, 'GetTitleBarInfo');

  TitleInfo.cbSize := SizeOf(TitleInfo);
  if @Proc <> nil then Result := Proc(hWnd, TitleInfo);
  FreeLibrary(hDlL);
end; { GetTitleInfo }

function GetWinampWidth: integer;
var
  R: TRect;
begin
  if GetWindowRect(plugin.hwndParent, R) then
    Result := R.Right - R.Left
  else
    Result := WINAMP_WIDTH;
end; { GetWinampWidth }

function GetWinampHeight: integer;
var
  R: TRect;
begin
  if GetWindowRect(plugin.hwndParent, R) then
    Result := R.Bottom - R.Top
  else
    Result := GetSystemMetrics(SM_CYSIZE);
end; { GetWinampHeight }

{ GetTitleButtonWidth : Return Title Button Total Width From TitlInfo }

function GetTitleButtonWidth(const TitleInfo: tagTITLEBARINFO): integer;
var
  i: integer;
  X: integer;
begin
  Result := 0;
  X := GetSystemMetrics(SM_CXSIZE);
  for i := 2 to 5 do
    if TitleInfo.rgstate[i] and STATE_SYSTEM_INVISIBLE = 0 then Inc(Result, X);
end; { GetTitleButtonWidth }

function GetPosition(nCode: integer; hWnd: HWND; lParam: LPARAM): TPoint;
var
  R: TRect;
  Info: tagTITLEBARINFO;
  WP: WINDOWPLACEMENT;
  WID: THandle;
  EID: THandle;
begin
  GetWindowThreadProcessID(hWnd, @WID);
  FillChar(WP, SizeOf(WP), 0);
  WP.length := Sizeof(WP);

  GetWindowThreadProcessId(GetDesktopWindow, @EID);
  if WID = EID then Exit;
  if not GetTitleInfo(hWnd, Info) or (WinampProcessID = WID) then Exit;

  case nCode of
    HCBT_ACTIVATE:
      if GetWindowLong(hWnd, GWL_STYLE) and WS_CAPTION = WS_CAPTION then
        R := Info.rcTitleBar
      else if not GetWindowRect(hWnd, R) then
        Exit;
    HCBT_MOVESIZE:
      begin
        R := PRect(lParam)^;
        Inc(R.Top, (GetSystemMetrics(SM_CYCAPTION) - GetSystemMetrics(SM_CYSIZE)) div 2);
      end;
    HCBT_MINMAX:
      case Lo(lParam) of
        SW_MAXIMIZE: SystemParametersInfo(SPI_GETWORKAREA, 0, @R, 0);
        SW_RESTORE:
          begin
            if not GetWindowPlacement(hWnd, @WP) then Exit;
            R := WP.rcNormalPosition;
          end;
      end;
  end;

  with R do
  begin
    Result.X := Right - GetWinampWidth - GetTitleButtonWidth(Info);
    Result.Y := Top + (GetSystemMetrics(SM_CYSIZE) - GetWinampHeight) div 2;
    SystemParametersInfo(SPI_GETWORKAREA, 0, @R, 0);
    if not PtInRect(R, Result) then
    begin
      Result.X := 0;
      Result.Y := 0;
    end;
  end;
end; { GetPosition }

procedure SetShadeWindowPos(P: TPoint);
begin
  if (P.X <> 0) and (P.Y <> 0) then
    SetWindowPos(plugin.hwndParent, HWND_TOPMOST, P.X, P.Y,
      0, 0, SWP_NOSIZE or SWP_NOACTIVATE);
end; { SetShadeWindowPos }

function MyCBTProc(nCode: integer; wParam: WPARAM; lParam: LPARAM): integer; stdcall;
begin
  if GetWinampHeight <= WINAMP_HEIGHT then
    //if GetShade then
    case nCode of
      HCBT_ACTIVATE, HCBT_MOVESIZE, HCBT_MINMAX:
        SetShadeWindowPos(GetPosition(nCode, wParam, lParam));
    end;
  Result := CallNextHookEx(CBTProc, nCode, wParam, lParam);
end; { MyCBTProc }

procedure Hook;
begin
  CBTProc := SetWindowsHookEx(WH_CBT, @MyCBTProc, HInstance, 0);
end; { Hook }

procedure UnHook;
begin
  UnhookWindowsHookEx(CBTProc);
  CBTProc := 0;
end; { UnHook }

end.

